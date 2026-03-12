import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var setup: SetupManager
    @EnvironmentObject private var transcriber: Transcriber

    @State private var showFileImporter = false

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
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .movie, .mpeg4Movie, .wav],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result {
                transcriber.selectedFileURL = urls.first
            }
        }
        .alert(String(localized: "error_title"), isPresented: Binding(
            get: {
                if case .failed = setup.stage { return true }
                if case .failed = transcriber.status { return true }
                return false
            },
            set: { _ in }
        )) {
            Button(String(localized: "ok")) {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if setup.stage != .ready {
                setupOverlay
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("app_title")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("app_subtitle")
                .foregroundStyle(.secondary)
        }
    }

    private var fileSection: some View {
        HStack(spacing: 14) {
            Button {
                showFileImporter = true
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
            .disabled(transcriber.selectedFileURL == nil || setup.stage != .ready || transcriber.status == .running)
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

                Picker("model", selection: $setup.installChoice) {
                    ForEach(InstallChoice.allCases) { option in
                        Text(option.displayTitle).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(setup.stage == .installing)

                if setup.stage == .installing {
                    ProgressView(value: setup.setupProgress)
                    Text(setup.setupStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await setup.install() }
                } label: {
                    Text(setup.stage == .installing ? "setup_in_progress" : "start_setup")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(setup.stage == .installing)
            }
            .padding(24)
            .frame(width: 520)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
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
}

#Preview {
    ContentView()
        .environmentObject(SetupManager())
        .environmentObject(Transcriber())
}
