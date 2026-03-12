import AppKit
import AVFoundation
import Foundation

@MainActor
final class Transcriber: ObservableObject {
    enum Status {
        case idle
        case running
        case done
        case failed(String)
    }

    @Published var selectedFileURL: URL?
    @Published var progress: Double = 0
    @Published var outputText = ""
    @Published var status: Status = .idle

    private var process: Process?

    var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    func start(executableURL: URL?, modelURL: URL) async {
        guard let input = selectedFileURL else { return }
        guard let executableURL else {
            status = .failed(String(localized: "error_missing_whisper_cli"))
            return
        }

        let didAccessSecurityScopedResource = input.startAccessingSecurityScopedResource()
        var temporaryInputURL: URL?

        let outputURL = URL(filePath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        defer {
            if didAccessSecurityScopedResource {
                input.stopAccessingSecurityScopedResource()
            }
            if let temporaryInputURL {
                try? FileManager.default.removeItem(at: temporaryInputURL)
            }
            try? FileManager.default.removeItem(at: outputURL)
        }

        do {
            let transcribableInputURL = try await prepareInputFile(from: input)
            if transcribableInputURL != input {
                temporaryInputURL = transcribableInputURL
            }

            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let process = Process()
            process.executableURL = executableURL
            process.arguments = [
                "-m", modelURL.path,
                "-f", transcribableInputURL.path,
                "-otxt",
                "-of", outputURL.deletingPathExtension().path,
                "-pp"
            ]

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe()
            self.process = process
            progress = 0
            outputText = ""
            status = .running
            var processLog = ""

            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    processLog.append(text)
                    self?.consumeProgress(from: text)
                }
            }

            try process.run()
            await waitForTermination(process)
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus == 0 {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    outputText = try String(contentsOf: outputURL)
                    guard !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw NSError(domain: "Transcriber", code: 8, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_empty_result")])
                    }
                    progress = 1.0
                    status = .done
                } else {
                    throw NSError(domain: "Transcriber", code: 6, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_missing_result")])
                }
            } else {
                let details = processLog.trimmingCharacters(in: .whitespacesAndNewlines)
                let failureMessage = details.isEmpty ? String(localized: "error_transcribe_failed") : "\(String(localized: "error_transcribe_failed"))\n\n\(details)"
                throw NSError(domain: "Transcriber", code: 7, userInfo: [NSLocalizedDescriptionKey: failureMessage])
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func copyResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(outputText, forType: .string)
    }

    func saveResult() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "transcript.txt"

        if panel.runModal() == .OK, let saveURL = panel.url {
            try? outputText.write(to: saveURL, atomically: true, encoding: .utf8)
        }
    }

    private func waitForTermination(_ process: Process) async {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in
                continuation.resume()
            }
        }
    }

    private func consumeProgress(from logLine: String) {
        let pattern = #"(\d{1,3})%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(logLine.startIndex..<logLine.endIndex, in: logLine)
        guard let match = regex.firstMatch(in: logLine, range: range),
              let pctRange = Range(match.range(at: 1), in: logLine),
              let pct = Double(logLine[pctRange]) else { return }

        progress = min(1, max(progress, pct / 100))
    }

    private func prepareInputFile(from inputURL: URL) async throws -> URL {
        if isLikelyVideoFile(inputURL) {
            return try await extractAudioTrack(from: inputURL)
        }

        return inputURL
    }

    private func isLikelyVideoFile(_ url: URL) -> Bool {
        guard let typeIdentifier = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }

        return typeIdentifier.conforms(to: .movie) || typeIdentifier.conforms(to: .video)
    }

    private func extractAudioTrack(from videoURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw NSError(domain: "Transcriber", code: 9, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_video_has_no_audio")])
        }

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "Transcriber", code: 10, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_video_extract_failed")])
        }

        let outputURL = URL(filePath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.shouldOptimizeForNetworkUse = false

        let result = await exportSession.export()
        if case .completed = result {
            return outputURL
        }

        if let error = exportSession.error {
            throw NSError(domain: "Transcriber", code: 11, userInfo: [NSLocalizedDescriptionKey: "\(String(localized: "error_video_extract_failed"))\n\n\(error.localizedDescription)"])
        }

        throw NSError(domain: "Transcriber", code: 12, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_video_extract_failed")])
    }
}
