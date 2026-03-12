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

    func clearFailure() {
        if case .failed = stage {
            stage = installArtifactsAvailable() ? .ready : .needsInstall
        }
    }

    private func ensureDirectories() throws {
        try fm.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: binDirectory, withIntermediateDirectories: true)
    }

    private func installArtifactsAvailable() -> Bool {
        fm.fileExists(atPath: selectedModelURL.path)
    }
}
