import XCTest
@testable import timezones

final class TimeStoreTests: XCTestCase {
    var utc: TimeZone!
    var seoul: TimeZone!
    var chicago: TimeZone!

    override func setUp() {
        super.setUp()
        utc = TimeZone(identifier: "UTC")!
        seoul = TimeZone(identifier: "Asia/Seoul")!
        chicago = TimeZone(identifier: "America/Chicago")!
    }

    private func makeStore(baseDate: Date, extraIDs: [String] = []) -> TimeStore {
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return TimeStore(
            baseDate: baseDate,
            liveNow: baseDate,
            isLive: false,
            extraIDs: extraIDs,
            userDefaults: ud,
            enableTimer: false
        )
    }

    private func dateIn(_ tz: TimeZone, y: Int, m: Int, d: Int, h: Int, min: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var c = DateComponents()
        c.year = y
        c.month = m
        c.day = d
        c.hour = h
        c.minute = min
        c.second = 0
        c.nanosecond = 0
        return cal.date(from: c)!
    }

    private func seoulZone() -> ZoneDef {
        ZoneDef(id: "seoul", title: "Seoul", defaultCity: "Seoul", timeZone: seoul)
    }

    private func gmtZone() -> ZoneDef {
        ZoneDef(id: "zulu", title: "GMT", defaultCity: "London", timeZone: utc)
    }

    private func centralZone() -> ZoneDef {
        ZoneDef(id: "central", title: "Central", defaultCity: "Chicago", timeZone: chicago)
    }

    func testCatalogIsEmptyLocalOnlyByDefault() {
        XCTAssertTrue(TimeStore.catalog.isEmpty)
        XCTAssertTrue(TimeStore.defaultExtras.isEmpty)
        let store = makeStore(baseDate: Date())
        XCTAssertEqual(store.zones.count, 1)
        XCTAssertEqual(store.zones.first?.id, "local")
    }

    func testKST10amIsPriorEveningInCentral() {
        let kst10 = dateIn(seoul, y: 2026, m: 9, d: 11, h: 10, min: 0)
        let store = makeStore(baseDate: kst10)
        let centralYMD = store.yearMonthDay(for: store.baseDate, in: chicago)
        let centralHM = store.hourMinute(for: store.baseDate, in: chicago)
        XCTAssertEqual(centralYMD.m, 9)
        XCTAssertEqual(centralYMD.d, 10)
        XCTAssertEqual(centralHM.h, 20)
        XCTAssertEqual(centralHM.m, 0)
    }

    func testGmtOffsetStrings() {
        let d = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        XCTAssertEqual(seoulZone().gmtOffsetString(for: d), "+9")
        XCTAssertEqual(gmtZone().gmtOffsetString(for: d), "+0")
        XCTAssertEqual(centralZone().gmtOffsetString(for: d), "-5")
        let jan = dateIn(utc, y: 2026, m: 1, d: 10, h: 12, min: 0)
        XCTAssertEqual(centralZone().gmtOffsetString(for: jan), "-6")
    }

    func testAbbreviations() {
        let d = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        XCTAssertEqual(gmtZone().abbreviation(for: d), "GMT")
        XCTAssertEqual(seoulZone().abbreviation(for: d), "KST")
        let local = ZoneDef(id: "local", title: "Local", defaultCity: "Local", timeZone: seoul)
        XCTAssertEqual(local.abbreviation(for: d), "KST")
    }

    func testCopyLineFormat() {
        let base = dateIn(seoul, y: 2026, m: 9, d: 11, h: 17, min: 0)
        let store = makeStore(baseDate: base)
        XCTAssertEqual(store.copyLine(for: seoulZone()), "Seoul 9/11 5:00PM (KST)")
    }

    func testCopySentenceHasNoHeresThe() {
        let base = dateIn(chicago, y: 2026, m: 9, d: 14, h: 19, min: 0)
        let store = makeStore(baseDate: base)
        let s = store.copySentence(for: centralZone())
        XCTAssertEqual(s, store.copyLine(for: centralZone()))
        XCTAssertFalse(s.lowercased().contains("here's"))
    }

    func testDefaultCopyOrder() {
        XCTAssertEqual(TimeStore.defaultCopyOrder, [.city, .date, .time12, .abbr])
    }

    func testCopyPresetsSaveApplyDelete() {
        let store = makeStore(baseDate: Date())
        store.copyOrder = [.city, .date, .time12, .abbr]
        XCTAssertTrue(store.saveCopyPreset(name: "Customers"))
        XCTAssertEqual(store.copyPresets.count, 1)
        XCTAssertEqual(store.copyPresets.first?.name, "Customers")
        store.copyOrder = [.date, .time24]
        XCTAssertTrue(store.saveCopyPreset(name: "Work"))
        XCTAssertEqual(store.copyPresets.count, 2)
        let custID = store.copyPresets.first(where: { $0.name == "Customers" })!.id
        store.applyCopyPreset(id: custID)
        XCTAssertEqual(store.copyOrder, [.city, .date, .time12, .abbr])
        store.deleteCopyPreset(id: custID)
        XCTAssertEqual(store.copyPresets.count, 1)
        XCTAssertFalse(store.saveCopyPreset(name: "   "))
    }

