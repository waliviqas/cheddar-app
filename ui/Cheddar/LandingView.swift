import SwiftUI

/*
This screen's only job is: welcome the user and hand them to their clips.
*/
struct LandingView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    Spacer()
                    Image("Logo")
                        .resizable()
                        .frame(width: 180, height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .shadow(color: Theme.cheddar.opacity(0.25), radius: 30)
                    Text("CHEDDAR")
                        .font(Theme.display(64))
                        .foregroundStyle(.white)
                        .padding(.top, 28)
                    Text("PORTABLE RADAR GUN")
                        .font(.footnote.weight(.semibold))
                        .kerning(4)
                        .foregroundStyle(Theme.cheddar)
                        .padding(.top, 4)
                    Spacer()
                    NavigationLink {
                        ClipLibraryView()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(Theme.navy)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.cheddar, in: Capsule())
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
        }
        .tint(Theme.cheddar)
    }
}

#Preview {
    LandingView()
}
