//
//  TidalAuthManager.swift
//  Droppy
//
//  Tidal API OAuth 2.1 PKCE authentication and API calls
//  Tidal requires PKCE for all clients per OAuth 2.1 spec
//

import AppKit
import CommonCrypto
import Foundation
import Security

/// Manages Tidal API authentication and API calls for library features
final class TidalAuthManager {
    static let shared = TidalAuthManager()

    // MARK: - Configuration

    private var clientId: String = ""
    private let redirectUri = "droppy://tidal-callback"
    private let scopes = "user.read collection.read collection.write playlists.read playlists.write"

    // MARK: - Tidal OAuth Endpoints

    private let authorizeURL = "https://login.tidal.com/authorize"
    private let tokenURL = "https://auth.tidal.com/v1/oauth2/token"
    private let apiBaseURL = "https://openapi.tidal.com/v2"

    // MARK: - Token Storage Keys

    private let accessTokenKey = "TidalAccessToken"
    private let refreshTokenKey = "TidalRefreshToken"
    private let tokenExpiryKey = "TidalTokenExpiry"
    private let userIdKey = "TidalUserId"
    private let keychainService = "com.iordv.droppy.tidal"

    // MARK: - PKCE State

    private var codeVerifier: String?

    // MARK: - Cached User ID

    private var cachedUserId: String? {
        get { UserDefaults.standard.string(forKey: userIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: userIdKey) }
    }

    // MARK: - State

    var isAuthenticated: Bool {
        return getRefreshToken() != nil
    }

    var hasValidClientId: Bool {
        return clientId != "YOUR_TIDAL_CLIENT_ID" && !clientId.isEmpty
    }

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    private func loadConfiguration() {
        guard let url = Bundle.main.url(forResource: "TidalConfig", withExtension: "plist") else {
            print("TidalAuthManager: TidalConfig.plist not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            if let config = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let id = config["ClientId"] as? String {
                self.clientId = id
            }
        } catch {
            print("TidalAuthManager: Failed to load configuration: \(error)")
        }
    }

    // MARK: - OAuth Flow

    /// Start the OAuth authorization flow
    func startAuthentication() {
        guard hasValidClientId else {
            print("TidalAuthManager: No valid Client ID configured")
            return
        }

        // Generate PKCE code verifier and challenge
        codeVerifier = generateCodeVerifier()
        guard let verifier = codeVerifier,
              let challenge = generateCodeChallenge(from: verifier) else {
            print("TidalAuthManager: Failed to generate PKCE challenge")
            return
        }

        // Build authorization URL
        var components = URLComponents(string: authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]

        guard let url = components.url else {
            print("TidalAuthManager: Failed to build authorization URL")
            return
        }

        print("TidalAuthManager: Opening authorization URL")
        NSWorkspace.shared.open(url)
    }

    /// Handle OAuth callback URL
    func handleCallback(url: URL) -> Bool {
        guard url.scheme == "droppy",
              url.host == "tidal-callback" else {
            return false
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("TidalAuthManager: No authorization code in callback")
            return false
        }

        print("TidalAuthManager: Received authorization code")
        exchangeCodeForToken(code: code)
        return true
    }

    /// Exchange authorization code for access token
    private func exchangeCodeForToken(code: String) {
        guard let verifier = codeVerifier else {
            print("TidalAuthManager: No code verifier available")
            return
        }

        let url = URL(string: tokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectUri,
            "client_id": clientId,
            "code_verifier": verifier
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            self?.codeVerifier = nil

            if let error = error {
                print("TidalAuthManager: Token exchange error: \(error)")
                return
            }

            guard let data = data else {
                print("TidalAuthManager: No data in token response")
                return
            }

            if self?.parseTokenResponse(data: data) == true {
                // Fetch user ID for collection endpoints
                self?.fetchCurrentUserId()
            }
        }.resume()
    }

    /// Refresh the access token using refresh token
    func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = getRefreshToken() else {
            print("TidalAuthManager: No refresh token available")
            completion(false)
            return
        }

        let url = URL(string: tokenURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientId
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("TidalAuthManager: Token refresh error: \(error)")
                completion(false)
                return
            }

            guard let data = data else {
                print("TidalAuthManager: No data in refresh response")
                completion(false)
                return
            }

            if self?.parseTokenResponse(data: data) == true {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }

