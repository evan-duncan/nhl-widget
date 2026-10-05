import AppKit

private let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

protocol StandingsService {
    /// Fresh standings when available; otherwise cached standings with `staleSince` set, or nil when there are none.
    func load(_ conference: Conference) async -> (standings: ConferenceStandings, staleSince: Date?)?
}

protocol LogoService {
    func image(_ abbrev: String) async -> NSImage?
}

extension ConferenceStandings {
    static func decode(_ data: Data, conference: Conference) throws -> ConferenceStandings {
        struct Response: Decodable { let standings: [Team] }
        let standings = ConferenceStandings(teams: try JSONDecoder().decode(Response.self, from: data).standings, conference: conference)
        guard standings.divisions.contains(where: { !$0.teams.isEmpty }) else { throw URLError(.cannotParseResponse) }
        return standings
    }
}

struct NHLStandingsService: StandingsService {
    var cacheFile = cachesDirectory.appendingPathComponent("standings.json")
    var session = URLSession.shared

    func fetchData() async throws -> Data {
        let (data, response) = try await session.data(from: URL(string: "https://api-web.nhle.com/v1/standings/now")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    /// Fresh standings when the fetch decodes; otherwise the last good response, with `staleSince` set to when it was saved.
    func load(_ conference: Conference) async -> (standings: ConferenceStandings, staleSince: Date?)? {
        if let data = try? await fetchData(), let standings = try? ConferenceStandings.decode(data, conference: conference) {
            try? data.write(to: cacheFile)
            return (standings, nil)
        }
        guard let data = try? Data(contentsOf: cacheFile),
              let standings = try? ConferenceStandings.decode(data, conference: conference) else { return nil }
        let saved = (try? cacheFile.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return (standings, saved ?? .distantPast)
    }
}

struct NHLLogoService: LogoService {
    var cacheDir = cachesDirectory
    var session = URLSession.shared

    static func url(_ abbrev: String) -> URL {
        URL(string: "https://assets.nhle.com/logos/nhl/svg/\(abbrev)_light.svg")!
    }

    /// Logos rarely change, so each is downloaded once and kept in Caches; every tap reloads the timeline.
    func image(_ abbrev: String) async -> NSImage? {
        let file = cacheDir.appendingPathComponent("\(abbrev).svg")
        if let data = try? Data(contentsOf: file) { return NSImage(data: data) }
        guard let (data, response) = try? await session.data(from: Self.url(abbrev)),
              (response as? HTTPURLResponse)?.statusCode == 200, let image = NSImage(data: data) else { return nil }
        try? data.write(to: file)
        return image
    }
}
