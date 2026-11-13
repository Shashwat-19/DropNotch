import AppKit
import IOKit.ps
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import DropNotch

/// Renders the website's pictures and clip frames from DropNotch's own views (website/README.md, "Feature media").
/// Skipped unless `DN_SITE_MEDIA_OUT` names an output folder; `scripts/site-media.sh` sets it and encodes the frames.
/// Every name, track, lyric, event and picture here is invented, so nothing real or copyrighted reaches the site.
@MainActor
final class SiteMediaRenderer: XCTestCase {
    private var out: URL!
    /// Where the progress bar is drawn in the next capture (see `capture`).
    private var barElapsed: TimeInterval = 0
    private let lyricsKey = LRCLibClient.enabledKey
    private var savedLyricsSetting: Any?

    override func setUp() async throws {
        guard let path = ProcessInfo.processInfo.environment["DN_SITE_MEDIA_OUT"] else {
            throw XCTSkip("Set DN_SITE_MEDIA_OUT (scripts/site-media.sh) to render the website media")
        }
        out = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        savedLyricsSetting = UserDefaults.standard.object(forKey: lyricsKey)
        UserDefaults.standard.set(true, forKey: lyricsKey)
    }

    override func tearDown() async throws {
        if out != nil { UserDefaults.standard.set(savedLyricsSetting, forKey: lyricsKey) }
    }

    // MARK: - Fakes

    private final class Players: NowPlayingSource {
        let stream: AsyncStream<NowPlayingInfo?>
        init(_ stream: AsyncStream<NowPlayingInfo?>) { self.stream = stream }
        var updates: AsyncStream<NowPlayingInfo?> { stream }
        func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome { .ok }
        func refresh(_ player: MediaPlayer) {}
    }

    /// Lyrics written for this page; not from any song.
    static let lrc = """
    [00:18.00] Streetlights blur into a gold parade
    [00:22.50] Windows down, the radio half played
    [00:27.00] Every mile we leave the noise behind
    [00:31.50] Humming something we will never find
    [00:36.00]
    [00:39.00] Take the long way, let the evening run
    [00:43.50] Chasing colours of a setting sun
    [00:48.00] Hold the moment, keep it in your hand
    [00:52.50] Some roads only drivers understand
    """

    private final class Lyrics: LyricsSource, @unchecked Sendable {
        func lyrics(title: String, artist: String, duration: TimeInterval?) async throws -> SyncedLyrics? {
            SyncedLyrics(lrc: SiteMediaRenderer.lrc)
        }
    }

