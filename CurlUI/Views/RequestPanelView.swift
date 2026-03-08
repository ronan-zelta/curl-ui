import SwiftUI
import CodeViewer

struct RequestPanelView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            urlBar
                .padding()

            Divider()

            Picker("", selection: $viewModel.selectedRequestTab) {
                ForEach(RequestViewModel.RequestTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch viewModel.selectedRequestTab {
            case .params:
                ScrollView {
                    KeyValueEditorView(
                        title: "Query Parameters",
                        entries: $viewModel.params,
                        onAdd: { viewModel.addParam() },
                        onRemove: { viewModel.removeParam(at: $0) }
                    )
                    .padding()
                }
            case .headers:
                ScrollView {
                    KeyValueEditorView(
                        title: "Headers",
                        entries: $viewModel.headers,
                        onAdd: { viewModel.addHeader() },
                        onRemove: { viewModel.removeHeader(at: $0) }
                    )
                    .padding()
                }
            case .body:
                BodyEditorView(viewModel: viewModel)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - URL Bar

    private var urlBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $viewModel.selectedMethod) {
                ForEach(HTTPMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 100)

            TextField("Enter URL or paste curl command", text: $viewModel.urlString)
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.urlString) { newValue in
                    viewModel.handleURLChange(newValue)
                }
                .onSubmit { viewModel.sendRequest() }

            Button(action: { viewModel.sendRequest() }) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 50)
                } else {
                    Text("Send")
                        .frame(width: 50)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

// MARK: - KeyValueEditorView

struct KeyValueEditorView: View {
    let title: String
    @Binding var entries: [KeyValueEntry]
    let onAdd: () -> Void
    let onRemove: (IndexSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    TextField("Key", text: $entries[index].key)
                        .textFieldStyle(.roundedBorder)
                    TextField("Value", text: $entries[index].value)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        onRemove(IndexSet(integer: index))
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - BodyEditorView

struct BodyEditorView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $viewModel.selectedBodyType) {
                ForEach(BodyType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            bodyContent
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch viewModel.selectedBodyType {
        case .none:
            Spacer()
            HStack {
                Spacer()
                Text("This request does not have a body")
                    .foregroundColor(.secondary)
                Spacer()
            }
            Spacer()

        case .raw:
            CodeViewer(
                content: $viewModel.requestBody,
                mode: .json,
                darkTheme: .monokai,
                lightTheme: .dawn,
                isReadOnly: false,
                fontSize: 13
            )

        case .binary:
            VStack(spacing: 12) {
                Spacer()
                HStack(spacing: 8) {
                    TextField("File path", text: $viewModel.binaryFilePath)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            viewModel.loadBinaryFile(from: viewModel.binaryFilePath)
                        }
                    Button("Browse\u{2026}") {
                        viewModel.browseBinaryFile()
                    }
                }
                .padding(.horizontal)

                if let data = viewModel.binaryFileData {
                    Text("\(data.count) bytes loaded")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                } else if !viewModel.binaryFilePath.isEmpty {
                    Text("Failed to load file")
                        .foregroundColor(.red)
                }
                Spacer()
            }

        case .formData:
            ScrollView {
                KeyValueEditorView(
                    title: "Form Data",
                    entries: $viewModel.formDataEntries,
                    onAdd: { viewModel.addFormDataEntry() },
                    onRemove: { viewModel.removeFormDataEntry(at: $0) }
                )
                .padding()
            }

        case .urlEncoded:
            ScrollView {
                KeyValueEditorView(
                    title: "URL Encoded",
                    entries: $viewModel.urlEncodedEntries,
                    onAdd: { viewModel.addUrlEncodedEntry() },
                    onRemove: { viewModel.removeUrlEncodedEntry(at: $0) }
                )
                .padding()
            }

        case .graphQL:
            VStack(alignment: .leading, spacing: 8) {
                Text("Query")
                    .font(.headline)
                    .padding([.horizontal, .top])
                CodeViewer(
                    content: $viewModel.graphQLQuery,
                    mode: .graphqlschema,
                    darkTheme: .monokai,
                    lightTheme: .dawn,
                    isReadOnly: false,
                    fontSize: 13
                )
                .frame(minHeight: 80)
                .padding(.horizontal)

                Text("Variables (JSON)")
                    .font(.headline)
                    .padding(.horizontal)
                CodeViewer(
                    content: $viewModel.graphQLVariables,
                    mode: .json,
                    darkTheme: .monokai,
                    lightTheme: .dawn,
                    isReadOnly: false,
                    fontSize: 13
                )
                .frame(minHeight: 50)
                .padding([.horizontal, .bottom])
            }
        }
    }
}
