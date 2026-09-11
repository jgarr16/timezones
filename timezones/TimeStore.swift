import SwiftUI
import Combine
import AppKit

enum CopyToken: String, Codable, CaseIterable, Identifiable {
    case city
    case date
    case dateMDYY
    case dateMDYYYY
    case dateISO
    case monthYear
    case year2
    case year4
    case time12
    case time24
    case abbr
    case offset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .city: return "City"
        case .date: return "Date (M/D)"
        case .dateMDYY: return "Date (M/D/YY)"
        case .dateMDYYYY: return "Date (M/D/YYYY)"
        case .dateISO: return "Date ISO (YYYY-MM-DD)"
        case .monthYear: return "Month/Year (M/YYYY)"
        case .year2: return "Year (YY)"
        case .year4: return "Year (YYYY)"
        case .time12: return "Time 12h (08:30AM)"
        case .time24: return "Time 24h (08:30)"
        case .abbr: return "Abbreviation (KST)"
        case .offset: return "GMT offset (+9)"
        }
    }

    var example: String {
        switch self {
        case .city: return "Seoul"
        case .date: return "9/16"
        case .dateMDYY: return "9/16/26"
        case .dateMDYYYY: return "9/16/2026"
        case .dateISO: return "2026-09-16"
        case .monthYear: return "9/2026"
        case .year2: return "26"
        case .year4: return "2026"
        case .time12: return "08:30AM"
        case .time24: return "08:30"
        case .abbr: return "(KST)"
        case .offset: return "+9"
        }
    }
}

struct CustomZone: Codable, Hashable, Identifiable {
    var id: String
    var city: String
    var timeZoneID: String
}

struct ZoneDef: Identifiable, Hashable {
    let id: String
    let title: String
    let defaultCity: String
    let timeZone: TimeZone

