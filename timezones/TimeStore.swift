import SwiftUI
import Combine

struct ZoneDef: Identifiable, Hashable {
    let id: String
    let title: String
    let timeZone: TimeZone

    func abbreviation(for date: Date) -> String {
        if id == "zulu" { return "GMT" }
        return timeZone.abbreviation(for: date) ?? ""
    }
}

final class TimeStore: ObservableObject {
    @Published var baseDate: Date = Date()
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
        ZoneDef(id: "tokyo", title: "Tokyo", timeZone: TimeZone(identifier: "Asia/Tokyo") ?? TimeZone.current),
        ZoneDef(id: "sydney", title: "Sydney", timeZone: TimeZone(identifier: "Australia/Sydney") ?? TimeZone.current),
        ZoneDef(id: "auckland", title: "Auckland", timeZone: TimeZone(identifier: "Pacific/Auckland") ?? TimeZone.current)
    ]

    static let defaultExtras = ["zulu", "central"]

    var localDef: ZoneDef {
        ZoneDef(id: "local", title: "Local", timeZone: TimeZone.autoupdatingCurrent)
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
                if self.isLive {
                    self.baseDate = now
                }
            }
    }

    var localHHmm: String {
        hhmm(for: baseDate, in: localDef.timeZone)
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

    func goLive() {
        baseDate = Date()
        isLive = true
    }

    func pause() {
        isLive = false
    }
}
