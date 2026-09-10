import SwiftUI
import Combine

struct ZoneDef: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let timeZone: TimeZone

    func abbreviation(for date: Date) -> String {
        if id == "zulu" {
            return "ZULU"
        }
        return timeZone.abbreviation(for: date) ?? ""
    }
}

struct ContentView: View {
    @State private var baseDate: Date = Date()
    @State private var isLive: Bool = true
    @State private var editableZoneID: String = "local"

    private let zones: [ZoneDef] = [
        ZoneDef(
            id: "local",
            title: "Local",
            systemImage: "house",
            timeZone: TimeZone.autoupdatingCurrent
        ),
        ZoneDef(
            id: "zulu",
            title: "Zulu",
            systemImage: "globe",
            timeZone: TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        ),
        ZoneDef(
            id: "central",
            title: "Central",
            systemImage: "building.2",
            timeZone: TimeZone(identifier: "America/Chicago") ?? TimeZone.current
        )
    ]

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            headerView

            Picker("Adjustable clock", selection: $editableZoneID) {
                ForEach(zones) { zone in
                    Text(zone.title).tag(zone.id)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            .help("Only one time can be adjusted at a time")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(zones) { zone in
                    clockCard(for: zone)
                }
            }

            footerView
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(timer) { _ in
            if isLive {
                baseDate = Date()
            }
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Timezones")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("24-hour • bidirectional sync")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(isLive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(isLive ? "Live" : "Paused")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)
                Button(isLive ? "Pause" : "Now") {
                    if isLive {
                        isLive = false
                    } else {
                        baseDate = Date()
                        isLive = true
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var footerView: some View {
        HStack {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("Adjust the selected clock. All other clocks update automatically.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(formattedGlobalDebug)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    private var formattedGlobalDebug: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "HH:mm:ss 'UTC'"
        return f.string(from: baseDate)
    }

    private func clockCard(for zone: ZoneDef) -> some View {
        let comps = hourMinute(for: baseDate, in: zone.timeZone)
        let isEditable = (zone.id == editableZoneID)

        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: zone.systemImage)
                    .foregroundStyle(.secondary)
                Text(zone.title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(zone.abbreviation(for: baseDate))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(timeString(for: baseDate, in: zone.timeZone))
                .font(.system(size: 28, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(dateString(for: baseDate, in: zone.timeZone))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)

            Divider()

            TimeWheelPicker(
                hour: comps.h,
                minute: comps.m,
                isEnabled: isEditable,
                onHourChanged: { newHour in
                    updateBaseDate(for: zone, newHour: newHour, newMinute: comps.m)
                },
                onMinuteChanged: { newMinute in
                    updateBaseDate(for: zone, newHour: comps.h, newMinute: newMinute)
                }
            )
            .opacity(isEditable ? 1.0 : 0.45)

            Text(isEditable ? "Adjustable" : "Synced")
                .font(.system(size: 11))
                .foregroundStyle(isEditable ? .primary : .secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEditable ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func calendar(for timeZone: TimeZone) -> Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }

    private func hourMinute(for date: Date, in timeZone: TimeZone) -> (h: Int, m: Int) {
        let cal = calendar(for: timeZone)
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }

    private func timeString(for date: Date, in timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func dateString(for date: Date, in timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = Locale.current
        f.dateStyle = .medium
        f.timeStyle = .none
        f.dateFormat = "E, MMM d, yyyy"
        return f.string(from: date)
    }

    private func updateBaseDate(for zone: ZoneDef, newHour: Int, newMinute: Int) {
        let cal = calendar(for: zone.timeZone)
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: baseDate)
        comps.hour = newHour
        comps.minute = newMinute
        comps.second = 0
        comps.nanosecond = 0
        if let newDate = cal.date(from: comps) {
            baseDate = newDate
        }
        isLive = false
    }
}
