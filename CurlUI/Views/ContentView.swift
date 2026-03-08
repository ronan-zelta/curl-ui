import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = RequestViewModel()

    var body: some View {
        VSplitView {
            RequestPanelView(viewModel: viewModel)
                .frame(minHeight: 200)

            ResponsePanelView(viewModel: viewModel)
                .frame(minHeight: 200)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

#Preview {
    ContentView()
}
