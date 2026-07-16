import SwiftUI

/*
This screen's only job is: welcome the user and hand them to the camera.
*/
struct LandingView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("🧀")
                    .font(.system(size: 96))
                Text("Cheddar")
                    .font(.largeTitle.bold())
                Text("Your portable hockey radar gun")
                    .foregroundStyle(.secondary)
                NavigationLink("Get Started") {
                    RecordView()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 32)
            }
        }
    }
}

#Preview {
    LandingView()
}
