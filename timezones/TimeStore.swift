import SwiftUI
import Combine
import AppKit

struct ZoneDef: Identifiable, Hashable {
    let id: String
    let title: String
    let timeZone: TimeZone

    func abbreviation(for date: Date) -> String {
        if id == "local" { return "KST" }
        if id == "zulu" { return "GMT" }
        if id == "seoul" { return "KST" }
        if id == "tokyo" { return "JST" }
        if id == "dubai" { return "GST" }
        if id == "honolulu" { return "HST" }
        let abbr = timeZone.abbreviation(for: date) ?? ""
        // macOS returns GMT+X for some Asian zones, prefer common names.
        if abbr.hasPrefix("GMT+") || abbr.hasPrefix("GMT-") {
            if id == "paris" { return "CET" }
            if id == "sydney" { return "AET" }
            if id == "auckland" { return "NZT" }
        }
        return abbr
    }

    func gmtOffsetString(for date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let totalMinutes = seconds / 60
        let sign = totalMinutes >= 0 ? "+" : "-"
        let absMinutes = abs(totalMinutes)
        let hours = absMinutes / 60
        let mins = absMinutes % 60
        if mins == 0 {
            return "\(sign)\(hours)"
        } else {
            return String(format: "%@%d:%02d", sign, hours, mins)
        }
    }
}

final class TimeStore: ObservableObject {
    @Published var baseDate: Date = Date()
    @Published var liveNow: Date = Date()
    @Published var isLive: Bool = true
    @Published var extraIDs: [String] {
        didSet {
            UserDefaults.standard.set(extraIDs, forKey: Self.storageKey)
        }
    }

    private var timerCancellable: AnyCancellable?

    static let storageKey = "extraZoneIDs"
    static let maxExtras = 5

    static let catalog: [ZoneDef] = [
        ZoneDef(id: "zulu", title: "GMT", timeZone: TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!),
        ZoneDef(id: "central", title: "Central", timeZone: TimeZone(identifier: "America/Chicago") ?? TimeZone.current),
        ZoneDef(id: "eastern", title: "Eastern", timeZone: TimeZone(identifier: "America/New_York") ?? TimeZone.current),
        ZoneDef(id: "pacific", title: "Pacific", timeZone: TimeZone(identifier: "America/Los_Angeles") ?? TimeZone.current),
        ZoneDef(id: "mountain", title: "Mountain", timeZone: TimeZone(identifier: "America/Denver") ?? TimeZone.current),
        ZoneDef(id: "honolulu", title: "Honolulu", timeZone: TimeZone(identifier: "Pacific/Honolulu") ?? TimeZone.current),
        ZoneDef(id: "london", title: "London", timeZone: TimeZone(identifier: "Europe/London") ?? TimeZone.current),
        ZoneDef(id: "paris", title: "Paris", timeZone: TimeZone(identifier: "Europe/Paris") ?? TimeZone.current),
        ZoneDef(id: "dubai", title: "Dubai", timeZone: TimeZone(identifier: "Asia/Dubai") ?? TimeZone.current),
        ZoneDef(id: "seoul", title: "Seoul", timeZone: TimeZone(identifier: "Asia/Seoul") ?? TimeZone.current),
        ZoneDef(id: "tokyo", title: "Tokyo", timeZone: TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current),
        ZoneDef(id: "sydney", title: "Sydney", timeZone: TimeZone(identifier: "Australia/Sydney") ?? TimeZone.current),
        ZoneDef(id: "auckland", title: "Auckland", timeZone: TimeZone(identifier: "Pacific/Auckland") ?? TimeZone.current)
    ]

    static let defaultExtras = ["zulu", "central"]

    var localDef: ZoneDef {
        ZoneDef(id: "local", title: "KST", timeZone: TimeZone.autoupdatingCurrent)
    }

