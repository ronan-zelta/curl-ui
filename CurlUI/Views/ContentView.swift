import SwiftUI
import CodeViewer

struct ContentView: View {
    @StateObject private var viewModel = RequestViewModel()

    var body: some View {
        VSplitView {
            requestPanel
                .frame(minHeight: 200)

            responsePanel
                .frame(minHeight: 200)
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Request Panel

    private var requestPanel: some View {
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
                    paramsSection.padding()
                }
            case .headers:
                ScrollView {
                    headersSection.padding()
                }
            case .body:
                bodySection
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

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

    // MARK: - Params

    private var paramsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Query Parameters")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.addParam() }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(viewModel.params.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    TextField("Key", text: $viewModel.params[index].key)
                        .textFieldStyle(.roundedBorder)
                    TextField("Value", text: $viewModel.params[index].value)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        viewModel.removeParam(at: IndexSet(integer: index))
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Headers

    private var headersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Headers")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.addHeader() }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(viewModel.headers.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    TextField("Key", text: $viewModel.headers[index].key)
                        .textFieldStyle(.roundedBorder)
                    TextField("Value", text: $viewModel.headers[index].value)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        viewModel.removeHeader(at: IndexSet(integer: index))
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Body

    private var bodySection: some View {
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
                    Button("Browse…") {
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
                keyValueEditor(
                    entries: $viewModel.formDataEntries,
                    add: { viewModel.addFormDataEntry() },
                    remove: { viewModel.removeFormDataEntry(at: $0) }
                )
                .padding()
            }

        case .urlEncoded:
            ScrollView {
                keyValueEditor(
                    entries: $viewModel.urlEncodedEntries,
                    add: { viewModel.addUrlEncodedEntry() },
                    remove: { viewModel.removeUrlEncodedEntry(at: $0) }
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

    private func keyValueEditor(
        entries: Binding<[HeaderEntry]>,
        add: @escaping () -> Void,
        remove: @escaping (IndexSet) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Button(action: add) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(entries.wrappedValue.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    TextField("Key", text: entries[index].key)
                        .textFieldStyle(.roundedBorder)
                    TextField("Value", text: entries[index].value)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        remove(IndexSet(integer: index))
                    }) {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Response Panel

    private var responsePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            if let response = viewModel.response {
                responseContent(response)
            } else if viewModel.isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("Sending request...")
                    Spacer()
                }
                Spacer()
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Send a request to see the response")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
                .lineLimit(3)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
    }

    private func responseContent(_ response: APIResponse) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                statusBadge(response)
                Text(String(format: "%.0f ms", response.duration * 1000))
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
                Spacer()
            }
            .padding()

            Divider()

            Picker("", selection: $viewModel.selectedResponseTab) {
                ForEach(RequestViewModel.ResponseTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            switch viewModel.selectedResponseTab {
            case .body:
                responseBodyView(response)
            case .headers:
                responseHeadersView(response)
            }
        }
    }

    private func statusBadge(_ response: APIResponse) -> some View {
        let color: Color = {
            switch response.statusCategory {
            case .success: return .green
            case .redirect: return .yellow
            case .clientError: return .orange
            case .serverError: return .red
            case .unknown: return .gray
            }
        }()

        return Text("\(response.statusCode)")
            .font(.system(.title3, design: .monospaced).bold())
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    private func responseBodyView(_ response: APIResponse) -> some View {
        CodeViewer(
            content: .constant(response.formattedBody),
            mode: .json,
            darkTheme: .monokai,
            lightTheme: .dawn,
            isReadOnly: true,
            fontSize: 13
        )
    }

    private func responseHeadersView(_ response: APIResponse) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(response.headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack(alignment: .top, spacing: 8) {
                        Text(key)
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundColor(.accentColor)
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 2)
                    Divider()
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    ContentView()
}