    @discardableResult
    private func parseTokenResponse(data: Data) -> Bool {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("TidalAuthManager: Invalid JSON response")
                return false
            }

            if let error = json["error"] as? String {
                print("TidalAuthManager: API error: \(error)")
                return false
            }

            guard let accessToken = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Int else {
                print("TidalAuthManager: Missing token fields")
                return false
            }

            // Store tokens
            saveToKeychain(key: accessTokenKey, value: accessToken)

            if let refreshToken = json["refresh_token"] as? String {
                saveToKeychain(key: refreshTokenKey, value: refreshToken)
            }

            // Store expiry time
            let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
            UserDefaults.standard.set(expiryDate, forKey: tokenExpiryKey)

            print("TidalAuthManager: Tokens saved successfully")

            // Notify controller
            DispatchQueue.main.async {
                TidalController.shared.updateAuthState()
            }

            return true
        } catch {
            print("TidalAuthManager: JSON parse error: \(error)")
            return false
        }
    }

    // MARK: - User ID

    /// Fetch the current user's ID (needed for collection endpoints)
    private func fetchCurrentUserId() {
        getValidAccessToken { [weak self] token in
            guard let token = token else { return }

            self?.makeTidalAPIRequest(
                endpoint: "/users/me",
                method: "GET",
                body: nil,
                token: token
            ) { success, data in
                guard success, let data = data else { return }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataObj = json["data"] as? [String: Any],
                       let userId = dataObj["id"] as? String {
                        self?.cachedUserId = userId
                        print("TidalAuthManager: User ID cached: \(userId)")
                    }
                } catch {
                    print("TidalAuthManager: Failed to parse user info: \(error)")
                }
            }
        }
    }

    // MARK: - API Calls

    /// Get valid access token, refreshing if needed
    private func getValidAccessToken(completion: @escaping (String?) -> Void) {
        if let expiry = UserDefaults.standard.object(forKey: tokenExpiryKey) as? Date,
           expiry < Date() {
            refreshAccessToken { [weak self] success in
                if success {
                    completion(self?.getAccessToken())
                } else {
                    completion(nil)
                }
            }
            return
        }

        completion(getAccessToken())
    }

    /// Add a track to user's favorites
    func addTrackToFavorites(trackId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = cachedUserId else {
            print("TidalAuthManager: No user ID cached")
            completion(false)
            return
        }

        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(false)
                return
            }

            let body: [String: Any] = [
                "data": [
                    ["type": "tracks", "id": trackId]
                ]
            ]

            self?.makeTidalAPIRequest(
                endpoint: "/userCollectionTracks/\(userId)/relationships/items",
                method: "POST",
                body: body,
                token: token
            ) { success, _ in
                completion(success)
            }
        }
    }

    /// Remove a track from user's favorites
    func removeTrackFromFavorites(trackId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = cachedUserId else {
            print("TidalAuthManager: No user ID cached")
            completion(false)
            return
        }

        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(false)
                return
            }

            let body: [String: Any] = [
                "data": [
                    ["type": "tracks", "id": trackId]
                ]
            ]

            self?.makeTidalAPIRequest(
                endpoint: "/userCollectionTracks/\(userId)/relationships/items",
                method: "DELETE",
                body: body,
                token: token
            ) { success, _ in
                completion(success)
            }
        }
    }

    /// Check if a track is in user's favorites
    func checkIfTrackIsFavorited(trackId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = cachedUserId else {
            completion(false)
            return
        }

        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(false)
                return
            }

            self?.makeTidalAPIRequest(
                endpoint: "/userCollectionTracks/\(userId)/relationships/items",
                method: "GET",
                body: nil,
                token: token
            ) { success, data in
                guard success, let data = data else {
                    completion(false)
                    return
                }

                // Check if trackId appears in the collection items
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let items = json["data"] as? [[String: Any]] {
                        let isFavorited = items.contains { ($0["id"] as? String) == trackId }
                        completion(isFavorited)
                    } else {
                        completion(false)
                    }
                } catch {
                    completion(false)
                }
            }
        }
    }

    /// Make a request to the Tidal API (JSON:API format)
    private func makeTidalAPIRequest(
        endpoint: String,
        method: String,
        body: [String: Any]?,
        token: String,
        completion: @escaping (Bool, Data?) -> Void
    ) {
        let fullURL = apiBaseURL + endpoint
        // Use URLComponents to handle any special characters in query params
        guard let components = URLComponents(string: fullURL),
              let url = components.url else {
            print("TidalAuthManager: Invalid URL: \(fullURL)")
            completion(false, nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.tidal.v1+json", forHTTPHeaderField: "Accept")
        request.setValue("application/vnd.tidal.v1+json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("TidalAuthManager: API error: \(error)")
                completion(false, nil)
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                if !success {
                    print("TidalAuthManager: API status \(httpResponse.statusCode) for \(method) \(endpoint)")
                }
                completion(success, data)
            } else {
                completion(false, nil)
            }
        }.resume()
    }

    // MARK: - Track Search

    /// Search for a track by title and artist to resolve its Tidal ID
    func searchTrack(title: String, artist: String, completion: @escaping (String?) -> Void) {
        getValidAccessToken { [weak self] token in
            guard let self = self, let token = token else {
                completion(nil)
                return
            }

            // Build URL with URLComponents to handle encoding properly
            let query = "\(title) \(artist)"
            // Use urlPathAllowed minus "/" so artists like "AC/DC" don't break the path
            var pathAllowed = CharacterSet.urlPathAllowed
            pathAllowed.remove(charactersIn: "/")
            let pathEncoded = query.addingPercentEncoding(withAllowedCharacters: pathAllowed) ?? query
            let urlString = self.apiBaseURL + "/searchresults/\(pathEncoded)/relationships/tracks"

            guard var components = URLComponents(string: urlString) else {
                print("TidalAuthManager: Failed to build search URL")
                completion(nil)
                return
            }

            components.queryItems = [
                URLQueryItem(name: "countryCode", value: "US"),
                URLQueryItem(name: "include", value: "tracks"),
                URLQueryItem(name: "page[limit]", value: "1")
            ]

            guard let url = components.url else {
                print("TidalAuthManager: Failed to create search URL from components")
                completion(nil)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.tidal.v1+json", forHTTPHeaderField: "Accept")
            request.setValue("application/vnd.tidal.v1+json", forHTTPHeaderField: "Content-Type")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("TidalAuthManager: Search API error: \(error)")
                    completion(nil)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if !(200...299).contains(httpResponse.statusCode) {
                        print("TidalAuthManager: Search API status \(httpResponse.statusCode)")
                        completion(nil)
                        return
                    }
                }

                guard let data = data else {
                    completion(nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let items = json["data"] as? [[String: Any]],
                       let firstItem = items.first,
                       let trackId = firstItem["id"] as? String {
                        print("TidalAuthManager: Resolved track ID: \(trackId)")
                        completion(trackId)
                    } else {
                        print("TidalAuthManager: No track found for query: \(query)")
                        completion(nil)
                    }
                } catch {
                    print("TidalAuthManager: Search parse error: \(error)")
                    completion(nil)
                }
            }.resume()
        }
    }

    // MARK: - Track Quality

    /// Fetch audio quality info for a track
    func fetchTrackQuality(trackId: String, completion: @escaping (String?) -> Void) {
        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(nil)
                return
            }

            self?.makeTidalAPIRequest(
                endpoint: "/tracks/\(trackId)?countryCode=US&include=tracks",
                method: "GET",
                body: nil,
                token: token
            ) { success, data in
                guard success, let data = data else {
                    completion(nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let dataObj = json["data"] as? [String: Any] ?? (json["data"] as? [[String: Any]])?.first,
                       let attrs = dataObj["attributes"] as? [String: Any],
                       let mediaTags = attrs["mediaTags"] as? [String] {
                        // Prioritize: Atmos > HiRes > HiFi
                        if mediaTags.contains("DOLBY_ATMOS") {
                            completion("Atmos")
                        } else if mediaTags.contains("HIRES_LOSSLESS") {
                            completion("HiRes")
                        } else if mediaTags.contains("LOSSLESS") {
                            completion("HiFi")
                        } else {
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                } catch {
                    print("TidalAuthManager: Quality parse error: \(error)")
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Track Credits

    /// Fetch credits (producers, songwriters, etc.) for a track
    func fetchTrackCredits(trackId: String, completion: @escaping ([(name: String, role: String)]?) -> Void) {
        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(nil)
                return
            }

            self?.makeTidalAPIRequest(
                endpoint: "/tracks/\(trackId)/relationships/credits?countryCode=US&include=credits",
                method: "GET",
                body: nil,
                token: token
            ) { success, data in
                guard success, let data = data else {
                    completion(nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let items = json["included"] as? [[String: Any]] {
                        let credits: [(name: String, role: String)] = items.compactMap { item in
                            guard let attrs = item["attributes"] as? [String: Any],
                                  let name = attrs["name"] as? String,
                                  let role = attrs["role"] as? String else { return nil }
                            return (name: name, role: role)
                        }
                        completion(credits.isEmpty ? nil : credits)
                    } else {
                        completion(nil)
                    }
                } catch {
                    print("TidalAuthManager: Credits parse error: \(error)")
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Lyrics

    /// Fetch lyrics for a track (returns LRC synced text if available, plain text fallback)
    func fetchLyrics(trackId: String, completion: @escaping (String?, String?) -> Void) {
        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(nil, nil)
                return
            }

            self?.makeTidalAPIRequest(
                endpoint: "/tracks/\(trackId)/relationships/lyrics?countryCode=US&include=lyrics",
                method: "GET",
                body: nil,
                token: token
            ) { success, data in
                guard success, let data = data else {
                    completion(nil, nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let items = json["included"] as? [[String: Any]],
                       let lyricsObj = items.first,
                       let attrs = lyricsObj["attributes"] as? [String: Any] {
                        let lrcText = attrs["lrcText"] as? String
                        let plainText = attrs["text"] as? String
                        completion(lrcText, plainText)
                    } else {
                        completion(nil, nil)
                    }
                } catch {
                    print("TidalAuthManager: Lyrics parse error: \(error)")
                    completion(nil, nil)
                }
            }
        }
    }

    // MARK: - Playlists

    /// Fetch user's playlists
    func fetchUserPlaylists(completion: @escaping ([(id: String, name: String, count: Int)]?) -> Void) {
        guard let userId = cachedUserId else {
            completion(nil)
            return
        }

        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(nil)
                return
            }

            self?.makeTidalAPIRequest(
                endpoint: "/userCollectionPlaylists/\(userId)/relationships/items?countryCode=US&include=playlists",
                method: "GET",
                body: nil,
                token: token
            ) { success, data in
                guard success, let data = data else {
                    completion(nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let included = json["included"] as? [[String: Any]] {
                        let playlists: [(id: String, name: String, count: Int)] = included.compactMap { item in
                            guard let id = item["id"] as? String,
                                  let attrs = item["attributes"] as? [String: Any],
                                  let name = attrs["name"] as? String else { return nil }
                            let count = attrs["numberOfItems"] as? Int ?? 0
                            return (id: id, name: name, count: count)
                        }
                        completion(playlists.isEmpty ? nil : playlists)
                    } else {
                        completion(nil)
                    }
                } catch {
                    print("TidalAuthManager: Playlists parse error: \(error)")
                    completion(nil)
                }
            }
        }
    }

    /// Add a track to a playlist
    func addTrackToPlaylist(trackId: String, playlistId: String, completion: @escaping (Bool) -> Void) {
        getValidAccessToken { [weak self] token in
            guard let token = token else {
                completion(false)
                return
            }

            let body: [String: Any] = [
                "data": [
                    ["type": "tracks", "id": trackId]
                ]
            ]

            self?.makeTidalAPIRequest(
                endpoint: "/playlists/\(playlistId)/relationships/items",
                method: "POST",
                body: body,
                token: token
            ) { success, _ in
                completion(success)
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        deleteFromKeychain(key: accessTokenKey)
        deleteFromKeychain(key: refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: tokenExpiryKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        print("TidalAuthManager: Signed out")
    }

    // MARK: - Extension Removal Cleanup

    /// Clean up all Tidal resources when extension is removed
    func cleanup() {
        signOut()
        UserDefaults.standard.removeObject(forKey: "tidalTracked")

        DispatchQueue.main.async {
            TidalController.shared.updateAuthState()
        }

        print("TidalAuthManager: Cleanup complete")
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String? {
        guard let data = verifier.data(using: .utf8) else { return nil }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }

        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        var newItem = query
        newItem[kSecValueData as String] = data

        let status = SecItemAdd(newItem as CFDictionary, nil)
        if status != errSecSuccess {
            print("TidalAuthManager: Keychain save error: \(status)")
        }
    }

    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    private func getAccessToken() -> String? {
        return getFromKeychain(key: accessTokenKey)
    }

    private func getRefreshToken() -> String? {
        return getFromKeychain(key: refreshTokenKey)
    }
}
