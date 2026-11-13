import SwiftUI

/*
This view's only job is: show the shot's speed, or say the shot wasn't counted.
*/
struct ResultView: View {
    let mph: Double?
    let onAnotherShot: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let mph {
                Text(String(format: "%.1f", mph))
                    .font(.system(size: 80, weight: .black, design: .rounded))
                Text("MPH")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            } else {
                Text("Shot not counted")
                    .font(.title.bold())
            }
            Button("Another Shot", action: onAnotherShot)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    ResultView(mph: 88.5) {}
}
