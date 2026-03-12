import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var setup: SetupManager
    @Environment(\.openURL) private var openURL

    @State private var showModelImporter = false

    private var models: [String] {
        setup.availableModels()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("settings")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 10) {
                Text("current_model")
                    .font(.headline)
                Picker("model", selection: Binding(
                    get: { setup.selectedModelName },
                    set: { setup.selectModel(named: $0) }
                )) {
                    ForEach(models, id: \.self) { modelName in
                        Text(modelName).tag(modelName)
                    }
                }
                .pickerStyle(.menu)
                .disabled(models.isEmpty || setup.isInstalling)

                if models.isEmpty {
                    Text("settings_no_models")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("install_model")
                    .font(.headline)

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
                    Button("open_huggingface") {
                        openURL(setup.installChoice.huggingFaceModelPageURL)
                    }
                    .disabled(setup.isInstalling)

                    Button("import_model") {
                        showModelImporter = true
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

            Spacer()
        }
        .padding(20)
        .frame(width: 520, height: 360)
        .fileImporter(
            isPresented: $showModelImporter,
            allowedContentTypes: modelImporterTypes,
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                Task {
                    await setup.importModel(from: url)
                }
            }
        }
    }

    private var modelImporterTypes: [UTType] {
        var allowed: [UTType] = [.data, .item]
        if let binType = UTType(filenameExtension: "bin") {
            allowed.insert(binType, at: 0)
        }
        return allowed
    }
}
