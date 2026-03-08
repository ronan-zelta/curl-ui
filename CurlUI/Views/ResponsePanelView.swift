import SwiftUI
import CodeViewer

struct ResponsePanelView: View {
    @ObservedObject var viewModel: RequestViewModel

    var body: some View {
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

    // MARK: - Error Banner

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

    // MARK: - Response Content

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

    // MARK: - Status Badge

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

    // MARK: - Response Body

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

    // MARK: - Response Headers

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
