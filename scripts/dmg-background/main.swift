import SwiftUI
import AppKit

/// The DMG window's background (D41): the app icon's gradient and notch, an arrow from the app to Applications, and
/// the first-launch steps. make-dmg.sh places the icons on these marks; move both together.
/// Finder draws icon labels white in Dark Mode and black in Light Mode, so the icon rows sit on a mid-tone
/// (luminance about 0.18), about 4.5:1 for either. The licence files sit last, at y 445: Finder's tab bar and path
/// bar, when a user turns them on, cover the bottom of the window, so nothing needed for installing goes there.
let size = CGSize(width: 640, height: 510)
let appMark = CGPoint(x: 170, y: 150)
let applicationsMark = CGPoint(x: 470, y: 150)

/// A line with a chevron at its right end.
struct Arrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.move(to: CGPoint(x: rect.maxX - rect.height / 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.height / 2, y: rect.maxY))
        return p
    }
}

struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.30, green: 0.42, blue: 1.0), Color(red: 0.42, green: 0.22, blue: 0.92)],
                           startPoint: .top, endPoint: .bottom)
            // Soft light under the notch, as in the icon.
            RadialGradient(colors: [.white.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 320)
            NotchShape(shoulder: 8, bottomRadius: 14).fill(.black)
                .frame(width: 200 + 16, height: 32)
                .position(x: size.width / 2, y: 16)
            Text("Install DropNotch")
                .font(.system(size: 20, weight: .semibold))
                .position(x: size.width / 2, y: 56)
            // Between the two 80 pt icons.
            Arrow().stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: applicationsMark.x - appMark.x - 140, height: 26)
                .position(x: (appMark.x + applicationsMark.x) / 2, y: appMark.y)
            guide
                .frame(width: 560)
                .position(x: size.width / 2, y: 305)
        }
        .foregroundStyle(.white)
        .frame(width: size.width, height: size.height)
    }

    // The wording of the macOS dialogs, as in README › Install. Step 2 checked on macOS 27.0.1 (R1); step 3 not yet.
    private var guide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("First launch").font(.system(size: 14, weight: .semibold))
            step(1, "Drag DropNotch onto Applications.")
            step(2, "Open DropNotch. If macOS says “DropNotch.app” Not Opened, click Done, not Move to Bin (Move to Trash).")
            step(3, "Open System Settings › Privacy & Security, scroll to Security, click Open Anyway and confirm.")
        }
        .font(.system(size: 13))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.25), in: Circle())
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Writes background.png (1x) and background@2x.png into the folder given; make-dmg.sh joins them into one TIFF.
MainActor.assumeIsolated {
    let folder = URL(fileURLWithPath: CommandLine.arguments[1])
    for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
        let renderer = ImageRenderer(content: Background())
        renderer.scale = scale
        let rep = NSBitmapImageRep(cgImage: renderer.cgImage!)
        try! rep.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name))
    }
}
