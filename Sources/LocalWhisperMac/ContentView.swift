import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    private enum ImportTarget {
        case audio
        case model
    }

    @EnvironmentObject private var setup: SetupManager
    @EnvironmentObject private var transcriber: Transcriber
    @Environment(\.openURL) private var openURL

    @State private var importTarget: ImportTarget?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.blue.opacity(0.16), Color.purple.opacity(0.12), Color.black.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                header
                fileSection
                progressSection
                outputSection
            }
            .padding(28)
        }
        .fileImporter(
            isPresented: Binding(
                get: { importTarget != nil },
                set: { _ in }
            ),
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImporterResult(result)
        }
        .alert(String(localized: "error_title"), isPresented: Binding(
            get: {
                if case .failed = setup.stage { return true }
                if case .failed = transcriber.status { return true }
                return false
            },
            set: { showing in
                if !showing {
                    setup.clearFailure()
                    if case .failed = transcriber.status {
                        transcriber.status = .idle
                    }
                }
            }
        )) {
            Button(String(localized: "ok")) {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if !setup.isReady {
                setupOverlay
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("app_title")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("app_subtitle")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SettingsLink {
                Label("settings", systemImage: "gearshape")
            }
            .buttonStyle(.bordered)
        }
    }

    private var fileSection: some View {
        HStack(spacing: 14) {
            Button {
                importTarget = .audio
            } label: {
                Label("choose_file", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)

            Text(transcriber.selectedFileURL?.lastPathComponent ?? String(localized: "no_file_selected"))
                .lineLimit(1)
                .foregroundStyle(transcriber.selectedFileURL == nil ? .secondary : .primary)

            Spacer()

            Button {
                Task {
                    await transcriber.start(executableURL: setup.whisperExecutableURL, modelURL: setup.selectedModelURL)
                }
            } label: {
                Label("start_transcribing", systemImage: "waveform.and.mic")
            }
            .buttonStyle(.borderedProminent)
            .disabled(transcriber.selectedFileURL == nil || !setup.isReady || transcriber.isRunning || setup.whisperExecutableURL == nil)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView(value: transcriber.progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("result")
                .font(.headline)

            TextEditor(text: $transcriber.outputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                Button {
                    transcriber.copyResult()
                } label: {
                    Label("copy", systemImage: "doc.on.doc")
                }
                .disabled(!canExport)

                Button {
                    transcriber.saveResult()
                } label: {
                    Label("save_txt", systemImage: "square.and.arrow.down")
                }
                .disabled(!canExport)

                Spacer()
            }
        }
    }

    private var setupOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.35))
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("first_run_setup")
                    .font(.title2.bold())

                Text("setup_description")
                    .foregroundStyle(.secondary)

                if setup.whisperExecutableURL == nil {
                    prerequisiteInstallSection
                }

                Picker("model", selection: $setup.installChoice) {
                    ForEach(InstallChoice.allCases) { option in
                        Text(option.displayTitle).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(setup.isInstalling)

                Text("setup_model_download_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button {
                        openURL(setup.installChoice.huggingFaceModelPageURL)
                    } label: {
                        Text("open_huggingface")
                    }
                    .disabled(setup.isInstalling)

                    Button {
                        importTarget = .model
                    } label: {
                        Text("import_model")
                    }
                    .disabled(setup.isInstalling)
                }

                if setup.isInstalling {
                    ProgressView(value: setup.setupProgress)
                    Text(setup.setupStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(width: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var prerequisiteInstallSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("setup_prereq_title")
                .font(.headline)

            Text("setup_prereq_body")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(prerequisiteCommands)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button {
                copyPrerequisiteCommands()
            } label: {
                Label("copy_setup_commands", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
    }

    private var prerequisiteCommands: String {
        "brew install whisper-cpp\nwhich whisper-cli"
    }

    private func copyPrerequisiteCommands() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(prerequisiteCommands, forType: .string)
    }

    private var statusText: String {
        switch transcriber.status {
        case .idle:
            return String(localized: "ready")
        case .running:
            return String(localized: "transcribing")
        case .done:
            return String(localized: "done")
        case let .failed(message):
            return message
        }
    }

    private var errorMessage: String {
        switch setup.stage {
        case let .failed(message): return message
        default:
            if case let .failed(message) = transcriber.status {
                return message
            }
            return String(localized: "generic_error")
        }
    }

    private var canExport: Bool {
        if case .done = transcriber.status {
            return !transcriber.outputText.isEmpty
        }
        return false
    }

    private var allowedTypes: [UTType] {
        switch importTarget {
        case .audio:
            return [.audio, .movie, .mpeg4Movie]
        case .model:
            return modelImporterTypes
        case .none:
            return [.data]
        }
    }

    private var modelImporterTypes: [UTType] {
        var allowed: [UTType] = [.data, .item]
        if let binType = UTType(filenameExtension: "bin") {
            allowed.insert(binType, at: 0)
        }
        return allowed
    }

    private func handleImporterResult(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let selectedURL = urls.first else {
            importTarget = nil
            return
        }

        switch importTarget {
        case .audio:
            transcriber.selectedFileURL = selectedURL
        case .model:
            Task {
                await setup.importModel(from: selectedURL)
            }
        case .none:
            break
        }

        importTarget = nil
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SetupManager())
            .environmentObject(Transcriber())
    }
}
#endif