    func testCopyPresetSavesZones() {
        let store = makeStore(baseDate: Date())
        XCTAssertTrue(store.addCustomZone(city: "Austin", timeZoneID: "America/Chicago"))
        XCTAssertTrue(store.addCustomZone(city: "Seoul", timeZoneID: "Asia/Seoul"))
        store.copyOrder = [.city, .date, .time12]
        XCTAssertTrue(store.saveCopyPreset(name: "Family"))
        let preset = store.copyPresets.first(where: { $0.name == "Family" })!
        XCTAssertEqual(preset.tokens, [.city, .date, .time12])
        XCTAssertTrue(preset.zones.map { $0.city }.contains("Austin"))
        XCTAssertTrue(preset.zones.map { $0.city }.contains("Seoul"))
    }

    func testCopyPresetApplyRestoresZonesAndFormat() {
        let store = makeStore(baseDate: Date())
        XCTAssertTrue(store.addCustomZone(city: "Austin", timeZoneID: "America/Chicago"))
        XCTAssertTrue(store.addCustomZone(city: "Seoul", timeZoneID: "Asia/Seoul"))
        store.copyOrder = [.city, .date, .time12]
        XCTAssertTrue(store.saveCopyPreset(name: "Family"))
        let presetID = store.copyPresets.first!.id
        XCTAssertTrue(store.addCustomZone(city: "Beijing", timeZoneID: "Asia/Shanghai"))
        store.copyOrder = [.date, .time24]
        store.applyCopyPreset(id: presetID)
        XCTAssertEqual(store.copyOrder, [.city, .date, .time12])
        let cities = store.zones.map { store.cityName(for: $0) }
        XCTAssertTrue(cities.contains("Austin"))
        XCTAssertTrue(cities.contains("Seoul"))
        XCTAssertFalse(cities.contains("Beijing"))
    }

    func testCopyPresetOverwriteSameName() {
        let store = makeStore(baseDate: Date())
        store.copyOrder = [.city, .date]
        XCTAssertTrue(store.saveCopyPreset(name: "Customers"))
        store.copyOrder = [.date, .time24]
        XCTAssertTrue(store.saveCopyPreset(name: "customers"))
        XCTAssertEqual(store.copyPresets.count, 1)
        XCTAssertEqual(store.copyPresets.first?.tokens, [.date, .time24])
    }

    func testCopyPresetPersistence() {
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let base = dateIn(utc, y: 2026, m: 9, d: 11, h: 8, min: 0)
        let s1 = TimeStore(baseDate: base, liveNow: base, isLive: false, extraIDs: [], copyOrder: [.city, .date], userDefaults: ud, enableTimer: false)
        XCTAssertTrue(s1.saveCopyPreset(name: "Work"))
        let s2 = TimeStore(baseDate: base, liveNow: base, isLive: false, extraIDs: [], userDefaults: ud, enableTimer: false)
        XCTAssertEqual(s2.copyPresets.count, 1)
        XCTAssertEqual(s2.copyPresets.first?.name, "Work")
    }

    func testCityGuessAustin() {
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Austin"), "America/Chicago")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "austin, tx"), "America/Chicago")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Mountain View"), "America/Los_Angeles")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Seoul"), "Asia/Seoul")
        XCTAssertNil(TimeStore.suggestedTimeZoneID(forCity: "NarniaXYZ"))
        XCTAssertNil(TimeStore.suggestedTimeZoneID(forCity: "   "))
    }

    func testCityGuessExpanded() {
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Toledo"), "America/New_York")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Toledo, Ohio"), "America/New_York")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Moscow"), "Europe/Moscow")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Tehran"), "Asia/Tehran")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Frankfurt"), "Europe/Berlin")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "Frankfurt am Main"), "Europe/Berlin")
        XCTAssertEqual(TimeStore.suggestedTimeZoneID(forCity: "America/Chicago"), "America/Chicago")
    }

    func testTwelveHourHasNoLeadingZero() {
        let base = dateIn(seoul, y: 2026, m: 9, d: 15, h: 9, min: 0)
        let store = makeStore(baseDate: base)
        XCTAssertEqual(store.twelveHour(for: base, in: seoul), "9:00AM")
        let evening = dateIn(chicago, y: 2026, m: 9, d: 14, h: 19, min: 0)
        XCTAssertEqual(store.twelveHour(for: evening, in: chicago), "7:00PM")
    }

    func testCustomZoneAddRemove() {
        let store = makeStore(baseDate: Date(), extraIDs: [])
        XCTAssertTrue(store.addCustomZone(city: "Berlin", timeZoneID: "Europe/Berlin"))
        XCTAssertEqual(store.allCatalog.count, 1)
        let id = store.customZones.first!.id
        store.removeCustomZone(id: id)
        XCTAssertTrue(store.customZones.isEmpty)
    }
}
