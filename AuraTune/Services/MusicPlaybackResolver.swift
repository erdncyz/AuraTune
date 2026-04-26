import Foundation

final class MusicPlaybackResolver {
    static let shared = MusicPlaybackResolver()

    private init() {}

    func resolvePlaybackURLs(title: String, artist: String, platform: String) async -> (appURL: URL?, webURL: URL?) {
        switch platform {
        case "Spotify":
            if let uri = await SpotifyService.shared.resolveTrackURI(title: title, artist: artist),
               let trackID = spotifyTrackID(from: uri),
               let appURL = URL(string: "spotify:track:\(trackID)"),
               let webURL = URL(string: "https://open.spotify.com/track/\(trackID)") {
                return (appURL, webURL)
            }

            let query = queryString(title: title, artist: artist)
            return (
                URL(string: "spotify:search:\(query)"),
                URL(string: "https://open.spotify.com/search/\(query)")
            )

        case "YouTube Music":
            let query = queryString(title: title, artist: artist)
            let webURL = URL(string: "https://music.youtube.com/search?q=\(query)")
            return (webURL, webURL)

        case "Apple Music":
            let query = queryString(title: title, artist: artist)
            return (
                URL(string: "music://search?term=\(query)"),
                URL(string: "https://music.apple.com/search?term=\(query)")
            )

        default:
            let query = queryString(title: title, artist: artist)
            return (
                URL(string: "spotify:search:\(query)"),
                URL(string: "https://open.spotify.com/search/\(query)")
            )
        }
    }

    private func queryString(title: String, artist: String) -> String {
        "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

    private func spotifyTrackID(from uri: String) -> String? {
        if uri.hasPrefix("spotify:track:") {
            return String(uri.dropFirst("spotify:track:".count))
        }

        if let url = URL(string: uri),
           url.host == "open.spotify.com" {
            let parts = url.pathComponents
            if parts.count >= 3, parts[1] == "track" {
                return parts[2]
            }
        }

        return nil
    }
}
