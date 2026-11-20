import SwiftUI

/*
This view's only job is: show a guest each shot's speed from the recording, or say no shots were found, and let the
player film again with the same corners.
*/
struct ResultView: View {
    let speeds: [Double]
    let onAgain: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if speeds.isEmpty {
                Text("No shots found")
                    .font(.title.bold())
            } else {
                // Scrolls only when there are too many shots to fit.
                ViewThatFits(in: .vertical) {
                    rows
                    ScrollView { rows }
                }
                .frame(maxWidth: 320, maxHeight: 220)
            }
            Button(speeds.isEmpty ? "Try Again" : "Record Again", action: onAgain)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var rows: some View {
        VStack(spacing: 8) {
            ForEach(speeds.indices, id: \.self) { index in
                HStack {
                    Text("Shot \(index + 1)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f MPH", speeds[index]))
                        .font(.title2.bold())
                }
            }
        }
    }
}

#Preview {
    ResultView(speeds: [54.3, 61.8, 58.0]) {}
}
