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

    func testSetTimeInGMTUpdatesAllZones() {
        let start = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        let store = makeStore(baseDate: start)
        store.setTime(for: gmtZone(), newHour: 9, newMinute: 0)
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

    func testMonthLengthFebLeapAndNonLeap() {
        XCTAssertEqual(TimeStore.monthLength(year: 2024, month: 2, timeZone: utc), 29)
        XCTAssertEqual(TimeStore.monthLength(year: 2026, month: 2, timeZone: utc), 28)
        XCTAssertEqual(TimeStore.monthLength(year: 2026, month: 9, timeZone: utc), 30)
        XCTAssertEqual(TimeStore.monthLength(year: 2026, month: 10, timeZone: utc), 31)
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

    func testCentralAbbreviationDST() {
        let summer = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 0)
        let winter = dateIn(utc, y: 2026, m: 1, d: 10, h: 12, min: 0)
        XCTAssertEqual(centralZone().abbreviation(for: summer), "CDT")
        XCTAssertEqual(centralZone().abbreviation(for: winter), "CST")
    }

    func testLocalDefIsLocal() {
        let store = makeStore(baseDate: Date())
        XCTAssertEqual(store.localDef.title, "Local")
        XCTAssertEqual(store.localDef.defaultCity, "Local")
        XCTAssertEqual(store.displayName(for: store.localDef), "Local Time")
        XCTAssertEqual(store.displayName(for: gmtZone()), "GMT")
    }

    func testCityDefaults() {
        let store = makeStore(baseDate: Date())
        XCTAssertEqual(store.cityName(for: store.localDef), "Local")
        XCTAssertEqual(store.cityName(for: centralZone()), "Chicago")
    }

    func testCityCustomOverride() {
        let store = makeStore(baseDate: Date())
        store.setCityName(id: "central", name: "Austin")
        XCTAssertEqual(store.cityName(for: centralZone()), "Austin")
        store.setCityName(id: "central", name: "  ")
        XCTAssertEqual(store.cityName(for: centralZone()), "Chicago")
    }

    func testCopyLineFormat() {
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
        XCTAssertTrue(lines[0].hasPrefix("Local "))
    }

    func testTwelveHourUppercaseNoSpace() {
        let base = dateIn(utc, y: 2026, m: 9, d: 11, h: 19, min: 0)
        let store = makeStore(baseDate: base)
        XCTAssertEqual(store.twelveHour(for: base, in: utc), "07:00PM")
    }

    func testMenuBarUsesLiveNowNotBaseDate() {
        let editedBase = dateIn(utc, y: 2026, m: 1, d: 1, h: 0, min: 0)
        let live = dateIn(utc, y: 2026, m: 9, d: 10, h: 12, min: 34)
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = TimeStore(baseDate: editedBase, liveNow: live, isLive: false, extraIDs: [], userDefaults: ud, enableTimer: false)
        XCTAssertTrue(store.menuBarText.contains(":"))
        XCTAssertFalse(store.menuBarText.lowercased().contains("am"))
        XCTAssertFalse(store.menuBarText.lowercased().contains("pm"))
        store.setTime(for: gmtZone(), newHour: 5, newMinute: 5)
        XCTAssertEqual(store.baseDate, store.baseDate)
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

    func testDefaultExtrasIsFive() {
        XCTAssertEqual(TimeStore.defaultExtras.count, 5)
        XCTAssertEqual(TimeStore.maxExtras, 8)
    }

    func testToggleMaxEight() {
        let store = makeStore(baseDate: Date(), extraIDs: [])
        let ids = ["zulu", "central", "eastern", "pacific", "mountain", "honolulu", "london", "seoul"]
        for id in ids {
            store.toggle(id: id)
        }
        XCTAssertEqual(store.extraIDs.count, TimeStore.maxExtras)
        XCTAssertFalse(store.canAddMore())
        store.toggle(id: "zulu")
        XCTAssertFalse(store.isSelected(id: "zulu"))
        XCTAssertTrue(store.canAddMore())
    }

    func testZonesAlwaysStartsWithLocal() {
        let store = makeStore(baseDate: Date(), extraIDs: ["central"])
        XCTAssertEqual(store.zones.first?.id, "local")
        XCTAssertEqual(store.zones.first?.title, "Local")
    }

    func testDefaultCopyOrder() {
        XCTAssertEqual(TimeStore.defaultCopyOrder, [.city, .date, .time12, .abbr])
        let store = makeStore(baseDate: Date())
        XCTAssertEqual(store.copyOrder, TimeStore.defaultCopyOrder)
    }

    func testCopyOrderReorderChangesOutput() {
        let base = dateIn(seoul, y: 2026, m: 9, d: 16, h: 8, min: 30)
        let store = makeStore(baseDate: base, extraIDs: ["seoul"])
        let seoulDef = TimeStore.catalog.first(where: { $0.id == "seoul" })!
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/16 08:30AM (KST)")
        store.copyOrder = [.date, .time12, .city, .abbr]
        XCTAssertEqual(store.copyLine(for: seoulDef), "9/16 08:30AM Seoul (KST)")
    }

    func testCopyTokenDeselectRemovesPart() {
        let base = dateIn(seoul, y: 2026, m: 9, d: 16, h: 8, min: 30)
        let store = makeStore(baseDate: base, extraIDs: ["seoul"])
        let seoulDef = TimeStore.catalog.first(where: { $0.id == "seoul" })!
        store.toggleCopyToken(.abbr)
        XCTAssertFalse(store.isCopyTokenEnabled(.abbr))
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/16 08:30AM")
        store.toggleCopyToken(.time24)
        XCTAssertTrue(store.copyLine(for: seoulDef).contains("08:30"))
    }

    func testCopyTime24AndOffsetTokens() {
        let base = dateIn(seoul, y: 2026, m: 9, d: 16, h: 8, min: 30)
        let store = makeStore(baseDate: base, extraIDs: ["seoul"])
        let seoulDef = TimeStore.catalog.first(where: { $0.id == "seoul" })!
        store.copyOrder = [.city, .date, .time24, .offset]
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/16 08:30 +9")
    }

    func testYearTokens() {
        let base = dateIn(seoul, y: 2026, m: 9, d: 16, h: 8, min: 30)
        let store = makeStore(baseDate: base, extraIDs: ["seoul"])
        let seoulDef = TimeStore.catalog.first(where: { $0.id == "seoul" })!
        store.copyOrder = [.city, .date, .year2]
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/16 26")
        store.copyOrder = [.city, .date, .year4]
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/16 2026")
    }

    func testDateVariantTokens() {
        let base = dateIn(seoul, y: 2026, m: 9, d: 16, h: 8, min: 30)
        let store = makeStore(baseDate: base, extraIDs: ["seoul"])
        let seoulDef = TimeStore.catalog.first(where: { $0.id == "seoul" })!
        store.copyOrder = [.city, .dateMDYY, .time12]
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/16/26 08:30AM")
        store.copyOrder = [.city, .dateMDYYYY, .time12]
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/16/2026 08:30AM")
        store.copyOrder = [.city, .dateISO, .time12]
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 2026-09-16 08:30AM")
        store.copyOrder = [.city, .monthYear, .time12]
        XCTAssertEqual(store.copyLine(for: seoulDef), "Seoul 9/2026 08:30AM")
    }

    func testMoveCopyToken() {
        let store = makeStore(baseDate: Date())
        store.copyOrder = [.city, .date, .time12, .abbr]
        store.moveCopyToken(id: .abbr, by: -2)
        XCTAssertEqual(store.copyOrder, [.city, .abbr, .date, .time12])
        store.moveCopyTokens(fromOffsets: IndexSet(integer: 0), toOffset: 4)
        XCTAssertEqual(store.copyOrder.first, .abbr)
    }

    func testResetCopyFormat() {
        let store = makeStore(baseDate: Date())
        store.copyOrder = [.date]
        store.resetCopyFormat()
        XCTAssertEqual(store.copyOrder, TimeStore.defaultCopyOrder)
    }

    func testCopyOrderPersistence() {
        let ud = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let base = dateIn(utc, y: 2026, m: 9, d: 11, h: 8, min: 0)
        let s1 = TimeStore(baseDate: base, liveNow: base, isLive: false, extraIDs: [], copyOrder: [.date, .time12], userDefaults: ud, enableTimer: false)
        XCTAssertEqual(s1.copyOrder, [.date, .time12])
        let s2 = TimeStore(baseDate: base, liveNow: base, isLive: false, extraIDs: [], userDefaults: ud, enableTimer: false)
        XCTAssertEqual(s2.copyOrder, [.date, .time12])
    }

    func testCustomZoneAddRemove() {
        let store = makeStore(baseDate: Date(), extraIDs: [])
        XCTAssertTrue(store.addCustomZone(city: "Berlin", timeZoneID: "Europe/Berlin"))
        XCTAssertEqual(store.allCatalog.count, TimeStore.catalog.count + 1)
        XCTAssertTrue(store.isSelected(id: store.customZones.first!.id))
        XCTAssertFalse(store.addCustomZone(city: "Bad", timeZoneID: "Not/AZone"))
        let id = store.customZones.first!.id
        store.removeCustomZone(id: id)
        XCTAssertTrue(store.customZones.isEmpty)
        XCTAssertFalse(store.isSelected(id: id))
    }

    func testOrderedTokensForDisplay() {
        let store = makeStore(baseDate: Date())
        store.copyOrder = [.date, .city]
        let display = store.orderedTokensForDisplay()
        XCTAssertEqual(Array(display.prefix(2)), [.date, .city])
        XCTAssertEqual(display.count, CopyToken.allCases.count)
    }
}
