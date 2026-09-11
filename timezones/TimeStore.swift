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

struct CopyPreset: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var tokens: [CopyToken]
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
    @Published var copyPresets: [CopyPreset] {
        didSet {
            if let data = try? JSONEncoder().encode(copyPresets) {
                userDefaults.set(data, forKey: Self.copyPresetsKey)
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
    static let copyPresetsKey = "copyPresets"
    static let maxExtras = 8

    static let catalog: [ZoneDef] = []

    private static let legacyDefinitions: [String: (city: String, tzID: String)] = [
        "zulu": ("London", "UTC"),
        "central": ("Chicago", "America/Chicago"),
        "eastern": ("New York", "America/New_York"),
        "pacific": ("Los Angeles", "America/Los_Angeles"),
        "mountain": ("Denver", "America/Denver"),
        "honolulu": ("Honolulu", "Pacific/Honolulu"),
        "london": ("London", "Europe/London"),
        "paris": ("Paris", "Europe/Paris"),
        "dubai": ("Dubai", "Asia/Dubai"),
        "seoul": ("Seoul", "Asia/Seoul"),
        "tokyo": ("Tokyo", "Asia/Tokyo"),
        "sydney": ("Sydney", "Australia/Sydney"),
        "auckland": ("Auckland", "Pacific/Auckland")
    ]

    static let defaultExtras: [String] = []
    static let defaultCopyOrder: [CopyToken] = [.city, .date, .time12, .abbr]

    // MARK: - City to time zone guessing (offline, on the fly)
    static let cityTimeZoneMap: [String: String] = [
        "austin": "America/Chicago",
        "dallas": "America/Chicago",
        "houston": "America/Chicago",
        "san antonio": "America/Chicago",
        "chicago": "America/Chicago",
        "minneapolis": "America/Chicago",
        "st louis": "America/Chicago",
        "new orleans": "America/Chicago",
        "memphis": "America/Chicago",
        "nashville": "America/Chicago",
        "kansas city": "America/Chicago",
        "oklahoma city": "America/Chicago",
        "new york": "America/New_York",
        "boston": "America/New_York",
        "philadelphia": "America/New_York",
        "washington": "America/New_York",
        "atlanta": "America/New_York",
        "miami": "America/New_York",
        "orlando": "America/New_York",
        "detroit": "America/New_York",
        "cleveland": "America/New_York",
        "pittsburgh": "America/New_York",
        "charlotte": "America/New_York",
        "los angeles": "America/Los_Angeles",
        "san francisco": "America/Los_Angeles",
        "san diego": "America/Los_Angeles",
        "mountain view": "America/Los_Angeles",
        "cupertino": "America/Los_Angeles",
        "palo alto": "America/Los_Angeles",
        "seattle": "America/Los_Angeles",
        "portland": "America/Los_Angeles",
        "las vegas": "America/Los_Angeles",
        "denver": "America/Denver",
        "salt lake city": "America/Denver",
        "phoenix": "America/Phoenix",
        "honolulu": "Pacific/Honolulu",
        "anchorage": "America/Anchorage",
        "london": "Europe/London",
        "paris": "Europe/Paris",
        "berlin": "Europe/Berlin",
        "rome": "Europe/Rome",
        "madrid": "Europe/Madrid",
        "amsterdam": "Europe/Amsterdam",
        "zurich": "Europe/Zurich",
        "stockholm": "Europe/Stockholm",
        "athens": "Europe/Athens",
        "istanbul": "Europe/Istanbul",
        "dubai": "Asia/Dubai",
        "mumbai": "Asia/Kolkata",
        "delhi": "Asia/Kolkata",
        "kolkata": "Asia/Kolkata",
        "bangkok": "Asia/Bangkok",
        "singapore": "Asia/Singapore",
        "hong kong": "Asia/Hong_Kong",
        "shanghai": "Asia/Shanghai",
        "beijing": "Asia/Shanghai",
        "seoul": "Asia/Seoul",
        "tokyo": "Asia/Tokyo",
        "osaka": "Asia/Tokyo",
        "sydney": "Australia/Sydney",
        "melbourne": "Australia/Melbourne",
        "auckland": "Pacific/Auckland",
        "toronto": "America/Toronto",
        "vancouver": "America/Vancouver",
        "mexico city": "America/Mexico_City",
        "sao paulo": "America/Sao_Paulo",
        "london uk": "Europe/London",
        "gmt": "UTC",
        "utc": "UTC",
        "zulu": "UTC"
    ]

    static func suggestedTimeZoneID(forCity city: String) -> String? {
        let key = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty { return nil }
        if let direct = cityTimeZoneMap[key] { return direct }
        for (k, v) in cityTimeZoneMap where key.contains(k) {
            return v
        }
        return nil
    }

    var localDef: ZoneDef {
        ZoneDef(id: "local", title: "Local", defaultCity: "Local", timeZone: TimeZone.autoupdatingCurrent)
    }

    var allCatalog: [ZoneDef] {
        customZones.compactMap { cz in
            guard let tz = TimeZone(identifier: cz.timeZoneID) else { return nil }
            return ZoneDef(id: cz.id, title: cz.city, defaultCity: cz.city, timeZone: tz)
        }
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
        copyPresets: [CopyPreset]? = nil,
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
        let resolvedCustomCities: [String: String]
        if let customCities {
            resolvedCustomCities = customCities
        } else {
            resolvedCustomCities = (userDefaults.dictionary(forKey: Self.citiesKey) as? [String: String]) ?? [:]
        }
        let loadedCustomZones: [CustomZone]
        if let customZones {
            loadedCustomZones = customZones
        } else if let data = userDefaults.data(forKey: Self.customZonesKey),
                  let decoded = try? JSONDecoder().decode([CustomZone].self, from: data) {
            loadedCustomZones = decoded
        } else {
            loadedCustomZones = []
        }
        var migratedCustom = loadedCustomZones
        for id in resolvedExtraIDs {
            if migratedCustom.contains(where: { $0.id == id }) { continue }
            if let leg = Self.legacyDefinitions[id] {
                let city = resolvedCustomCities[id] ?? leg.city
                if TimeZone(identifier: leg.tzID) != nil {
                    migratedCustom.append(CustomZone(id: id, city: city, timeZoneID: leg.tzID))
                }
            }
        }
        self.extraIDs = resolvedExtraIDs
        self.customCities = resolvedCustomCities
        self.customZones = migratedCustom
        if !migratedCustom.isEmpty && loadedCustomZones.count != migratedCustom.count {
            if let data = try? JSONEncoder().encode(migratedCustom) {
                userDefaults.set(data, forKey: Self.customZonesKey)
            }
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
        if let copyPresets {
            self.copyPresets = copyPresets
        } else if let data = userDefaults.data(forKey: Self.copyPresetsKey),
                  let decoded = try? JSONDecoder().decode([CopyPreset].self, from: data) {
            self.copyPresets = decoded
        } else {
            self.copyPresets = []
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

    func saveCopyPreset(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !copyOrder.isEmpty else { return false }
        if let idx = copyPresets.firstIndex(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            copyPresets[idx].tokens = copyOrder
        } else {
            let p = CopyPreset(id: "preset-" + UUID().uuidString.prefix(8).lowercased(), name: trimmed, tokens: copyOrder)
            copyPresets.append(p)
        }
        return true
    }

    func applyCopyPreset(id: String) {
        if let p = copyPresets.first(where: { $0.id == id }) {
            copyOrder = p.tokens
        }
    }

    func deleteCopyPreset(id: String) {
        copyPresets.removeAll(where: { $0.id == id })
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
