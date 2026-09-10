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

    private var timerCancellable: AnyCancellable?

    let zones: [ZoneDef] = [
        ZoneDef(id: "local", title: "Local", timeZone: TimeZone.autoupdatingCurrent),
        ZoneDef(id: "zulu", title: "GMT", timeZone: TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!),
        ZoneDef(id: "central", title: "Central", timeZone: TimeZone(identifier: "America/Chicago") ?? TimeZone.current)
    ]

    init() {
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
        hhmm(for: baseDate, in: zones[0].timeZone)
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
