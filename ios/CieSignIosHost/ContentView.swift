import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SigningViewModel()

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack { content }
            } else {
                NavigationView { content }
                    .navigationTitle("CIE Sign iOS")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.status)
                .multilineTextAlignment(.leading)
            Button {
                viewModel.signSamplePdf()
            } label: {
                HStack {
                    if viewModel.isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text(viewModel.isBusy ? "In corso..." : "Firma PDF di esempio")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isBusy)
            Spacer()
        }
        .padding()
        .navigationTitle("CIE Sign iOS")
    }
}

#Preview {
    ContentView()
}
