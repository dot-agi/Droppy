//
//  TidalController.swift
//  Droppy
//
//  Tidal-specific media controls using System Events UI scripting and Web API
//  Tidal has no AppleScript dictionary, so all controls go through System Events
//

import AppKit
import Foundation

/// Manages Tidal-specific features including shuffle, repeat, and like functionality
/// Uses System Events UI scripting for local controls and Tidal API for library features
@Observable
final class TidalController {
    static let shared = TidalController()

    // MARK: - State

    /// Whether shuffle is currently enabled in Tidal
    private(set) var shuffleEnabled: Bool = false

    /// Current repeat mode in Tidal
    private(set) var repeatMode: RepeatMode = .off

    /// Whether the current track is liked (in user's favorites)
    private(set) var isCurrentTrackLiked: Bool = false

    /// Whether we're currently checking/updating liked status
    private(set) var isLikeLoading: Bool = false

    /// Whether user has authenticated with Tidal API
    private(set) var isAuthenticated: Bool = false

    /// Current track identifier from Tidal (used for like/unlike and premium features)
    private(set) var currentTrackId: String?

    // MARK: - Premium Feature State

    /// Audio quality label for the current track (e.g. "HiFi", "HiRes", "Atmos")
    private(set) var currentTrackQuality: String?

    /// Credits for the current track (producers, songwriters, engineers)
    private(set) var currentTrackCredits: [(name: String, role: String)]?

    /// Whether the credits overlay is showing
    var showingCredits: Bool = false

    /// Parsed synced lyrics for the current track
    private(set) var lyricsLines: [(time: TimeInterval, text: String)]?

    /// The current lyric line matching playback position
    private(set) var currentLyricLine: String?

    /// Whether lyrics display is enabled
    var showingLyrics: Bool = false

    /// User's playlists (fetched on auth)
    private(set) var userPlaylists: [(id: String, name: String, count: Int)]?

    // MARK: - Track ID Resolution Cache

    /// Cache search results to avoid repeated API calls for the same track
    private var trackIdCache: [String: String] = [:]

    /// The title+artist key for the currently resolved track
    private var lastResolvedKey: String?

    /// Tidal bundle identifier
    static let tidalBundleId = "com.tidal.desktop"

    /// Serial queue for AppleScript execution - NSAppleScript is NOT thread-safe
    private let appleScriptQueue = DispatchQueue(label: "com.droppy.TidalController.applescript")

    // MARK: - Repeat Mode

    enum RepeatMode: String, CaseIterable {
        case off = "off"
        case context = "context"  // Repeat playlist/album
        case track = "track"      // Repeat single track

        var displayName: String {
            switch self {
            case .off: return "Off"
            case .context: return "All"
            case .track: return "One"
            }
        }

        var iconName: String {
            switch self {
            case .off: return "repeat"
            case .context: return "repeat"
            case .track: return "repeat.1"
            }
        }

        var next: RepeatMode {
            switch self {
            case .off: return .context
            case .context: return .track
            case .track: return .off
            }
        }
    }

    // MARK: - Initialization

    private init() {
        isAuthenticated = TidalAuthManager.shared.isAuthenticated
    }

    // MARK: - Tidal Detection