    private final class Calendar: CalendarSource {
        var access: CalendarAccess { .allowed }
        func requestAccess() async -> CalendarAccess { .allowed }
        func events(from start: Date, to end: Date) async -> [CalendarEvent] {
            // On the hour after now, so they're upcoming whenever this runs.
            let next = Foundation.Calendar.current.nextDate(after: Date(), matching: DateComponents(minute: 0),
                                                           matchingPolicy: .nextTime) ?? Date()
            func at(_ hours: Double, _ minutes: Double, _ title: String, colour: CGColor) -> CalendarEvent {
                let start = next.addingTimeInterval(hours * 3600)
                return CalendarEvent(id: title, title: title, start: start, end: start.addingTimeInterval(minutes * 60),
                                     isAllDay: false, colour: colour, isHidden: false)
            }
            return [at(0.5, 30, "Stand-up", colour: CGColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)),
                    at(2, 45, "Design review", colour: CGColor(red: 1, green: 0.6, blue: 0.2, alpha: 1)),
                    at(5, 60, "Gym", colour: CGColor(red: 0.4, green: 0.85, blue: 0.4, alpha: 1))]
        }
        var changes: AsyncStream<Void> { AsyncStream { _ in } }
    }

    private struct Weather: WeatherSource {
        func places(matching name: String) async throws -> [WeatherPlace] { [] }
        func reading(at place: WeatherPlace) async throws -> WeatherReading {
            WeatherReading(temperature: 24, high: 28, low: 18, code: 2, isDay: true, airQuality: 64)
        }
    }

    // MARK: - Scenes

    /// The lock-screen player: compact over an illustrated lock screen, then full screen with lyrics filling in.
    func testLockScreen() async throws {
        let (module, feed) = await nowPlaying(at: 18.4, playing: true)
        barElapsed = 18.4
        let screen = CGSize(width: 1470, height: 956)

        // Compact: one frame; the script holds it.
        let compactFrame = LockScreenPlayerWindow.compactFrame(on: CGRect(origin: .zero, size: screen))
        let compact = ZStack(alignment: .topLeading) {
            IllustratedLockScreen()
            CompactLockPlayerView(module: module, expand: {})
                .frame(width: compactFrame.width, height: compactFrame.height)
                .offset(x: compactFrame.minX, y: screen.height - compactFrame.maxY)
        }
        try await render(compact, size: screen, name: "lock-compact")

        // Expanded: 15 frames a second through the first lines.
        let expanded = FullScreenPlayerView(module: module, collapse: {})
        let host = makeHost(expanded, size: screen)
        await module.loadLyrics()
        for frame in 0..<105 {
            barElapsed = 18.4 + Double(frame) / 15
            feed.yield(info(at: barElapsed, playing: true))
            await settle()
            try capture(host, name: String(format: "lock-expanded-%03d", frame))
        }
    }

    /// The Home tab: Now Playing, Calendar and Weather cards in the open notch.
    func testHome() async throws {
        let (nowPlaying, _) = await nowPlaying(at: 102, playing: true)
        barElapsed = 102
        let calendar = CalendarModule(source: Calendar(), defaults: defaults())
        let weather = WeatherModule(source: Weather(), defaults: defaults())
        weather.start()
        weather.choose(WeatherPlace(name: "Bengaluru", region: "Karnataka", country: "India", latitude: 12.97, longitude: 77.59))
        let registry = ModuleRegistry(modules: [HomeModule(), nowPlaying, calendar, weather], defaults: defaults())
        registry.setEnabled("weather", true)
        registry.start()
        await calendar.reload()
        for _ in 0..<200 where weather.reading == nil || calendar.events.isEmpty { await Task.yield() }
        let notch = OpenNotch(width: 676) {
            HomeView().environment(registry)
        }
        try await render(Desktop(content: notch), size: CGSize(width: 1000, height: 300), name: "home")
    }

    /// The Notes tab in the open notch.
    func testNotes() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "dn-site-note-\(UUID()).txt")
        try "Ideas for the weekend\n– Fix the bike's back brake\n– Try the new ramen place on 12th Main\n– Call about the Friday booking"
            .write(to: file, atomically: true, encoding: .utf8)
        let notes = NotesModule(fileURL: file)
        notes.start()
        let notch = OpenNotch(width: 596) { notes.expandedView() }
        try await render(Desktop(content: notch), size: CGSize(width: 1000, height: 300), name: "notes")
    }

    /// The charging alert: the closed notch widens with a bolt and the charge, then closes. Frames for a GIF.
    func testChargingAlert() async throws {
        let (stream, continuation) = AsyncStream.makeStream(of: BatteryStatus?.self)
        let registry = ModuleRegistry(modules: [], defaults: defaults())
        let alert = ChargingAlert(source: Battery(stream: stream), registry: registry, defaults: defaults()) {}
        alert.start()
        continuation.yield(status(onPower: false))
        continuation.yield(status(onPower: true))
        for _ in 0..<500 where registry.hud == nil { await Task.yield() }
        let hud = try XCTUnwrap(registry.hud)
        let notchWidth: CGFloat = 185, wing: CGFloat = 38, height: CGFloat = 34
        // Closed, widen over 5 frames, hold, narrow over 5 frames, closed.
        let steps: [CGFloat] = Array(repeating: 0, count: 8) + (1...5).map { CGFloat($0) / 5 }
            + Array(repeating: 1, count: 30) + (0..<5).reversed().map { CGFloat($0) / 5 } + Array(repeating: 0, count: 8)
        let size = CGSize(width: 600, height: 120)
        for (index, open) in steps.enumerated() {
            let eased = open * open * (3 - 2 * open)
            let width = notchWidth + 2 * wing * eased
            let view = Desktop(content: ZStack {
                NotchShape(shoulder: 6 * eased, bottomRadius: 10).fill(.black)
                HStack(spacing: 0) {
                    hud.leading.frame(width: wing)
                    Spacer(minLength: 0)
                    hud.trailing.frame(width: wing)
                }
                .padding(.horizontal, 6)
                .opacity(Double(eased))
            }
            .frame(width: width, height: height)
            .environment(\.colorScheme, .dark))
            try await render(view, size: size, name: String(format: "charging-%03d", index))
        }
        alert.stop()
    }

    // MARK: - Helpers

    private final class Battery: BatterySource {
        let stream: AsyncStream<BatteryStatus?>
        init(stream: AsyncStream<BatteryStatus?>) { self.stream = stream }
        var updates: AsyncStream<BatteryStatus?> { stream }
    }

    private func status(onPower: Bool) -> BatteryStatus? {
        BatteryStatus(descriptions: [[kIOPSTypeKey: kIOPSInternalBatteryType, kIOPSCurrentCapacityKey: 82,
                                      kIOPSMaxCapacityKey: 100, kIOPSIsChargingKey: onPower,
                                      kIOPSPowerSourceStateKey: onPower ? kIOPSACPowerValue : kIOPSBatteryPowerValue]])
    }

    private func defaults() -> UserDefaults {
        let name = "SiteMedia.\(UUID())"
        return UserDefaults(suiteName: name)!
    }

    private func info(at seconds: TimeInterval, playing: Bool) -> NowPlayingInfo {
        var info = NowPlayingInfo(player: .music, state: playing ? .playing : .paused, title: "Evening Drive",
                                  artist: "Example Artist", trackID: "site-demo", duration: 214,
                                  position: PlaybackPosition(seconds: seconds, at: Date()))
        info.artwork = Self.artwork
        return info
    }

    private func nowPlaying(at seconds: TimeInterval, playing: Bool) async
        -> (NowPlayingModule, AsyncStream<NowPlayingInfo?>.Continuation) {
        let (stream, feed) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        let lyricsDefaults = defaults()
        lyricsDefaults.set(true, forKey: lyricsKey)
        let module = NowPlayingModule(source: Players(stream), lyricsSource: Lyrics(), defaults: lyricsDefaults)
        module.start()
        feed.yield(info(at: seconds, playing: playing))
        for _ in 0..<1000 where module.shown == nil { await Task.yield() }
        return (module, feed)
    }

    /// A made-up cover: a dusk gradient, a low sun and a road.
    static let artwork: NowPlayingArtwork? = {
        let size = 640
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colours = [CGColor(red: 0.16, green: 0.1, blue: 0.35, alpha: 1), CGColor(red: 0.85, green: 0.35, blue: 0.4, alpha: 1),
                       CGColor(red: 1, green: 0.7, blue: 0.35, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 0.6, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: CGFloat(size)), end: CGPoint(x: 0, y: CGFloat(size) * 0.35), options: [.drawsAfterEndLocation])
        context.setFillColor(CGColor(red: 1, green: 0.88, blue: 0.6, alpha: 1))
        context.fillEllipse(in: CGRect(x: 220, y: 200, width: 200, height: 200))
        context.setFillColor(CGColor(red: 0.08, green: 0.06, blue: 0.16, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size, height: 240))
        context.setFillColor(CGColor(red: 1, green: 0.8, blue: 0.4, alpha: 0.9))
        for lane in 0..<6 {
            let y = CGFloat(30 + lane * 34)
            context.fill(CGRect(x: 310 - CGFloat(lane) * 2, y: y, width: 20 - CGFloat(lane) * 2, height: 18))
        }
        let data = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return NowPlayingArtwork(trackID: "site-demo", data: data as Data)
    }()

    private func makeHost<V: View>(_ view: V, size: CGSize) -> NSHostingView<AnyView> {
        let host = NSHostingView(rootView: AnyView(view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)))
        host.sizingOptions = []
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = host
        return host
    }

    private func render<V: View>(_ view: V, size: CGSize, name: String) async throws {
        let host = makeHost(view, size: size)
        await settle()
        try capture(host, name: name)
    }

    /// Lets SwiftUI and the modules' tasks catch up before a frame is taken.
    private func settle() async {
        for _ in 0..<30 { await Task.yield() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
    }

    private func capture(_ host: NSView, name: String) throws {
        host.layoutSubtreeIfNeeded()
        // The progress bar animates on the render server, which a capture doesn't run: draw it where it is now.
        for bar in subviews(of: host).compactMap({ $0 as? ProgressBarView }) {
            bar.update(elapsed: barElapsed, duration: 214, isPlaying: false)
        }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try rep.representation(using: .png, properties: [:])?.write(to: out.appending(path: "\(name).png"))
    }

    private func subviews(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(subviews(of:))
    }
}

