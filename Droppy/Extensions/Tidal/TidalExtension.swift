//
//  TidalExtension.swift
//  Droppy
//
//  Self-contained definition for Tidal Integration extension
//

import SwiftUI

struct TidalExtension: ExtensionDefinition {
    static let id = "tidal"
    static let title = "Tidal Integration"
    static let subtitle = "Control playback from your notch"
    static let category: ExtensionGroup = .media
    static let categoryColor = Color(red: 0.0, green: 0.80, blue: 0.84) // Tidal teal

    static let description = "Control Tidal playback directly from your notch. See album art, track info, and playback controls without switching apps."

    static let features: [(icon: String, text: String)] = [
        ("music.note", "Now playing info in notch"),
        ("play.circle.fill", "Playback controls"),
        ("photo.fill", "Album art display"),
        ("heart.fill", "Favorite tracks"),
        ("link", "Secure OAuth connection")
    ]

    static var screenshotURL: URL? {
        URL(string: "https://getdroppy.app/assets/images/tidal-screenshot.jpg")
    }

    static var iconURL: URL? {
        URL(string: "https://getdroppy.app/assets/icons/tidal.png")
    }

    static let iconPlaceholder = "music.note.list"
    static let iconPlaceholderColor = Color(red: 0.0, green: 0.80, blue: 0.84)

    static func cleanup() {
        TidalAuthManager.shared.cleanup()
    }
}
