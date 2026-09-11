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
    case gmtParen

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
        case .time12: return "Time 12h (8:30AM)"
        case .time24: return "Time 24h (08:30)"
        case .abbr: return "Abbreviation (KST)"
        case .offset: return "GMT offset (+9)"
        case .gmtParen: return "GMT offset in parens ((GMT+8))"
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
        case .time12: return "8:30AM"
        case .time24: return "08:30"
        case .abbr: return "(KST)"
        case .offset: return "+9"
        case .gmtParen: return "(GMT+8)"
        }
    }
}

struct PresetZoneEntry: Codable, Hashable {
    var city: String
    var timeZoneID: String
    var isCopySelected: Bool

    static let localID = "__local__"
}

struct CopyPreset: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var tokens: [CopyToken]
    var zones: [PresetZoneEntry]

    init(id: String, name: String, tokens: [CopyToken], zones: [PresetZoneEntry] = []) {
        self.id = id
        self.name = name
        self.tokens = tokens
        self.zones = zones
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tokens
        case zones
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        tokens = try c.decode([CopyToken].self, forKey: .tokens)
        zones = try c.decodeIfPresent([PresetZoneEntry].self, forKey: .zones) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(tokens, forKey: .tokens)
        try c.encode(zones, forKey: .zones)
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
                if timeZone.identifier == "Asia/Shanghai" { return "CST" }
            }
            return abbr
        }
        if id == "zulu" { return "GMT" }
        if id == "seoul" { return "KST" }
        if id == "tokyo" { return "JST" }
        if id == "dubai" { return "GST" }
        if id == "honolulu" { return "HST" }
        if timeZone.identifier == "Asia/Shanghai" { return "CST" }
        if timeZone.identifier == "Asia/Seoul" { return "KST" }
        if timeZone.identifier == "Asia/Tokyo" { return "JST" }
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

    func gmtParenString(for date: Date) -> String {
        return "(GMT\(gmtOffsetString(for: date)))"
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

    static let cityTimeZoneMap: [String: String] = [
        "austin": "America/Chicago",
        "dallas": "America/Chicago",
        "fort worth": "America/Chicago",
        "houston": "America/Chicago",
        "san antonio": "America/Chicago",
        "lubbock": "America/Chicago",
        "amarillo": "America/Chicago",
        "corpus christi": "America/Chicago",
        "plano": "America/Chicago",
        "arlington": "America/Chicago",
        "chicago": "America/Chicago",
        "minneapolis": "America/Chicago",
        "st paul": "America/Chicago",
        "st louis": "America/Chicago",
        "saint louis": "America/Chicago",
        "new orleans": "America/Chicago",
        "baton rouge": "America/Chicago",
        "shreveport": "America/Chicago",
        "memphis": "America/Chicago",
        "nashville": "America/Chicago",
        "knoxville": "America/New_York",
        "chattanooga": "America/New_York",
        "kansas city": "America/Chicago",
        "oklahoma city": "America/Chicago",
        "tulsa": "America/Chicago",
        "little rock": "America/Chicago",
        "des moines": "America/Chicago",
        "omaha": "America/Chicago",
        "lincoln": "America/Chicago",
        "wichita": "America/Chicago",
        "fargo": "America/Chicago",
        "bismarck": "America/Chicago",
        "sioux falls": "America/Chicago",
        "birmingham": "America/Chicago",
        "montgomery": "America/Chicago",
        "mobile": "America/Chicago",
        "jackson": "America/Chicago",
        "green bay": "America/Chicago",
        "milwaukee": "America/Chicago",
        "madison": "America/Chicago",
        "new york": "America/New_York",
        "nyc": "America/New_York",
        "brooklyn": "America/New_York",
        "queens": "America/New_York",
        "boston": "America/New_York",
        "philadelphia": "America/New_York",
        "philly": "America/New_York",
        "pittsburgh": "America/New_York",
        "washington": "America/New_York",
        "washington dc": "America/New_York",
        "baltimore": "America/New_York",
        "atlanta": "America/New_York",
        "savannah": "America/New_York",
        "miami": "America/New_York",
        "orlando": "America/New_York",
        "tampa": "America/New_York",
        "jacksonville": "America/New_York",
        "tallahassee": "America/New_York",
        "charlotte": "America/New_York",
        "raleigh": "America/New_York",
        "durham": "America/New_York",
        "richmond": "America/New_York",
        "norfolk": "America/New_York",
        "virginia beach": "America/New_York",
        "detroit": "America/New_York",
        "cleveland": "America/New_York",
        "columbus": "America/New_York",
        "cincinnati": "America/New_York",
        "dayton": "America/New_York",
        "toledo": "America/New_York",
        "akron": "America/New_York",
        "indianapolis": "America/Indiana/Indianapolis",
        "louisville": "America/Kentucky/Louisville",
        "lexington": "America/New_York",
        "albany": "America/New_York",
        "buffalo": "America/New_York",
        "rochester": "America/New_York",
        "syracuse": "America/New_York",
        "newark": "America/New_York",
        "trenton": "America/New_York",
        "hartford": "America/New_York",
        "providence": "America/New_York",
        "portland me": "America/New_York",
        "portland, maine": "America/New_York",
        "burlington": "America/New_York",
        "concord": "America/New_York",
        "montpelier": "America/New_York",
        "augusta me": "America/New_York",
        "dover": "America/New_York",
        "annapolis": "America/New_York",
        "charleston wv": "America/New_York",
        "los angeles": "America/Los_Angeles",
        "long beach": "America/Los_Angeles",
        "anaheim": "America/Los_Angeles",
        "san francisco": "America/Los_Angeles",
        "san jose": "America/Los_Angeles",
        "oakland": "America/Los_Angeles",
        "sacramento": "America/Los_Angeles",
        "fresno": "America/Los_Angeles",
        "bakersfield": "America/Los_Angeles",
        "san diego": "America/Los_Angeles",
        "santa clara": "America/Los_Angeles",
        "sunnyvale": "America/Los_Angeles",
        "mountain view": "America/Los_Angeles",
        "cupertino": "America/Los_Angeles",
        "palo alto": "America/Los_Angeles",
        "menlo park": "America/Los_Angeles",
        "seattle": "America/Los_Angeles",
        "tacoma": "America/Los_Angeles",
        "bellevue": "America/Los_Angeles",
        "spokane": "America/Los_Angeles",
        "portland or": "America/Los_Angeles",
        "portland, oregon": "America/Los_Angeles",
        "eugene": "America/Los_Angeles",
        "salem": "America/Los_Angeles",
        "las vegas": "America/Los_Angeles",
        "reno": "America/Los_Angeles",
        "henderson": "America/Los_Angeles",
        "denver": "America/Denver",
        "colorado springs": "America/Denver",
        "boulder": "America/Denver",
        "aurora": "America/Denver",
        "salt lake city": "America/Denver",
        "boise": "America/Boise",
        "cheyenne": "America/Denver",
        "billings": "America/Denver",
        "missoula": "America/Denver",
        "helena": "America/Denver",
        "albuquerque": "America/Denver",
        "santa fe": "America/Denver",
        "el paso": "America/Denver",
        "jackson wy": "America/Denver",
        "phoenix": "America/Phoenix",
        "tucson": "America/Phoenix",
        "mesa": "America/Phoenix",
        "scottsdale": "America/Phoenix",
        "flagstaff": "America/Phoenix",
        "chandler": "America/Phoenix",
        "glendale": "America/Phoenix",
        "honolulu": "Pacific/Honolulu",
        "hilo": "Pacific/Honolulu",
        "maui": "Pacific/Honolulu",
        "kailua": "Pacific/Honolulu",
        "anchorage": "America/Anchorage",
        "juneau": "America/Juneau",
        "fairbanks": "America/Anchorage",
        "toronto": "America/Toronto",
        "ottawa": "America/Toronto",
        "montreal": "America/Toronto",
        "quebec city": "America/Toronto",
        "quebec": "America/Toronto",
        "halifax": "America/Halifax",
        "winnipeg": "America/Winnipeg",
        "calgary": "America/Edmonton",
        "edmonton": "America/Edmonton",
        "vancouver": "America/Vancouver",
        "victoria bc": "America/Vancouver",
        "mexico city": "America/Mexico_City",
        "guadalajara": "America/Mexico_City",
        "monterrey": "America/Monterrey",
        "cancun": "America/Cancun",
        "tijuana": "America/Tijuana",
        "havana": "America/Havana",
        "sao paulo": "America/Sao_Paulo",
        "rio de janeiro": "America/Sao_Paulo",
        "brasilia": "America/Sao_Paulo",
        "salvador": "America/Bahia",
        "buenos aires": "America/Argentina/Buenos_Aires",
        "santiago": "America/Santiago",
        "lima": "America/Lima",
        "bogota": "America/Bogota",
        "quito": "America/Guayaquil",
        "caracas": "America/Caracas",
        "panama city": "America/Panama",
        "san jose costa rica": "America/Costa_Rica",
        "london": "Europe/London",
        "manchester": "Europe/London",
        "birmingham uk": "Europe/London",
        "leeds": "Europe/London",
        "liverpool": "Europe/London",
        "bristol": "Europe/London",
        "edinburgh": "Europe/London",
        "glasgow": "Europe/London",
        "cardiff": "Europe/London",
        "belfast": "Europe/London",
        "dublin": "Europe/Dublin",
        "cork": "Europe/Dublin",
        "lisbon": "Europe/Lisbon",
        "porto": "Europe/Lisbon",
        "paris": "Europe/Paris",
        "lyon": "Europe/Paris",
        "marseille": "Europe/Paris",
        "berlin": "Europe/Berlin",
        "frankfurt": "Europe/Berlin",
        "munich": "Europe/Berlin",
        "hamburg": "Europe/Berlin",
        "cologne": "Europe/Berlin",
        "dusseldorf": "Europe/Berlin",
        "stuttgart": "Europe/Berlin",
        "nuremberg": "Europe/Berlin",
        "rome": "Europe/Rome",
        "milan": "Europe/Rome",
        "naples": "Europe/Rome",
        "turin": "Europe/Rome",
        "florence": "Europe/Rome",
        "venice": "Europe/Rome",
        "madrid": "Europe/Madrid",
        "barcelona": "Europe/Madrid",
        "seville": "Europe/Madrid",
        "valencia": "Europe/Madrid",
        "bilbao": "Europe/Madrid",
        "amsterdam": "Europe/Amsterdam",
        "rotterdam": "Europe/Amsterdam",
        "brussels": "Europe/Brussels",
        "antwerp": "Europe/Brussels",
        "luxembourg": "Europe/Luxembourg",
        "zurich": "Europe/Zurich",
        "geneva": "Europe/Zurich",
        "bern": "Europe/Zurich",
        "vienna": "Europe/Vienna",
        "salzburg": "Europe/Vienna",
        "prague": "Europe/Prague",
        "brno": "Europe/Prague",
        "warsaw": "Europe/Warsaw",
        "krakow": "Europe/Warsaw",
        "gdansk": "Europe/Warsaw",
        "budapest": "Europe/Budapest",
        "bucharest": "Europe/Bucharest",
        "sofia": "Europe/Sofia",
        "athens": "Europe/Athens",
        "thessaloniki": "Europe/Athens",
        "istanbul": "Europe/Istanbul",
        "ankara": "Europe/Istanbul",
        "izmir": "Europe/Istanbul",
        "moscow": "Europe/Moscow",
        "saint petersburg": "Europe/Moscow",
        "st petersburg": "Europe/Moscow",
        "novosibirsk": "Asia/Novosibirsk",
        "yekaterinburg": "Asia/Yekaterinburg",
        "kyiv": "Europe/Kyiv",
        "kiev": "Europe/Kyiv",
        "kharkiv": "Europe/Kyiv",
        "odesa": "Europe/Kyiv",
        "odessa": "Europe/Kyiv",
        "minsk": "Europe/Minsk",
        "riga": "Europe/Riga",
        "vilnius": "Europe/Vilnius",
        "tallinn": "Europe/Tallinn",
        "helsinki": "Europe/Helsinki",
        "espoo": "Europe/Helsinki",
        "stockholm": "Europe/Stockholm",
        "gothenburg": "Europe/Stockholm",
        "malmo": "Europe/Stockholm",
        "oslo": "Europe/Oslo",
        "bergen": "Europe/Oslo",
        "copenhagen": "Europe/Copenhagen",
        "aarhus": "Europe/Copenhagen",
        "reykjavik": "Atlantic/Reykjavik",
        "cairo": "Africa/Cairo",
        "alexandria": "Africa/Cairo",
        "giza": "Africa/Cairo",
        "johannesburg": "Africa/Johannesburg",
        "cape town": "Africa/Johannesburg",
        "durban": "Africa/Johannesburg",
        "pretoria": "Africa/Johannesburg",
        "nairobi": "Africa/Nairobi",
        "addis ababa": "Africa/Addis_Ababa",
        "lagos": "Africa/Lagos",
        "abuja": "Africa/Lagos",
        "accra": "Africa/Accra",
        "dakar": "Africa/Dakar",
        "casablanca": "Africa/Casablanca",
        "rabat": "Africa/Casablanca",
        "marrakech": "Africa/Casablanca",
        "algiers": "Africa/Algiers",
        "tunis": "Africa/Tunis",
        "tripoli": "Africa/Tripoli",
        "khartoum": "Africa/Khartoum",
        "kampala": "Africa/Kampala",
        "dar es salaam": "Africa/Dar_es_Salaam",
        "tel aviv": "Asia/Jerusalem",
        "jerusalem": "Asia/Jerusalem",
        "haifa": "Asia/Jerusalem",
        "amman": "Asia/Amman",
        "beirut": "Asia/Beirut",
        "damascus": "Asia/Damascus",
        "baghdad": "Asia/Baghdad",
        "basra": "Asia/Baghdad",
        "riyadh": "Asia/Riyadh",
        "jeddah": "Asia/Riyadh",
        "mecca": "Asia/Riyadh",
        "medina": "Asia/Riyadh",
        "doha": "Asia/Qatar",
        "kuwait city": "Asia/Kuwait",
        "kuwait": "Asia/Kuwait",
        "manama": "Asia/Bahrain",
        "muscat": "Asia/Muscat",
        "dubai": "Asia/Dubai",
        "abu dhabi": "Asia/Dubai",
        "sharjah": "Asia/Dubai",
        "tehran": "Asia/Tehran",
        "isfahan": "Asia/Tehran",
        "mashhad": "Asia/Tehran",
        "karaj": "Asia/Tehran",
        "baku": "Asia/Baku",
        "tbilisi": "Asia/Tbilisi",
        "yerevan": "Asia/Yerevan",
        "tashkent": "Asia/Tashkent",
        "almaty": "Asia/Almaty",
        "astana": "Asia/Almaty",
        "bishkek": "Asia/Bishkek",
        "karachi": "Asia/Karachi",
        "lahore": "Asia/Karachi",
        "islamabad": "Asia/Karachi",
        "faisalabad": "Asia/Karachi",
        "mumbai": "Asia/Kolkata",
        "bombay": "Asia/Kolkata",
        "delhi": "Asia/Kolkata",
        "new delhi": "Asia/Kolkata",
        "kolkata": "Asia/Kolkata",
        "calcutta": "Asia/Kolkata",
        "chennai": "Asia/Kolkata",
        "bangalore": "Asia/Kolkata",
        "bengaluru": "Asia/Kolkata",
        "hyderabad": "Asia/Kolkata",
        "ahmedabad": "Asia/Kolkata",
        "pune": "Asia/Kolkata",
        "jaipur": "Asia/Kolkata",
        "lucknow": "Asia/Kolkata",
        "kanpur": "Asia/Kolkata",
        "nagpur": "Asia/Kolkata",
        "surat": "Asia/Kolkata",
        "dhaka": "Asia/Dhaka",
        "chittagong": "Asia/Dhaka",
        "kathmandu": "Asia/Kathmandu",
        "pokhara": "Asia/Kathmandu",
        "colombo": "Asia/Colombo",
        "kandy": "Asia/Colombo",
        "male": "Indian/Maldives",
        "thimphu": "Asia/Thimphu",
        "yangon": "Asia/Yangon",
        "rangoon": "Asia/Yangon",
        "naypyidaw": "Asia/Yangon",
        "mandalay": "Asia/Yangon",
        "bangkok": "Asia/Bangkok",
        "phuket": "Asia/Bangkok",
        "chiang mai": "Asia/Bangkok",
        "pattaya": "Asia/Bangkok",
        "hanoi": "Asia/Bangkok",
        "ho chi minh": "Asia/Ho_Chi_Minh",
        "saigon": "Asia/Ho_Chi_Minh",
        "da nang": "Asia/Ho_Chi_Minh",
        "phnom penh": "Asia/Phnom_Penh",
        "siem reap": "Asia/Phnom_Penh",
        "vientiane": "Asia/Vientiane",
        "kuala lumpur": "Asia/Kuala_Lumpur",
        "george town": "Asia/Kuala_Lumpur",
        "singapore": "Asia/Singapore",
        "jakarta": "Asia/Jakarta",
        "surabaya": "Asia/Jakarta",
        "bandung": "Asia/Jakarta",
        "bali": "Asia/Makassar",
        "denpasar": "Asia/Makassar",
        "manila": "Asia/Manila",
        "quezon city": "Asia/Manila",
        "cebu": "Asia/Manila",
        "davao": "Asia/Manila",
        "hong kong": "Asia/Hong_Kong",
        "macau": "Asia/Macau",
        "macao": "Asia/Macau",
        "taipei": "Asia/Taipei",
        "kaohsiung": "Asia/Taipei",
        "taichung": "Asia/Taipei",
        "shanghai": "Asia/Shanghai",
        "beijing": "Asia/Shanghai",
        "peking": "Asia/Shanghai",
        "guangzhou": "Asia/Shanghai",
        "canton": "Asia/Shanghai",
        "shenzhen": "Asia/Shanghai",
        "wuhan": "Asia/Shanghai",
        "chengdu": "Asia/Shanghai",
        "chongqing": "Asia/Shanghai",
        "nanjing": "Asia/Shanghai",
        "tianjin": "Asia/Shanghai",
        "hangzhou": "Asia/Shanghai",
        "suzhou": "Asia/Shanghai",
        "xian": "Asia/Shanghai",
        "xi'an": "Asia/Shanghai",
        "qingdao": "Asia/Shanghai",
        "dalian": "Asia/Shanghai",
        "shenyang": "Asia/Shanghai",
        "harbin": "Asia/Shanghai",
        "kunming": "Asia/Shanghai",
        "changsha": "Asia/Shanghai",
        "seoul": "Asia/Seoul",
        "busan": "Asia/Seoul",
        "incheon": "Asia/Seoul",
        "daegu": "Asia/Seoul",
        "daejeon": "Asia/Seoul",
        "gwangju": "Asia/Seoul",
        "suwon": "Asia/Seoul",
        "pyongyang": "Asia/Pyongyang",
        "tokyo": "Asia/Tokyo",
        "yokohama": "Asia/Tokyo",
        "osaka": "Asia/Tokyo",
        "kyoto": "Asia/Tokyo",
        "nagoya": "Asia/Tokyo",
        "sapporo": "Asia/Tokyo",
        "fukuoka": "Asia/Tokyo",
        "kobe": "Asia/Tokyo",
        "hiroshima": "Asia/Tokyo",
        "sendai": "Asia/Tokyo",
        "ulaanbaatar": "Asia/Ulaanbaatar",
        "sydney": "Australia/Sydney",
        "melbourne": "Australia/Melbourne",
        "brisbane": "Australia/Brisbane",
        "perth": "Australia/Perth",
        "adelaide": "Australia/Adelaide",
        "canberra": "Australia/Sydney",
        "darwin": "Australia/Darwin",
        "hobart": "Australia/Hobart",
        "gold coast": "Australia/Brisbane",
        "newcastle": "Australia/Sydney",
        "wollongong": "Australia/Sydney",
        "auckland": "Pacific/Auckland",
        "wellington": "Pacific/Auckland",
        "christchurch": "Pacific/Auckland",
        "hamilton": "Pacific/Auckland",
        "dunedin": "Pacific/Auckland",
        "suva": "Pacific/Fiji",
        "nadi": "Pacific/Fiji",
        "port moresby": "Pacific/Port_Moresby",
        "noumea": "Pacific/Noumea",
        "papeete": "Pacific/Tahiti",
        "apia": "Pacific/Apia",
        "nuku'alofa": "Pacific/Tongatapu",
        "gmt": "UTC",
        "utc": "UTC",
        "zulu": "UTC"
    ]

    static func suggestedTimeZoneID(forCity city: String) -> String? {
        let key = city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.isEmpty { return nil }
        if let direct = cityTimeZoneMap[key] { return direct }
        if key.contains("/") {
            let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
            if TimeZone(identifier: trimmed) != nil { return trimmed }
        }
        for k in cityTimeZoneMap.keys.sorted(by: { $0.count > $1.count }) {
            if key.contains(k) {
                return cityTimeZoneMap[k]
            }
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

    func snapshotZonesForPreset() -> [PresetZoneEntry] {
        zones.map { zone in
            if zone.id == "local" {
                return PresetZoneEntry(city: cityName(for: zone), timeZoneID: PresetZoneEntry.localID, isCopySelected: copySelectedIDs.contains(zone.id))
            } else {
                return PresetZoneEntry(city: cityName(for: zone), timeZoneID: zone.timeZone.identifier, isCopySelected: copySelectedIDs.contains(zone.id))
            }
        }
    }

    func saveCopyPreset(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !copyOrder.isEmpty else { return false }
        let snapshot = snapshotZonesForPreset()
        if let idx = copyPresets.firstIndex(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            copyPresets[idx].tokens = copyOrder
            copyPresets[idx].zones = snapshot
        } else {
            let p = CopyPreset(id: "preset-" + UUID().uuidString.prefix(8).lowercased(), name: trimmed, tokens: copyOrder, zones: snapshot)
            copyPresets.append(p)
        }
        return true
    }

    func applyCopyPreset(id: String) {
        guard let p = copyPresets.first(where: { $0.id == id }) else { return }
        copyOrder = p.tokens
        if !p.zones.isEmpty {
            applyPresetZones(p.zones)
        }
    }

    func applyPresetZones(_ entries: [PresetZoneEntry]) {
        var newExtraIDs: [String] = []
        var newCopy = Set<String>()
        for entry in entries {
            if entry.timeZoneID == PresetZoneEntry.localID {
                let cityTrim = entry.city.trimmingCharacters(in: .whitespacesAndNewlines)
                if cityTrim.isEmpty || cityTrim.lowercased() == "local" {
                    customCities.removeValue(forKey: "local")
                } else {
                    customCities["local"] = cityTrim
                }
                if entry.isCopySelected {
                    newCopy.insert("local")
                }
            }
        }
        for entry in entries where entry.timeZoneID != PresetZoneEntry.localID {
            guard TimeZone(identifier: entry.timeZoneID) != nil else { continue }
            var matchedID: String?
            for cz in customZones {
                if cz.timeZoneID == entry.timeZoneID {
                    let resolved: String
                    if let custom = customCities[cz.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
                        resolved = custom
                    } else {
                        resolved = cz.city
                    }
                    if resolved.lowercased() == entry.city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                        matchedID = cz.id
                        break
                    }
                }
            }
            if matchedID == nil {
                if newExtraIDs.count >= Self.maxExtras { continue }
                let newID = "custom-" + UUID().uuidString.prefix(8).lowercased()
                let cz = CustomZone(id: String(newID), city: entry.city, timeZoneID: entry.timeZoneID)
                customZones.append(cz)
                matchedID = cz.id
            }
            if let mid = matchedID {
                if !newExtraIDs.contains(mid) {
                    newExtraIDs.append(mid)
                }
                if let cz = customZones.first(where: { $0.id == mid }) {
                    if cz.city != entry.city {
                        customCities[mid] = entry.city
                    }
                }
                if entry.isCopySelected {
                    newCopy.insert(mid)
                }
            }
        }
        extraIDs = Array(newExtraIDs.prefix(Self.maxExtras))
        copySelectedIDs = newCopy
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
        f.dateFormat = "h:mm a"
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
        case .gmtParen:
            return zone.gmtParenString(for: baseDate)
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
