import SwiftUI

/*
This screen's only job is: the opening animation when the player comes back after a while. The mouse pops up on the
ice, winds up and rips a cheese puck at the screen; it slams into the glass, freezes as the Cheddar logo, and CHEDDAR
comes up under it. Then it gets out of the way.
*/
struct IntroView: View {
    let onFinish: () -> Void

    @State private var mouseIn = false
    @State private var stickAngle = -25.0
    @State private var lean = 0.0
    @State private var shot = false         // the puck is on its way at the screen
    @State private var hit = false          // it hit the glass: puck swaps for the logo, the rink goes
    @State private var settled = false      // the logo has shrunk back to its normal size
    @State private var nameIn = false
    @State private var flash = 0.0
    @State private var shake: CGFloat = 0
    @State private var clack = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let logoSpot = CGPoint(x: w / 2, y: h / 2 - 37)
            let mouseSpot = CGPoint(x: w * 0.30, y: h * 0.70)
            let puckStart = CGPoint(x: mouseSpot.x + 110, y: mouseSpot.y + 73)  // by his blade
            ZStack {
                Theme.background
                Group {
                    ice(from: mouseSpot.y + 82, width: w, height: h)
                    CheeseMouse(stickAngle: stickAngle)
                        .rotationEffect(.degrees(lean), anchor: .bottom)
                        .scaleEffect(mouseIn ? 1.2 : 0.6, anchor: .bottom)
                        .opacity(mouseIn ? 1 : 0)
                        .position(mouseSpot)
                }
                .opacity(hit ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: hit)
                if !hit {
                    CheesePuck()
                        .scaleEffect(shot ? 2.4 : 0.5)
                        .position(shot ? logoSpot : puckStart)
                        .opacity(mouseIn ? 1 : 0)
                }
                Image("Logo")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .shadow(color: Theme.cheddar.opacity(0.25), radius: 30)
                    .scaleEffect(settled ? 1 : 1.8)
                    .opacity(hit ? 1 : 0)
                    .position(logoSpot)
                Text("CHEDDAR")
                    .font(Theme.display(56))
                    .foregroundStyle(.white)
                    .opacity(nameIn ? 1 : 0)
                    .position(x: w / 2, y: logoSpot.y + 75 + 18 + 30 + (nameIn ? 0 : 12))
                Color.white.opacity(flash).allowsHitTesting(false)
            }
            .offset(x: shake)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy), trigger: clack)
        .sensoryFeedback(.impact(weight: .medium), trigger: hit)
        .task { await play() }
    }

    private func play() async {
        withAnimation(.spring(duration: 0.45, bounce: 0.4)) { mouseIn = true }
        try? await Task.sleep(for: .milliseconds(550))
        withAnimation(.easeOut(duration: 0.35)) { stickAngle = -110; lean = -6 }    // wind up
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeIn(duration: 0.08)) { stickAngle = 20; lean = 4 }        // rip it
        try? await Task.sleep(for: .milliseconds(50))                               // blade meets puck
        clack += 1
        withAnimation(.easeIn(duration: 0.4)) { shot = true }
        try? await Task.sleep(for: .milliseconds(400))
        hit = true                                                                  // into the glass
        flash = 0.7
        withAnimation(.easeOut(duration: 0.3)) { flash = 0 }
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { settled = true }
        for x in [10.0, -8, 6, -3, 0] {
            withAnimation(.linear(duration: 0.04)) { shake = x }
            try? await Task.sleep(for: .milliseconds(40))
        }
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.easeOut(duration: 0.35)) { nameIn = true }
        try? await Task.sleep(for: .milliseconds(1000))
        onFinish()
    }

    // A strip of ice under the mouse with a faint red line.
    private func ice(from top: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Theme.ice.opacity(0.22), Theme.ice.opacity(0.04)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(Theme.goalRed.opacity(0.45)).frame(height: 3).offset(y: 44)
        }
        .frame(width: width, height: height - top)
        .position(x: width / 2, y: top + (height - top) / 2)
    }
}

// The cheese puck in flight: cheddar on top, a darker rind round the side, a few holes.
private struct CheesePuck: View {
    var body: some View {
        let rind = Color(red: 0.85, green: 0.55, blue: 0.10)
        let hole = Color(red: 0.80, green: 0.50, blue: 0.06)
        ZStack {
            Ellipse().fill(rind).frame(width: 64, height: 26).offset(y: 10)
            Rectangle().fill(rind).frame(width: 64, height: 10).offset(y: 5)
            Ellipse().stroke(Theme.navy, lineWidth: 2).frame(width: 64, height: 26).offset(y: 10)
            Ellipse().fill(Theme.cheddar).frame(width: 64, height: 26)
            Ellipse().stroke(Theme.navy, lineWidth: 2).frame(width: 64, height: 26)
            Ellipse().fill(hole).frame(width: 11, height: 4.5).offset(x: -14, y: -3)
            Ellipse().fill(hole).frame(width: 7, height: 3).offset(x: 9, y: -6)
            Ellipse().fill(hole).frame(width: 9, height: 3.5).offset(x: 13, y: 4)
            Circle().fill(hole).frame(width: 5, height: 5).offset(x: -26, y: 14)
            Circle().fill(hole).frame(width: 4, height: 4).offset(x: 20, y: 17)
        }
        .frame(width: 68, height: 42)
    }
}

#Preview {
    IntroView {}
}
