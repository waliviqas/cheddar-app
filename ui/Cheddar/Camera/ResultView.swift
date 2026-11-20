import SwiftUI

/*
This view's only job is: say no shots were found in the recording, and let the player film again.
*/
struct ResultView: View {
    let onTryAgain: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("No shots found")
                .font(.title.bold())
            Button("Try Again", action: onTryAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    ResultView {}
}
