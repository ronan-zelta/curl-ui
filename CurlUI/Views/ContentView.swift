import SwiftUI

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
            // URL Bar
            urlBar
                .padding()

            Divider()

            // Tabs: Headers & Body
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headersSection
                    if viewModel.hasBody {
                        bodySection
                    }
                }
                .padding()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var urlBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $viewModel.selectedMethod) {
                ForEach(HTTPMethod.allCases) { method in
                    Text(method.rawValue)
                        .tag(method)
                }
            }
            .labelsHidden()
            .frame(width: 100)

            TextField("Enter URL", text: $viewModel.urlString)
                .textFieldStyle(.roundedBorder)
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

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Body (JSON)")
                .font(.headline)

            TextEditor(text: $viewModel.requestBody)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150)
                .border(Color.gray.opacity(0.3))
                .cornerRadius(4)
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
            // Status bar
            HStack(spacing: 12) {
                statusBadge(response)
                Text(String(format: "%.0f ms", response.duration * 1000))
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
                Spacer()
            }
            .padding()

            Divider()

            // Response tabs
            Picker("", selection: $viewModel.selectedResponseTab) {
                ForEach(RequestViewModel.ResponseTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tab content
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
        ScrollView([.horizontal, .vertical]) {
            Text(response.formattedBody)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