    func abbreviation(for date: Date) -> String {
        if id == "local" {
            let abbr = timeZone.abbreviation(for: date) ?? "Local"
            if abbr.hasPrefix("GMT+") || abbr.hasPrefix("GMT-") {
                if timeZone.identifier == "Asia/Seoul" { return "KST" }
                if timeZone.identifier == "Asia/Tokyo" { return "JST" }
                if timeZone.identifier == "Asia/Dubai" { return "GST" }
            }
            return abbr
        }
        if id == "zulu" { return "GMT" }
        if id == "seoul" { return "KST" }
        if id == "tokyo" { return "JST" }
        if id == "dubai" { return "GST" }
        if id == "honolulu" { return "HST" }
        let abbr = timeZone.abbreviation(for: date) ?? ""
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
    @Published var baseDate: Date
    @Published var liveNow: Date
    @Published var isLive: Bool
    @Published var extraIDs: [String] {
        didSet {
            userDefaults.set(extraIDs, forKey: Self.storageKey)
        }
    }
    @Published var customCities: [String: String] {
        didSet {
            userDefaults.set(customCities, forKey: Self.citiesKey)
        }
    }
    @Published var copySelectedIDs: Set<String> {
        didSet {
            userDefaults.set(Array(copySelectedIDs), forKey: Self.copyKey)
        }
    }
    @Published var copyOrder: [CopyToken] {
        didSet {
            userDefaults.set(copyOrder.map { $0.rawValue }, forKey: Self.copyOrderKey)
        }
    }
    @Published var customZones: [CustomZone] {
        didSet {
            if let data = try? JSONEncoder().encode(customZones) {
                userDefaults.set(data, forKey: Self.customZonesKey)
            }
        }
    }

    private var userDefaults: UserDefaults
    private var timerCancellable: AnyCancellable?

    static let storageKey = "extraZoneIDs"
    static let citiesKey = "customCityNames"
    static let copyKey = "copySelectedIDs"
    static let copyOrderKey = "copyTokenOrder"
    static let customZonesKey = "customZones"
    static let maxExtras = 8

    static let catalog: [ZoneDef] = [
        ZoneDef(id: "zulu", title: "GMT", defaultCity: "London", timeZone: TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!),
        ZoneDef(id: "central", title: "Central", defaultCity: "Chicago", timeZone: TimeZone(identifier: "America/Chicago") ?? TimeZone.current),
        ZoneDef(id: "eastern", title: "Eastern", defaultCity: "New York", timeZone: TimeZone(identifier: "America/New_York") ?? TimeZone.current),
        ZoneDef(id: "pacific", title: "Pacific", defaultCity: "Los Angeles", timeZone: TimeZone(identifier: "America/Los_Angeles") ?? TimeZone.current),
        ZoneDef(id: "mountain", title: "Mountain", defaultCity: "Denver", timeZone: TimeZone(identifier: "America/Denver") ?? TimeZone.current),
        ZoneDef(id: "honolulu", title: "Honolulu", defaultCity: "Honolulu", timeZone: TimeZone(identifier: "Pacific/Honolulu") ?? TimeZone.current),
        ZoneDef(id: "london", title: "London", defaultCity: "London", timeZone: TimeZone(identifier: "Europe/London") ?? TimeZone.current),
        ZoneDef(id: "seoul", title: "Seoul", defaultCity: "Seoul", timeZone: TimeZone(identifier: "Asia/Seoul") ?? TimeZone.current)
    ]

    static let defaultExtras = ["zulu", "central", "eastern", "pacific", "seoul"]
    static let defaultCopyOrder: [CopyToken] = [.city, .date, .time12, .abbr]

    var localDef: ZoneDef {
        ZoneDef(id: "local", title: "Local", defaultCity: "Local", timeZone: TimeZone.autoupdatingCurrent)
    }

    var allCatalog: [ZoneDef] {
        let customs: [ZoneDef] = customZones.compactMap { cz in
            guard let tz = TimeZone(identifier: cz.timeZoneID) else { return nil }
            return ZoneDef(id: cz.id, title: cz.city, defaultCity: cz.city, timeZone: tz)
        }
        return Self.catalog + customs
    }

    var zones: [ZoneDef] {
        let extras = extraIDs.compactMap { id in
            allCatalog.first(where: { $0.id == id })
        }
        return [localDef] + extras
    }

    init(
        baseDate: Date = Date(),
        liveNow: Date? = nil,
        isLive: Bool = true,
        extraIDs: [String]? = nil,
        customCities: [String: String]? = nil,
        copySelectedIDs: Set<String>? = nil,
        copyOrder: [CopyToken]? = nil,
        customZones: [CustomZone]? = nil,
        userDefaults: UserDefaults = .standard,
        enableTimer: Bool = true
    ) {
        self.userDefaults = userDefaults
        let initialBase = baseDate
        self.baseDate = initialBase
        self.liveNow = liveNow ?? initialBase
        self.isLive = isLive
        let resolvedExtraIDs: [String]
        if let extraIDs {
            resolvedExtraIDs = Array(extraIDs.prefix(Self.maxExtras))
        } else {
            let saved = userDefaults.stringArray(forKey: Self.storageKey)
            if let saved, !saved.isEmpty {
                resolvedExtraIDs = Array(saved.prefix(Self.maxExtras))
            } else {
                resolvedExtraIDs = Self.defaultExtras
            }
        }
        self.extraIDs = resolvedExtraIDs
        if let customCities {
            self.customCities = customCities
        } else {
            self.customCities = (userDefaults.dictionary(forKey: Self.citiesKey) as? [String: String]) ?? [:]
        }
        var currentIDs = Set<String>()
        currentIDs.insert("local")
        for id in resolvedExtraIDs {
            currentIDs.insert(id)
        }
        if let copySelectedIDs {
            self.copySelectedIDs = copySelectedIDs
        } else if let savedCopy = userDefaults.stringArray(forKey: Self.copyKey) {
            let filtered = Set(savedCopy).intersection(currentIDs)
            self.copySelectedIDs = filtered.isEmpty ? currentIDs : filtered
        } else {
            self.copySelectedIDs = currentIDs
        }
        if let copyOrder {
            self.copyOrder = copyOrder
        } else if let savedOrder = userDefaults.stringArray(forKey: Self.copyOrderKey) {
            let parsed = savedOrder.compactMap { CopyToken(rawValue: $0) }
            self.copyOrder = parsed.isEmpty ? Self.defaultCopyOrder : parsed
        } else {
            self.copyOrder = Self.defaultCopyOrder
        }
        if let customZones {
            self.customZones = customZones
        } else if let data = userDefaults.data(forKey: Self.customZonesKey),
                  let decoded = try? JSONDecoder().decode([CustomZone].self, from: data) {
            self.customZones = decoded
        } else {
            self.customZones = []
        }
        if enableTimer {
            timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] now in
                    guard let self else { return }
                    self.liveNow = now
                    if self.isLive {
                        self.baseDate = now
                    }
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

    func cityName(for zone: ZoneDef) -> String {
        if let custom = customCities[zone.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return zone.defaultCity
    }

    func setCityName(id: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            customCities.removeValue(forKey: id)
        } else {
            customCities[id] = trimmed
        }
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
            copySelectedIDs.remove(id)
        } else {
            if extraIDs.count < Self.maxExtras {
                extraIDs.append(id)
                copySelectedIDs.insert(id)
            }
        }
    }

    func isCustomZone(id: String) -> Bool {
        customZones.contains(where: { $0.id == id })
    }

    func addCustomZone(city: String, timeZoneID: String) -> Bool {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTZ = timeZoneID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty, !trimmedTZ.isEmpty else { return false }
        guard TimeZone(identifier: trimmedTZ) != nil else { return false }
        guard extraIDs.count < Self.maxExtras else { return false }
        let newID = "custom-" + UUID().uuidString.prefix(8).lowercased()
        let cz = CustomZone(id: String(newID), city: trimmedCity, timeZoneID: trimmedTZ)
        customZones.append(cz)
        extraIDs.append(cz.id)
        copySelectedIDs.insert(cz.id)
        return true
    }

    func removeCustomZone(id: String) {
        customZones.removeAll(where: { $0.id == id })
        extraIDs.removeAll(where: { $0 == id })
        copySelectedIDs.remove(id)
        customCities.removeValue(forKey: id)
    }

    func isCopySelected(id: String) -> Bool {
        copySelectedIDs.contains(id)
    }

    func toggleCopy(id: String) {
        if copySelectedIDs.contains(id) {
            copySelectedIDs.remove(id)
        } else {
            copySelectedIDs.insert(id)
        }
    }

    func isCopyTokenEnabled(_ token: CopyToken) -> Bool {
        copyOrder.contains(token)
    }

    func toggleCopyToken(_ token: CopyToken) {
        if copyOrder.contains(token) {
            copyOrder.removeAll(where: { $0 == token })
        } else {
            copyOrder.append(token)
        }
    }

    func moveCopyTokens(fromOffsets: IndexSet, toOffset: Int) {
        copyOrder.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func moveCopyToken(id: CopyToken, by delta: Int) {
        guard let idx = copyOrder.firstIndex(of: id) else { return }
        let newIdx = idx + delta
        guard newIdx >= 0, newIdx < copyOrder.count else { return }
        copyOrder.move(fromOffsets: IndexSet(integer: idx), toOffset: newIdx > idx ? newIdx + 1 : newIdx)
    }

    func resetCopyFormat() {
        copyOrder = Self.defaultCopyOrder
    }

    func orderedTokensForDisplay() -> [CopyToken] {
        let enabled = copyOrder
        let disabled = CopyToken.allCases.filter { !enabled.contains($0) }
        return enabled + disabled
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

    func stepDay(for zone: ZoneDef, by delta: Int) {
        let cal = calendar(for: zone.timeZone)
        if let shifted = cal.date(byAdding: .day, value: delta, to: baseDate) {
            baseDate = shifted
        }
        isLive = false
    }

    func stepMonth(for zone: ZoneDef, by delta: Int) {
        let cur = yearMonthDay(for: baseDate, in: zone.timeZone)
        var newM = cur.m + delta
        var newY = cur.y
        while newM < 1 {
            newM += 12
            newY -= 1
        }
        while newM > 12 {
            newM -= 12
            newY += 1
        }
        let newD = min(cur.d, Self.monthLength(year: newY, month: newM, timeZone: zone.timeZone))
        setDate(for: zone, year: newY, month: newM, day: newD)
    }

    static func monthLength(year: Int, month: Int, timeZone: TimeZone) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let d = cal.date(from: comps),
              let r = cal.range(of: .day, in: .month, for: d) else {
            return 31
        }
        return r.count
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
        if zone.id == "local" { return "Local Time" }
        return "\(zone.title) Time"
    }

    func twelveHour(for date: Date, in timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "hh:mm a"
        return f.string(from: date).replacingOccurrences(of: " ", with: "").uppercased()
    }

    func tokenString(for token: CopyToken, zone: ZoneDef) -> String {
        let ymd = yearMonthDay(for: baseDate, in: zone.timeZone)
        switch token {
        case .city:
            return cityName(for: zone)
        case .date:
            return "\(ymd.m)/\(ymd.d)"
        case .dateMDYY:
            return "\(ymd.m)/\(ymd.d)/\(String(format: "%02d", ymd.y % 100))"
        case .dateMDYYYY:
            return "\(ymd.m)/\(ymd.d)/\(ymd.y)"
        case .dateISO:
            return String(format: "%04d-%02d-%02d", ymd.y, ymd.m, ymd.d)
        case .monthYear:
            return "\(ymd.m)/\(ymd.y)"
        case .year2:
            return String(format: "%02d", ymd.y % 100)
        case .year4:
            return "\(ymd.y)"
        case .time12:
            return twelveHour(for: baseDate, in: zone.timeZone)
        case .time24:
            return hhmm(for: baseDate, in: zone.timeZone)
        case .abbr:
            return "(\(zone.abbreviation(for: baseDate)))"
        case .offset:
            return zone.gmtOffsetString(for: baseDate)
        }
    }

    func copyLine(for zone: ZoneDef) -> String {
        if copyOrder.isEmpty {
            let ymd = yearMonthDay(for: baseDate, in: zone.timeZone)
            let t = twelveHour(for: baseDate, in: zone.timeZone)
            let abbr = zone.abbreviation(for: baseDate)
            let city = cityName(for: zone)
            return "\(city) \(ymd.m)/\(ymd.d) \(t) (\(abbr))"
        }
        return copyOrder.map { tokenString(for: $0, zone: zone) }.joined(separator: " ")
    }

    func copySentence(for zone: ZoneDef) -> String {
        return copyLine(for: zone)
    }

    var clipboardText: String {
        zones.filter { copySelectedIDs.contains($0.id) }.map { copySentence(for: $0) }.joined(separator: "\n")
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