/// A plain desktop: a soft wallpaper and a menu bar, with `content` hanging from the top centre like the notch.
private struct Desktop<Content: View>: View {
    let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.16, green: 0.2, blue: 0.36), Color(red: 0.42, green: 0.3, blue: 0.5),
                                    Color(red: 0.85, green: 0.55, blue: 0.5)], startPoint: .top, endPoint: .bottom)
            Rectangle().fill(.black.opacity(0.18)).frame(height: 34)
            content
        }
    }
}

/// The open notch's shape around a tab's content, laid out as the app does (NotchRootView: the top row's strip, the
/// side and bottom margins).
private struct OpenNotch<Content: View>: View {
    let width: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        let shoulder = NotchGeometry.openShoulder
        content
            .padding(.horizontal, NotchStyle.sidePadding)
            .padding(.bottom, NotchStyle.bottomPadding)
            .padding(.top, 38)
            .padding(.horizontal, shoulder)
            .frame(width: width + 2 * shoulder, height: NotchGeometry.openSize.height)
            .background(NotchShape(shoulder: shoulder, bottomRadius: 18).fill(.black))
            .environment(\.colorScheme, .dark)
    }
}

/// An illustration of a lock screen for the compact player to sit on: a wallpaper, a clock and the password prompt.
/// Drawn here, not captured: macOS doesn't allow capturing the real lock screen.
private struct IllustratedLockScreen: View {
    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 0.1, green: 0.16, blue: 0.3), Color(red: 0.35, green: 0.28, blue: 0.45),
                                        Color(red: 0.8, green: 0.5, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 0) {
                    Text("Friday 13 November").font(.system(size: height * 0.024, weight: .semibold))
                    Text("9:41").font(.system(size: height * 0.12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.85))
                .position(x: proxy.size.width / 2, y: height * 0.17)
                VStack(spacing: 8) {
                    Circle().fill(.white.opacity(0.3)).frame(width: 48, height: 48)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 22)).foregroundStyle(.white.opacity(0.8)))
                    Text("Touch ID or Enter Password").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                }
                .position(x: proxy.size.width / 2, y: height * 0.88)
            }
        }
    }
}
