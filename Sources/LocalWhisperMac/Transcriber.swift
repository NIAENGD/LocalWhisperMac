import AppKit
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

    func start(executableURL: URL, modelURL: URL) async {
        guard let input = selectedFileURL else { return }

        let outputURL = URL(filePath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        do {
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let process = Process()
            process.executableURL = executableURL
            process.arguments = [
                "-m", modelURL.path,
                "-f", input.path,
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

            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.consumeProgress(from: text)
                }
            }

            try process.run()
            await waitForTermination(process)
            stderrPipe.fileHandleForReading.readabilityHandler = nil

            if process.terminationStatus == 0 {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    outputText = try String(contentsOf: outputURL)
                    progress = 1.0
                    status = .done
                } else {
                    throw NSError(domain: "Transcriber", code: 6, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_missing_result")])
                }
            } else {
                throw NSError(domain: "Transcriber", code: 7, userInfo: [NSLocalizedDescriptionKey: String(localized: "error_transcribe_failed")])
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
}