    var zones: [ZoneDef] {
        let extras = extraIDs.compactMap { id in
            Self.catalog.first(where: { $0.id == id })
        }
        return [localDef] + extras
    }

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: Self.storageKey)
        if let saved, !saved.isEmpty {
            self.extraIDs = Array(saved.prefix(Self.maxExtras))
        } else {
            self.extraIDs = Self.defaultExtras
        }
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in
                guard let self else { return }
                // Always-live clock for menu bar, independent of edits.
                self.liveNow = now
                if self.isLive {
                    self.baseDate = now
                }
            }
    }

    var localHHmm: String {
        hhmm(for: liveNow, in: localDef.timeZone)
    }

    var menuBarText: String {
        let ymd = yearMonthDay(for: liveNow, in: localDef.timeZone)
        let hm = hhmm(for: liveNow, in: localDef.timeZone)
        return "\(ymd.m)/\(ymd.d) \(hm)"
    }

    func isSelected(id: String) -> Bool {
        extraIDs.contains(id)
    }

    func canAddMore() -> Bool {
        extraIDs.count < Self.maxExtras
    }

    func toggle(id: String) {
        if extraIDs.contains(id) {
            extraIDs.removeAll(where: { $0 == id })
        } else {
            if extraIDs.count < Self.maxExtras {
                extraIDs.append(id)
            }
        }
    }

    func calendar(for timeZone: TimeZone) -> Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }

    func hourMinute(for date: Date, in timeZone: TimeZone) -> (h: Int, m: Int) {
        let cal = calendar(for: timeZone)
        let c = cal.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }

    func yearMonthDay(for date: Date, in timeZone: TimeZone) -> (y: Int, m: Int, d: Int) {
        let cal = calendar(for: timeZone)
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    func hhmm(for date: Date, in timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    func setTime(for zone: ZoneDef, newHour: Int, newMinute: Int) {
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

    func setDate(for zone: ZoneDef, year: Int, month: Int, day: Int) {
        let cal = calendar(for: zone.timeZone)
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: baseDate)
        comps.year = year
        comps.month = month
        comps.day = day
        comps.second = 0
        comps.nanosecond = 0
        guard let newDate = cal.date(from: comps) else { return }
        // Reject overflow normalization (e.g. Feb 30 -> Mar 2).
        let check = cal.dateComponents([.year, .month, .day], from: newDate)
        guard check.year == year, check.month == month, check.day == day else { return }
        baseDate = newDate
        isLive = false
    }

    func stepHour(for zone: ZoneDef, by delta: Int) {
        let cal = calendar(for: zone.timeZone)
        if let newDate = cal.date(byAdding: .hour, value: delta, to: baseDate) {
            baseDate = newDate
        }
        isLive = false
    }

    func stepMinute30(for zone: ZoneDef, by delta: Int) {
        let cal = calendar(for: zone.timeZone)
        let ymd = yearMonthDay(for: baseDate, in: zone.timeZone)
        let hm = hourMinute(for: baseDate, in: zone.timeZone)
        var newH = hm.h
        var newM = hm.m
        var dayOffset = 0
        if delta > 0 {
            if hm.m % 30 == 0 {
                let total = hm.h * 60 + hm.m + 30
                if total >= 24 * 60 {
                    newH = 0
                    newM = 0
                    dayOffset = 1
                } else {
                    newH = total / 60
                    newM = total % 60
                }
            } else if hm.m < 30 {
                newH = hm.h
                newM = 30
            } else {
                // 31...59 -> next hour 00
                if hm.h == 23 {
                    newH = 0
                    newM = 0
                    dayOffset = 1
                } else {
                    newH = hm.h + 1
                    newM = 0
                }
            }
        } else {
            if hm.m % 30 == 0 {
                let total = hm.h * 60 + hm.m - 30
                if total < 0 {
                    newH = 23
                    newM = 30
                    dayOffset = -1
                } else {
                    newH = total / 60
                    newM = total % 60
                }
            } else if hm.m > 30 {
                newH = hm.h
                newM = 30
            } else {
                // 1...29 -> :00 same hour
                newH = hm.h
                newM = 0
            }
        }
        var comps = DateComponents()
        comps.year = ymd.y
        comps.month = ymd.m
        comps.day = ymd.d
        comps.hour = newH
        comps.minute = newM
        comps.second = 0
        comps.nanosecond = 0
        guard let baseInZone = cal.date(from: comps) else { return }
        var finalDate = baseInZone
        if dayOffset != 0 {
            if let shifted = cal.date(byAdding: .day, value: dayOffset, to: baseInZone) {
                finalDate = shifted
            }
        }
        baseDate = finalDate
        isLive = false
    }

    func displayName(for zone: ZoneDef) -> String {
        if zone.id == "zulu" { return "GMT" }
        if zone.id == "local" { return "KST" }
        return "\(zone.title) Time"
    }

    func twelveHour(for date: Date, in timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "h:mm a"
        return f.string(from: date).lowercased()
    }

    func copyLine(for zone: ZoneDef) -> String {
        let ymd = yearMonthDay(for: baseDate, in: zone.timeZone)
        let t = twelveHour(for: baseDate, in: zone.timeZone)
        let abbr = zone.abbreviation(for: baseDate)
        return "\(ymd.m)/\(ymd.d) \(t) (\(abbr))"
    }

    func copySentence(for zone: ZoneDef) -> String {
        return copyLine(for: zone)
    }

    var clipboardText: String {
        zones.map { copySentence(for: $0) }.joined(separator: "\n")
    }

    func copyAllToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(clipboardText, forType: .string)
    }

    func copySingleToClipboard(zone: ZoneDef) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(copySentence(for: zone), forType: .string)
    }

    func goLive() {
        baseDate = Date()
        isLive = true
    }

    func pause() {
        isLive = false
    }
}