    /// Check if Tidal is currently running (and extension is enabled)
    var isTidalRunning: Bool {
        guard !ExtensionType.tidal.isRemoved else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: Self.tidalBundleId).first != nil
    }

    /// Refresh state when Tidal becomes the active source
    func refreshState() {
        guard !ExtensionType.tidal.isRemoved else { return }
        guard isTidalRunning else { return }

        // Track Tidal integration activation (only once per user)
        if !UserDefaults.standard.bool(forKey: "tidalTracked") {
            AnalyticsService.shared.trackExtensionActivation(extensionId: "tidal")
        }

        fetchShuffleState()
        fetchRepeatState()

        // Resolve current track ID if not yet resolved
        let manager = MusicManager.shared
        if currentTrackId == nil, !manager.songTitle.isEmpty {
            onTrackChange(title: manager.songTitle, artist: manager.artistName)
        }

        // If authenticated, check liked status and fetch playlists
        if isAuthenticated {
            if let trackId = currentTrackId {
                checkIfTrackIsLiked(trackId: trackId)
            }
            if userPlaylists == nil {
                fetchPlaylists()
            }
        }
    }

    /// Called when track changes - resolve track ID and update all metadata
    func onTrackChange(title: String, artist: String) {
        let key = "\(title)|\(artist)".lowercased()

        // Skip if same track
        guard key != lastResolvedKey else { return }

        // Clear previous track's premium data
        currentTrackQuality = nil
        currentTrackCredits = nil
        currentLyricLine = nil
        lyricsLines = nil
        showingCredits = false

        // Check cache first
        if let cachedId = trackIdCache[key] {
            lastResolvedKey = key
            currentTrackId = cachedId
            onTrackIdResolved(trackId: cachedId)
            return
        }

        // Resolve via search API
        TidalAuthManager.shared.searchTrack(title: title, artist: artist) { [weak self] trackId in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.lastResolvedKey = key
                if let trackId = trackId {
                    self.trackIdCache[key] = trackId
                    self.currentTrackId = trackId
                    self.onTrackIdResolved(trackId: trackId)
                } else {
                    self.currentTrackId = nil
                    self.isCurrentTrackLiked = false
                }
            }
        }
    }

    /// Once we have a track ID, fetch all premium metadata
    private func onTrackIdResolved(trackId: String) {
        // Check liked status
        if isAuthenticated {
            checkIfTrackIsLiked(trackId: trackId)
        }

        // Fetch quality badge
        TidalAuthManager.shared.fetchTrackQuality(trackId: trackId) { [weak self] quality in
            DispatchQueue.main.async {
                self?.currentTrackQuality = quality
            }
        }

        // Fetch credits
        TidalAuthManager.shared.fetchTrackCredits(trackId: trackId) { [weak self] credits in
            DispatchQueue.main.async {
                self?.currentTrackCredits = credits
            }
        }

        // Fetch lyrics
        TidalAuthManager.shared.fetchLyrics(trackId: trackId) { [weak self] lrcText, _ in
            DispatchQueue.main.async {
                if let lrcText = lrcText {
                    self?.lyricsLines = TidalLyricsParser.parse(lrcText)
                } else {
                    self?.lyricsLines = nil
                }
            }
        }
    }

    /// Update the current lyric line based on playback position
    func updateCurrentLyric(at elapsed: TimeInterval) {
        guard showingLyrics, let lines = lyricsLines, !lines.isEmpty else {
            if currentLyricLine != nil { currentLyricLine = nil }
            return
        }

        // Find the last line whose timestamp <= elapsed
        var matchedLine: String?
        for line in lines {
            if line.time <= elapsed {
                matchedLine = line.text
            } else {
                break
            }
        }

        if matchedLine != currentLyricLine {
            currentLyricLine = matchedLine
        }
    }

    // MARK: - Playlists

    /// Fetch user's playlists
    func fetchPlaylists() {
        TidalAuthManager.shared.fetchUserPlaylists { [weak self] playlists in
            DispatchQueue.main.async {
                self?.userPlaylists = playlists
            }
        }
    }

    /// Add current track to a playlist
    func addToPlaylist(playlistId: String, completion: @escaping (Bool) -> Void) {
        guard let trackId = currentTrackId else {
            completion(false)
            return
        }

        TidalAuthManager.shared.addTrackToPlaylist(trackId: trackId, playlistId: playlistId) { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // MARK: - System Events AppleScript Controls
    // Tidal has NO AppleScript dictionary. All controls go through System Events
    // by clicking menu bar items via accessibility (UI scripting).

    /// Toggle shuffle on/off via Playback menu
    func toggleShuffle() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                click menu item "Shuffle" of menu "Playback" of menu bar 1
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.fetchShuffleState()
            }
        }
    }

    /// Cycle through repeat modes via Playback menu
    /// Tidal's Repeat menu item cycles: off → all → one → off
    func cycleRepeatMode() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                click menu item "Repeat" of menu "Playback" of menu bar 1
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Cycle local state since we can't reliably read the exact mode
                DispatchQueue.main.async {
                    self?.repeatMode = self?.repeatMode.next ?? .off
                }
            }
        }
    }

    // MARK: - State Fetching

    /// Read shuffle state from Tidal's Playback menu checkmark
    private func fetchShuffleState() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                set shuffleItem to menu item "Shuffle" of menu "Playback" of menu bar 1
                try
                    set markChar to value of attribute "AXMenuItemMarkChar" of shuffleItem
                    if markChar is not missing value then
                        return "on"
                    else
                        return "off"
                    end if
                on error
                    return "off"
                end try
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] result in
            if let state = result as? String {
                DispatchQueue.main.async {
                    self?.shuffleEnabled = (state == "on")
                }
            }
        }
    }

    /// Read repeat state from Tidal's Playback menu
    /// Note: System Events can detect if Repeat has a checkmark but not which mode
    private func fetchRepeatState() {
        let script = """
        tell application "System Events"
            tell process "TIDAL"
                set repeatItem to menu item "Repeat" of menu "Playback" of menu bar 1
                try
                    set markChar to value of attribute "AXMenuItemMarkChar" of repeatItem
                    if markChar is not missing value then
                        return "on"
                    else
                        return "off"
                    end if
                on error
                    return "off"
                end try
            end tell
        end tell
        """

        runAppleScript(script) { [weak self] result in
            if let state = result as? String {
                DispatchQueue.main.async {
                    // We can only detect on/off from menu checkmark
                    // Default to .context when on, since we can't distinguish
                    self?.repeatMode = (state == "on") ? .context : .off
                }
            }
        }
    }

    // MARK: - AppleScript Execution

    private func runAppleScript(_ source: String, completion: @escaping (Any?) -> Void) {
        appleScriptQueue.async {
            let parsed: Any? = AppleScriptRuntime.execute {
                var error: NSDictionary?

                guard let script = NSAppleScript(source: source) else {
                    print("TidalController: Failed to create AppleScript")
                    return nil
                }

                let result = script.executeAndReturnError(&error)

                if let error = error {
                    print("TidalController: AppleScript error: \(error)")
                    return nil
                }

                // System Events scripts typically return strings
                switch result.descriptorType {
                case typeTrue:
                    return true
                case typeFalse:
                    return false
                default:
                    return result.stringValue
                }
            }

            DispatchQueue.main.async { completion(parsed) }
        }
    }

    // MARK: - Web API (Like Functionality)

    /// Like the current track (add to favorites)
    func likeCurrentTrack() {
        guard isAuthenticated else { return }
        guard let trackId = currentTrackId else { return }

        isLikeLoading = true

        TidalAuthManager.shared.addTrackToFavorites(trackId: trackId) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLikeLoading = false
                if success {
                    self?.isCurrentTrackLiked = true
                }
            }
        }
    }

    /// Unlike the current track (remove from favorites)
    func unlikeCurrentTrack() {
        guard isAuthenticated else { return }
        guard let trackId = currentTrackId else { return }

        isLikeLoading = true

        TidalAuthManager.shared.removeTrackFromFavorites(trackId: trackId) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLikeLoading = false
                if success {
                    self?.isCurrentTrackLiked = false
                }
            }
        }
    }

    /// Toggle like status
    func toggleLike() {
        if isCurrentTrackLiked {
            unlikeCurrentTrack()
        } else {
            likeCurrentTrack()
        }
    }

    /// Check if a track is in user's favorites
    private func checkIfTrackIsLiked(trackId: String) {
        TidalAuthManager.shared.checkIfTrackIsFavorited(trackId: trackId) { [weak self] isFavorited in
            DispatchQueue.main.async {
                self?.isCurrentTrackLiked = isFavorited
            }
        }
    }

    /// Trigger Tidal authentication
    func authenticate() {
        TidalAuthManager.shared.startAuthentication()
    }

    /// Sign out from Tidal
    func signOut() {
        TidalAuthManager.shared.signOut()
        isAuthenticated = false
        isCurrentTrackLiked = false
        currentTrackId = nil
        currentTrackQuality = nil
        currentTrackCredits = nil
        lyricsLines = nil
        currentLyricLine = nil
        userPlaylists = nil
        trackIdCache.removeAll()
        lastResolvedKey = nil
    }

    /// Update authentication state (called from TidalAuthManager after token changes)
    func updateAuthState() {
        isAuthenticated = TidalAuthManager.shared.isAuthenticated

        if isAuthenticated {
            if let trackId = currentTrackId {
                checkIfTrackIsLiked(trackId: trackId)
            }
            fetchPlaylists()

            // Re-trigger track resolution for the currently playing track
            // This handles the case where auth completes while a song is already playing
            let manager = MusicManager.shared
            if manager.isTidalSource, !manager.songTitle.isEmpty {
                lastResolvedKey = nil  // Force re-resolution
                trackIdCache.removeAll()
                onTrackChange(title: manager.songTitle, artist: manager.artistName)
            }
        }
    }
}
