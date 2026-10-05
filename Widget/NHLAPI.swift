import AppKit

private let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

extension ConferenceStandings {
    static func decode(_ data: Data, conference: Conference) throws -> ConferenceStandings {
        struct Response: Decodable { let standings: [Team] }
        let standings = ConferenceStandings(teams: try JSONDecoder().decode(Response.self, from: data).standings, conference: conference)
        guard standings.divisions.contains(where: { !$0.teams.isEmpty }) else { throw URLError(.cannotParseResponse) }
        return standings
    }

    static func fetchData() async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: URL(string: "https://api-web.nhle.com/v1/standings/now")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    /// Fresh standings when the fetch decodes; otherwise the last good response, with `staleSince` set to when it was saved.
    static func load(_ conference: Conference,
                     cacheFile: URL = cachesDirectory.appendingPathComponent("standings.json"),
                     fetch: () async throws -> Data = ConferenceStandings.fetchData)
        async -> (standings: ConferenceStandings, staleSince: Date?)? {
        if let data = try? await fetch(), let standings = try? decode(data, conference: conference) {
            try? data.write(to: cacheFile)
            return (standings, nil)
        }
        guard let data = try? Data(contentsOf: cacheFile), let standings = try? decode(data, conference: conference) else { return nil }
        let saved = (try? cacheFile.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return (standings, saved ?? .distantPast)
    }
}

enum Logos {
    static func url(_ abbrev: String) -> URL {
        URL(string: "https://assets.nhle.com/logos/nhl/svg/\(abbrev)_light.svg")!
    }

    /// Logos rarely change, so each is downloaded once and kept in Caches; every tap reloads the timeline.
    static func image(_ abbrev: String, cacheDir: URL = cachesDirectory) async -> NSImage? {
        let file = cacheDir.appendingPathComponent("\(abbrev).svg")
        if let data = try? Data(contentsOf: file) { return NSImage(data: data) }
        guard let (data, response) = try? await URLSession.shared.data(from: url(abbrev)),
              (response as? HTTPURLResponse)?.statusCode == 200, let image = NSImage(data: data) else { return nil }
        try? data.write(to: file)
        return image
    }
}
