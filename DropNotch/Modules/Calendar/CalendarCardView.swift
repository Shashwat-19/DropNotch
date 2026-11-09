import AppKit
import SwiftUI

/// The Calendar card (D44): the date and today's next events; a click opens Calendar. Before access is allowed it
/// shows the matching way to allow it.
struct CalendarCardView: View {
    let module: CalendarModule
    @Environment(\.openURL) private var openURL
    @FocusState private var focus: Focus?

    /// Fixed heights, so the number of rows that fit can be worked out from the card's height.
    private static let headerHeight: CGFloat = 30
    private static let rowHeight: CGFloat = 14
    private static let rowSpacing: CGFloat = 2

    var body: some View {
        content
            // Inserted on each open (D19), so this runs once per open.
            .onAppear { module.didOpen() }
    }

    @ViewBuilder
    private var content: some View {
        switch module.access {
        case .notDetermined:
            NotchEmptyState("Show today's events", systemImage: "calendar") {
                Button("Allow Calendar", action: requestAccess)
                    .keyboardControl(Focus.allow, focus: $focus, action: requestAccess)
            }
        case .denied:
            NotchEmptyState("Calendar access is off", systemImage: "calendar") {
                Button(action: openPrivacySettings) {
                    // Underlined as well as coloured, so it reads as a link without colour (L6).
                    Text("Allow in System Settings").underline()
                        .frame(minHeight: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.link)
                .font(.subheadline)
                .keyboardControl(Focus.settings, focus: $focus, action: openPrivacySettings)
            }
        case .restricted:
            NotchEmptyState("Calendar access is managed by this Mac's administrator", systemImage: "calendar")
        case .allowed:
            Button(action: openCalendar) { allowed }
                .buttonStyle(.plain)
                .keyboardControl(Focus.card, focus: $focus, action: openCalendar)
                .help("Open Calendar")
                .accessibilityHint(Text("Opens Calendar"))
        }
    }

    private var allowed: some View {
        // Redrawn when an event ends, so it drops off while the notch is open; only while the card is on screen,
        // and the day change reloads the events anyway (D44).
        TimelineView(.explicit(boundaries)) { _ in
            GeometryReader { proxy in
                let now = Date()
                let upcoming = UpcomingEvents(events: module.events, now: now, calendar: .autoupdatingCurrent,
                                              capacity: Self.capacity(height: proxy.size.height))
                VStack(alignment: .leading, spacing: Self.rowSpacing) {
                    header(now: now, hidden: upcoming.hiddenCount)
                        .padding(.bottom, NotchStyle.tightSpacing - Self.rowSpacing)
                    ForEach(Array(upcoming.rows.enumerated()), id: \.offset) { _, row in
                        self.row(row).frame(height: Self.rowHeight)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
        }
        .font(.subheadline)
        .lineLimit(1)
    }

    /// The locale's narrow AM/PM marker, where it has one: "Tomorrow 9:00 AM" left no room for the title.
    private static let time = Date.FormatStyle.dateTime.hour(.defaultDigits(amPM: .narrow)).minute()

    /// Rows under the header; at least one. Three on the Air's 86 pt card and on a 14" MacBook Pro's (D44).
    static func capacity(height: CGFloat) -> Int {
        let space = height - headerHeight - NotchStyle.tightSpacing
        return max(1, Int((space + rowSpacing) / (rowHeight + rowSpacing)))
    }

    /// The ends of today's timed events still to come: the moments the list changes.
    private var boundaries: [Date] {
        let now = Date()
        return module.events.filter { !$0.isAllDay && $0.end > now }.map(\.end).sorted()
    }

    private func header(now: Date, hidden: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(now, format: .dateTime.day())
                .font(.system(size: 30, weight: .semibold).monospacedDigit())
            Text(now.formatted(.dateTime.weekday(.wide)).localizedUppercase)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.red)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if hidden > 0 {
                Text(verbatim: "+\(hidden)")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("\(hidden) more events today"))
            }
        }
        .frame(height: Self.headerHeight)
    }

    @ViewBuilder
    private func row(_ row: UpcomingEvents.Row) -> some View {
        switch row {
        case .allDay(let events):
            line(events.first?.colour, label: Text("All day"),
                 title: module.showsTitles ? events.map(\.title).joined(separator: ", ") : nil,
                 count: module.showsTitles ? nil : events.count)
        case .event(let event):
            line(event.colour, label: Text(event.start, format: Self.time),
                 title: module.showsTitles ? event.title : nil)
        case .noMoreToday:
            Text("No more events today").foregroundStyle(.secondary)
        case .noneToday:
            Text("No events today").foregroundStyle(.secondary)
        case .tomorrow(let event):
            let label = event.isAllDay ? Text("Tomorrow")
                : Text("Tomorrow \(Text(event.start, format: Self.time))")
            line(event.colour, label: label, title: module.showsTitles ? event.title : nil)
        }
    }

    /// The calendar's colour as a bar, the time (or label), then the title unless titles are off (D44).
    private func line(_ colour: CGColor?, label: Text, title: String?, count: Int? = nil) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(colour.map(Color.init(cgColor:)) ?? .accentColor)
                .frame(width: 3)
                .accessibilityHidden(true)
            label
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
            if let title {
                // Verbatim: an event's title is never looked up for translation.
                Text(verbatim: title)
            } else if let count {
                Text(verbatim: "· \(count)")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func requestAccess() {
        Task { await module.requestAccess() }
    }

    private func openCalendar() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func openPrivacySettings() {
        // Undocumented URL [I], as for Automation (D23). If it stops working, the link's text still says where to go.
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            openURL(url)
        }
    }

    private enum Focus: Hashable {
        case allow, settings, card
    }
}
