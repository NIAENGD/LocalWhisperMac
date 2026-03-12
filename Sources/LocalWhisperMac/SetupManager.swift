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

    var whisperExecutableURL: URL? {
        resolveWhisperExecutableURL()
    }
    var selectedModelURL: URL {
        let saved = userDefaults.string(forKey: "selectedModelName")
        let name = saved ?? installChoice.modelFileName
        return modelDirectory.appendingPathComponent(name)
    }

    var selectedModelName: String {
        userDefaults.string(forKey: "selectedModelName") ?? installChoice.modelFileName
    }

    init() {
        let root = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Audionyx", isDirectory: true)
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
            } else if !isModelInstalled() {
                stage = .needsInstall
            } else {
                stage = .failed(String(localized: "error_missing_whisper_cli"))
            }
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
            guard sourceURL.pathExtension.lowercased() == "bin" else {
                throw NSError(
                    domain: "Setup",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "error_invalid_model_file")]
                )
            }

            setupStatusText = String(localized: "setup_importing_model")
            let destinationName = uniqueModelFileName(for: sourceURL.lastPathComponent)
            let destination = modelDirectory.appendingPathComponent(destinationName)
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)

            setupProgress = 1.0
            setupStatusText = String(localized: "setup_done")
            userDefaults.set(destinationName, forKey: "selectedModelName")
            stage = .ready
        } catch {
            stage = .failed(error.localizedDescription)
        }
    }

    func availableModels() -> [String] {
        guard let items = try? fm.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil) else {
            return []
        }

        return items
            .filter { $0.pathExtension.lowercased() == "bin" }
            .map(\.lastPathComponent)
            .sorted()
    }

    func selectModel(named modelName: String) {
        userDefaults.set(modelName, forKey: "selectedModelName")
        if installArtifactsAvailable() {
            stage = .ready
        } else if !isModelInstalled() {
            stage = .needsInstall
        } else {
            stage = .failed(String(localized: "error_missing_whisper_cli"))
        }
    }

    func clearFailure() {
        if case .failed = stage {
            if installArtifactsAvailable() {
                stage = .ready
            } else if !isModelInstalled() {
                stage = .needsInstall
            } else {
                stage = .failed(String(localized: "error_missing_whisper_cli"))
            }
        }
    }

    private func ensureDirectories() throws {
        try fm.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: binDirectory, withIntermediateDirectories: true)
    }

    private func installArtifactsAvailable() -> Bool {
        isModelInstalled() && whisperExecutableURL != nil
    }

    private func isModelInstalled() -> Bool {
        fm.fileExists(atPath: selectedModelURL.path)
    }

    private func resolveWhisperExecutableURL() -> URL? {
        var candidates = [
            binDirectory.appendingPathComponent("whisper-cli"),
            URL(filePath: "/opt/homebrew/bin/whisper-cli"),
            URL(filePath: "/usr/local/bin/whisper-cli")
        ]

        if let resourceURL = Bundle.main.resourceURL {
            candidates.insert(resourceURL.appendingPathComponent("whisper-cli"), at: 1)
        }

        for candidate in candidates {
            if fm.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    private func uniqueModelFileName(for proposedName: String) -> String {
        let ext = URL(filePath: proposedName).pathExtension
        let baseName = URL(filePath: proposedName).deletingPathExtension().lastPathComponent
        var candidate = proposedName
        var index = 1

        while fm.fileExists(atPath: modelDirectory.appendingPathComponent(candidate).path) {
            candidate = "\(baseName)-\(index).\(ext)"
            index += 1
        }

        return candidate
    }
}
