import SwiftUI
import AppKit

/// A teardrop with its tip at the top of `rect`.
struct Drop: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2, cx = rect.midX, cy = rect.maxY - r
        var p = Path()
        p.move(to: CGPoint(x: cx, y: rect.minY))
        p.addCurve(to: CGPoint(x: cx + r, y: cy), control1: CGPoint(x: cx + r * 0.35, y: rect.minY + r * 0.6),
                   control2: CGPoint(x: cx + r, y: cy - r * 0.75))
        p.addArc(center: CGPoint(x: cx, y: cy), radius: r, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(to: CGPoint(x: cx, y: rect.minY), control1: CGPoint(x: cx - r, y: cy - r * 0.75),
                   control2: CGPoint(x: cx - r * 0.35, y: rect.minY + r * 0.6))
        p.closeSubpath()
        return p
    }
}

/// macOS icon grid: a 1024 px canvas, an 824 px body with continuous corners (D38).
struct Icon: View {
    var body: some View {
        let body = RoundedRectangle(cornerRadius: 185, style: .continuous)
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.23, green: 0.47, blue: 1.0), Color(red: 0.42, green: 0.22, blue: 0.92)],
                           startPoint: .top, endPoint: .bottom)
            // Soft light under the notch.
            RadialGradient(colors: [.white.opacity(0.25), .clear], center: .init(x: 0.5, y: 0.25), startRadius: 0, endRadius: 420)
            NotchShape(shoulder: 34, bottomRadius: 70).fill(.black).frame(width: 440 + 68, height: 190)
            // A drop falling into the notch.
            Drop().fill(LinearGradient(colors: [.white, Color(red: 0.72, green: 0.9, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 230, height: 320)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 12)
                .overlay(alignment: .topLeading) {
                    Ellipse().fill(.white.opacity(0.9)).frame(width: 46, height: 74).rotationEffect(.degrees(25)).offset(x: 52, y: 170)
                }
                .padding(.top, 300)
        }
        .frame(width: 824, height: 824)
        .clipShape(body)
        .overlay(body.strokeBorder(.white.opacity(0.15), lineWidth: 2))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .frame(width: 1024, height: 1024)
    }
}

// Writes the 1024 px master to the path given; make-icons.sh scales it to every size.
MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: Icon())
    renderer.scale = 1
    let rep = NSBitmapImageRep(data: renderer.nsImage!.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
}
