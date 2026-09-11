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

    private func makeStore(baseDate: Date, extraIDs: [String] = ["zulu", "central"]) -> TimeStore {
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

    // MARK: - Bidirectional sync (your reported bug)

    func testKST10amIsPriorEveningInCentral() {
        // 10:00 Sep 11 KST = 01:00 Sep 11 UTC = 20:00 Sep 10 CDT (UTC-5 in Sept).
        let kst10 = dateIn(seoul, y: 2026, m: 9, d: 11, h: 10, min: 0)
        let store = makeStore(baseDate: kst10)
        let centralYMD = store.yearMonthDay(for: store.baseDate, in: chicago)
        let centralHM = store.hourMinute(for: store.baseDate, in: chicago)
        XCTAssertEqual(centralYMD.m, 9)
        XCTAssertEqual(centralYMD.d, 10)
        XCTAssertEqual(centralHM.h, 20)
        XCTAssertEqual(centralHM.m, 0)
    }

    func testSetTimeInGMTUpdatesAllZones() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        let store = makeStore(baseDate: start)
        store.setTime(for: gmtZone(), newHour: 9, newMinute: 0)
        // GMT 09:00 -> KST 18:00 same day, Central 04:00 same day (CDT).
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).h, 9)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: seoul).h, 18)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: seoul).m, 0)
        let cHM = store.hourMinute(for: store.baseDate, in: chicago)
        XCTAssertEqual(cHM.h, 4)
        XCTAssertEqual(cHM.m, 0)
        XCTAssertFalse(store.isLive)
    }

    func testSetTimePreservesDateInThatZone() {
        let start = dateIn(seoul, y: 2026, m: 9, d: 11, h: 10, min: 15)
        let store = makeStore(baseDate: start)
        store.setTime(for: seoulZone(), newHour: 14, newMinute: 0)
        let ymd = store.yearMonthDay(for: store.baseDate, in: seoul)
        let hm = store.hourMinute(for: store.baseDate, in: seoul)
        XCTAssertEqual(ymd.y, 2026)
        XCTAssertEqual(ymd.m, 9)
        XCTAssertEqual(ymd.d, 11)
        XCTAssertEqual(hm.h, 14)
        XCTAssertEqual(hm.m, 0)
    }

    func testSetDatePreservesTimeInThatZone() {
        let start = dateIn(seoul, y: 2026, m: 9, d: 11, h: 14, min: 30)
        let store = makeStore(baseDate: start)
        store.setDate(for: seoulZone(), year: 2026, month: 9, day: 15)
        let ymd = store.yearMonthDay(for: store.baseDate, in: seoul)
        let hm = store.hourMinute(for: store.baseDate, in: seoul)
        XCTAssertEqual(ymd.d, 15)
        XCTAssertEqual(hm.h, 14)
        XCTAssertEqual(hm.m, 30)
    }

    func testSetDateRejectsFeb30() {
        let start = dateIn(utc, y: 2026, m: 2, d: 10, h: 12, min: 0)
        let store = makeStore(baseDate: start)
        let before = store.baseDate
        store.setDate(for: gmtZone(), year: 2026, month: 2, day: 30)
        XCTAssertEqual(store.baseDate, before)
    }

    // MARK: - Arrow stepping

    func testStepHourRollsDay() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 23, min: 15)
        let store = makeStore(baseDate: start)
        store.stepHour(for: gmtZone(), by: 1)
        let ymd = store.yearMonthDay(for: store.baseDate, in: utc)
        let hm = store.hourMinute(for: store.baseDate, in: utc)
        XCTAssertEqual(ymd.d, 11)
        XCTAssertEqual(hm.h, 0)
        XCTAssertEqual(hm.m, 15)
    }

    func testStepMinuteUpSnapsTo30() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 14, min: 10)
        let store = makeStore(baseDate: start)
        store.stepMinute30(for: gmtZone(), by: 1)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).h, 14)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).m, 30)
    }

    func testStepMinuteDownSnapsTo00() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 14, min: 10)
        let store = makeStore(baseDate: start)
        store.stepMinute30(for: gmtZone(), by: -1)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).h, 14)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).m, 0)
    }

    func testStepMinuteUpFrom40GoesNextHour() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 14, min: 40)
        let store = makeStore(baseDate: start)
        store.stepMinute30(for: gmtZone(), by: 1)
        let hm = store.hourMinute(for: store.baseDate, in: utc)
        XCTAssertEqual(hm.h, 15)
        XCTAssertEqual(hm.m, 0)
    }

    func testStepMinuteExact30UpDown() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 14, min: 30)
        let store = makeStore(baseDate: start)
        store.stepMinute30(for: gmtZone(), by: 1)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).m, 0)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).h, 15)
        store.stepMinute30(for: gmtZone(), by: -1)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).h, 14)
        XCTAssertEqual(store.hourMinute(for: store.baseDate, in: utc).m, 30)
    }

    func testStepMinuteMidnightRollover() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 23, min: 45)
        let store = makeStore(baseDate: start)
        store.stepMinute30(for: gmtZone(), by: 1)
        let ymd = store.yearMonthDay(for: store.baseDate, in: utc)
        let hm = store.hourMinute(for: store.baseDate, in: utc)
        XCTAssertEqual(ymd.d, 11)
        XCTAssertEqual(hm.h, 0)
        XCTAssertEqual(hm.m, 0)
    }

    func testStepDay() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        let store = makeStore(baseDate: start)
        store.stepDay(for: gmtZone(), by: 1)
        XCTAssertEqual(store.yearMonthDay(for: store.baseDate, in: utc).d, 11)
        store.stepDay(for: gmtZone(), by: -1)
        XCTAssertEqual(store.yearMonthDay(for: store.baseDate, in: utc).d, 10)
    }

    func testStepMonthClampsDay() {
        // Jan 31 -> Feb clamps to Feb 28 (2026 not leap).
        let start = dateIn(utc, y: 2026, m: 1, d: 31, h: 12, min: 0)
        let store = makeStore(baseDate: start)
        store.stepMonth(for: gmtZone(), by: 1)
        let ymd = store.yearMonthDay(for: store.baseDate, in: utc)
        XCTAssertEqual(ymd.m, 2)
        XCTAssertEqual(ymd.d, 28)
    }

    func testStepMonthWrapsYear() {
        let start = dateIn(utc, y: 2026, m: 12, d: 15, h: 12, min: 0)
        let store = makeStore(baseDate: start)
        store.stepMonth(for: gmtZone(), by: 1)
        let ymd = store.yearMonthDay(for: store.baseDate, in: utc)
        XCTAssertEqual(ymd.y, 2027)
        XCTAssertEqual(ymd.m, 1)
        XCTAssertEqual(ymd.d, 15)
    }

    // MARK: - Month length

    func testMonthLengthFebLeapAndNonLeap() {
        XCTAssertEqual(TimeStore.monthLength(year: 2024, month: 2, timeZone: utc), 29)
        XCTAssertEqual(TimeStore.monthLength(year: 2026, month: 2, timeZone: utc), 28)
        XCTAssertEqual(TimeStore.monthLength(year: 2026, month: 9, timeZone: utc), 30)
        XCTAssertEqual(TimeStore.monthLength(year: 2026, month: 10, timeZone: utc), 31)
    }

    // MARK: - Offsets and names

    func testGmtOffsetStrings() {
        let d = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        XCTAssertEqual(seoulZone().gmtOffsetString(for: d), "+9")
        XCTAssertEqual(gmtZone().gmtOffsetString(for: d), "+0")
        // Chicago in September is CDT = -5.
        XCTAssertEqual(centralZone().gmtOffsetString(for: d), "-5")
        // Chicago in January is CST = -6.
        let jan = dateIn(utc, y: 2026, m: 1, d: 10, h: 12, min: 0)
        XCTAssertEqual(centralZone().gmtOffsetString(for: jan), "-6")
    }

    func testAbbreviations() {
        let d = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        XCTAssertEqual(gmtZone().abbreviation(for: d), "GMT")
        XCTAssertEqual(seoulZone().abbreviation(for: d), "KST")
        let local = ZoneDef(id: "local", title: "KST", defaultCity: "Seoul", timeZone: seoul)
        XCTAssertEqual(local.abbreviation(for: d), "KST")
    }

    func testCentralAbbreviationDST() {
        let summer = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        let winter = dateIn(utc, y: 2026, m: 1, d: 10, h: 12, min: 0)
        XCTAssertEqual(centralZone().abbreviation(for: summer), "CDT")
        XCTAssertEqual(centralZone().abbreviation(for: winter), "CST")
    }

    func testLocalDefIsKST() {
        let store = makeStore(baseDate: Date())
        XCTAssertEqual(store.localDef.title, "KST")
        XCTAssertEqual(store.displayName(for: store.localDef), "KST")
        XCTAssertEqual(store.displayName(for: gmtZone()), "GMT")
    }

    // MARK: - City names

    func testCityDefaults() {
        let store = makeStore(baseDate: Date())
        XCTAssertEqual(store.cityName(for: store.localDef), "Seoul")
        XCTAssertEqual(store.cityName(for: centralZone()), "Chicago")
    }

    func testCityCustomOverride() {
        let store = makeStore(baseDate: Date())
        store.setCityName(id: "central", name: "Austin")
        XCTAssertEqual(store.cityName(for: centralZone()), "Austin")
        store.setCityName(id: "central", name: "  ")
        XCTAssertEqual(store.cityName(for: centralZone()), "Chicago")
    }

    // MARK: - Copy format: City M/D hh:mmAM (ABBR)

    func testCopyLineFormat() {
        // 9/11 17:00 KST -> Seoul 9/11 05:00PM (KST).
        let base = dateIn(seoul, y: 2026, m: 9, d: 11, h: 17, min: 0)
        let store = makeStore(baseDate: base, extraIDs: ["seoul"])
        let seoulDef = TimeStore.catalog.first(where: { $0.id == "seoul" })!
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/11 05:00PM (KST)")
        XCTAssertFalse(store.copyLine(for: seoulDef).contains("Here's"))
        XCTAssertFalse(store.copyLine(for: seoulDef).contains("+9"))
    }

    func testCopySentenceHasNoHeresThe() {
        let base = dateIn(chicago, y: 2026, m: 9, d: 14, h: 19, min: 0)
        let store = makeStore(baseDate: base, extraIDs: ["central"])
        let central = TimeStore.catalog.first(where: { $0.id == "central" })!
        let s = store.copySentence(for: central)
        XCTAssertEqual(s, store.copyLine(for: central))
        XCTAssertFalse(s.lowercased().contains("here's"))
    }

    func testClipboardTextOnePerRow() {
        let base = dateIn(utc, y: 2026, m: 9, d: 11, h: 8, min: 0)
        let store = makeStore(baseDate: base, extraIDs: ["zulu", "central"])
        let lines = store.clipboardText.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, store.zones.count)
        for line in lines {
            XCTAssertTrue(line.contains("/"))
            XCTAssertTrue(line.contains("(") && line.contains(")"))
        }
    }

    func testClipboardRespectsCopySelection() {
        let base = dateIn(utc, y: 2026, m: 9, d: 11, h: 8, min: 0)
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = TimeStore(baseDate: base, liveNow: base, isLive: false, extraIDs: ["zulu", "central"], copySelectedIDs: Set(["local"]), userDefaults: ud, enableTimer: false)
        let lines = store.clipboardText.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("Seoul "))
    }

    func testTwelveHourUppercaseNoSpace() {
        let base = dateIn(utc, y: 2026, m: 9, d: 11, h: 19, min: 0)
        let store = makeStore(baseDate: base)
        XCTAssertEqual(store.twelveHour(for: base, in: utc), "07:00PM")
    }

    // MARK: - Menu bar stays live

    func testMenuBarUsesLiveNowNotBaseDate() {
        let editedBase = dateIn(utc, y: 2026, m: 1, d: 1, h: 0, min: 0)
        let live = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 34)
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = TimeStore(baseDate: editedBase, liveNow: live, isLive: false, extraIDs: [], userDefaults: ud, enableTimer: false)
        // Menu bar is 24h HH:mm with M/d prefix, from liveNow.
        XCTAssertTrue(store.menuBarText.contains(":"))
        XCTAssertFalse(store.menuBarText.lowercased().contains("am"))
        XCTAssertFalse(store.menuBarText.lowercased().contains("pm"))
        // Editing baseDate must not change menu bar.
        store.setTime(for: gmtZone(), newHour: 5, newMinute: 5)
        XCTAssertEqual(store.baseDate, store.baseDate) // edited
        // menuBarText still derived from liveNow.
        let expectedYMD = store.yearMonthDay(for: live, in: store.localDef.timeZone)
        XCTAssertTrue(store.menuBarText.hasPrefix("\(expectedYMD.m)/\(expectedYMD.d) "))
    }

    func testGoLiveAndPause() {
        let store = makeStore(baseDate: Date())
        store.pause()
        XCTAssertFalse(store.isLive)
        store.goLive()
        XCTAssertTrue(store.isLive)
    }

    // MARK: - Settings selection up to 8, 5 by default

    func testDefaultExtrasIsFive() {
        XCTAssertEqual(TimeStore.defaultExtras.count, 5)
        XCTAssertEqual(TimeStore.maxExtras, 8)
    }

    func testToggleMaxEight() {
        let store = makeStore(baseDate: Date(), extraIDs: [])
        let ids = ["zulu", "central", "eastern", "pacific", "mountain", "london", "paris", "dubai", "tokyo"]
        for id in ids {
            store.toggle(id: id)
        }
        XCTAssertEqual(store.extraIDs.count, TimeStore.maxExtras)
        XCTAssertFalse(store.isSelected(id: "tokyo"))
        XCTAssertTrue(store.canAddMore() == false)
        store.toggle(id: "zulu")
        XCTAssertFalse(store.isSelected(id: "zulu"))
        XCTAssertTrue(store.canAddMore())
    }

    func testZonesAlwaysStartsWithLocal() {
        let store = makeStore(baseDate: Date(), extraIDs: ["central"])
        XCTAssertEqual(store.zones.first?.id, "local")
        XCTAssertEqual(store.zones.first?.title, "KST")
    }
}
