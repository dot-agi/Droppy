//
//  TidalLyricsParser.swift
//  Droppy
//
//  Parses LRC (synchronized lyrics) format from Tidal API
//  Format: [mm:ss.xx] Lyric text here
//

import Foundation

enum TidalLyricsParser {
    /// Parse LRC format text into timestamped lines sorted by time
    static func parse(_ lrcText: String) -> [(time: TimeInterval, text: String)] {
        var lines: [(time: TimeInterval, text: String)] = []

        for line in lrcText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("[") else { continue }

            // Match [mm:ss.xx] or [mm:ss] pattern
            guard let closeBracket = trimmed.firstIndex(of: "]") else { continue }
            let timeStr = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
            let text = String(trimmed[trimmed.index(after: closeBracket)...]).trimmingCharacters(in: .whitespaces)

            // Skip metadata tags like [ar:Artist] [ti:Title]
            guard let time = parseTimestamp(timeStr) else { continue }

            // Skip empty lines
            guard !text.isEmpty else { continue }

            lines.append((time: time, text: text))
        }

        return lines.sorted { $0.time < $1.time }
    }

    /// Parse timestamp string "mm:ss.xx" into TimeInterval
    private static func parseTimestamp(_ str: String) -> TimeInterval? {
        let parts = str.split(separator: ":")
        guard parts.count == 2,
              let minutes = Double(parts[0]) else { return nil }

        let secondsParts = parts[1].split(separator: ".")
        guard let seconds = Double(secondsParts[0]) else { return nil }

        var milliseconds: Double = 0
        if secondsParts.count > 1 {
            let msStr = String(secondsParts[1])
            if let ms = Double(msStr) {
                // Handle both .xx (centiseconds) and .xxx (milliseconds)
                milliseconds = msStr.count <= 2 ? ms / 100.0 : ms / 1000.0
            }
        }

        return minutes * 60.0 + seconds + milliseconds
    }
}
