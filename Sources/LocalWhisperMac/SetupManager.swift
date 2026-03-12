import Foundation
import SwiftUI

enum InstallChoice: String, CaseIterable, Identifiable {
    case mediumEN
    case mediumMultilingual

    var id: String { rawValue }

    var modelFileName: String {
        switch self {
        case .mediumEN:
            return "ggml-medium.en.bin"
        case .mediumMultilingual:
            return "ggml-medium.bin"
        }
    }

    var modelURL: URL {
        switch self {
        case .mediumEN:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin?download=true")!
        case .mediumMultilingual:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin?download=true")!
        }
    }

    var huggingFaceModelPageURL: URL {
        switch self {
        case .mediumEN:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/blob/main/ggml-medium.en.bin")!
        case .mediumMultilingual:
            return URL(string: "https://huggingface.co/ggerganov/whisper.cpp/blob/main/ggml-medium.bin")!
        }
    }

    var displayTitle: LocalizedStringKey {
        switch self {
        case .mediumEN: return "model_english"
        case .mediumMultilingual: return "model_multilingual"
        }
    }
}

@MainActor
final class SetupManager: ObservableObject {
    enum Stage {
        case loading
        case needsInstall
        case installing
        case ready
        case failed(String)
    }

    var isReady: Bool {
        if case .ready = stage { return true }
        return false
    }

    var isInstalling: Bool {
        if case .installing = stage { return true }
        return false
    }

    @Published var stage: Stage = .loading
    @Published var installChoice: InstallChoice = .mediumEN
    @Published var setupProgress: Double = 0
    @Published var setupStatusText = ""

    private let fm = FileManager.default
    private let userDefaults = UserDefaults.standard

    let appSupportDirectory: URL
    let modelDirectory: URL
    let binDirectory: URL

    var whisperExecutableURL: URL { binDirectory.appendingPathComponent("whisper-cli") }
    var selectedModelURL: URL {
        let saved = userDefaults.string(forKey: "selectedModelName")
        let name = saved ?? installChoice.modelFileName
        return modelDirectory.appendingPathComponent(name)
    }

    init() {
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalWhisperMac", isDirectory: true)
        self.appSupportDirectory = root
        self.modelDirectory = root.appendingPathComponent("models", isDirectory: true)
        self.binDirectory = root.appendingPathComponent("bin", isDirectory: true)

        if Locale.preferredLanguages.first?.hasPrefix("zh") == true {
            installChoice = .mediumMultilingual
        }
    }

    func loadState() async {
        do {
            try ensureDirectories()
            if installArtifactsAvailable() {
                stage = .ready
            } else {
                stage = .needsInstall
            }
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    func install() async {
        stage = .installing
        setupProgress = 0
        setupStatusText = String(localized: "setup_preparing")

        do {
            try ensureDirectories()
            try await downloadWhisperBinary()
            setupProgress = 0.5
            try await downloadModel()
            setupProgress = 1.0
            setupStatusText = String(localized: "setup_done")
            userDefaults.set(installChoice.modelFileName, forKey: "selectedModelName")
            stage = .ready
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    func importModel(from sourceURL: URL) async {
        stage = .installing
        setupProgress = 0
        setupStatusText = String(localized: "setup_preparing")

        let hasSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try ensureDirectories()
            if !fm.isExecutableFile(atPath: whisperExecutableURL.path) {
                try await downloadWhisperBinary()
            }

            setupStatusText = String(localized: "setup_importing_model")
            let destination = modelDirectory.appendingPathComponent(installChoice.modelFileName)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)

            setupProgress = 1.0
            setupStatusText = String(localized: "setup_done")
            userDefaults.set(installChoice.modelFileName, forKey: "selectedModelName")
            stage = .ready
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    private func ensureDirectories() throws {
        try fm.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: binDirectory, withIntermediateDirectories: true)
    }

    private func installArtifactsAvailable() -> Bool {
        fm.isExecutableFile(atPath: whisperExecutableURL.path) && fm.fileExists(atPath: selectedModelURL.path)
    }

    private func downloadWhisperBinary() async throws {
        setupStatusText = String(localized: "setup_downloading_engine")

        let releaseURL = URL(string: "https://github.com/ggerganov/whisper.cpp/releases/download/v1.7.6/whisper-bin-macos-arm64.zip")!
        let zipURL = appSupportDirectory.appendingPathComponent("whisper-bin-macos-arm64.zip")

        try await downloadFile(from: releaseURL, to: zipURL)
        setupStatusText = String(localized: "setup_extracting_engine")

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "whisper-cli", "-d", binDirectory.path]
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(domain: "Setup", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_extracting_engine")])
        }

        try fm.removeItem(at: zipURL)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: whisperExecutableURL.path)
    }

    private func downloadModel() async throws {
        setupStatusText = String(localized: "setup_downloading_model")
        let destination = modelDirectory.appendingPathComponent(installChoice.modelFileName)
        try await downloadFile(from: installChoice.modelURL, to: destination)
    }

    private func downloadFile(from source: URL, to destination: URL) async throws {
        let (tmpURL, response) = try await URLSession.shared.download(from: source)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(
                domain: "Setup",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "\(String(localized: "error_download_failed")) (HTTP \(statusCode))"
                ]
            )
        }

        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tmpURL, to: destination)
    }
}
