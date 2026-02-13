//
//  TidalCard.swift
//  Droppy
//
//  Tidal extension card for Settings extensions grid
//

import SwiftUI

struct TidalExtensionCard: View {
    @State private var showInfoSheet = false
    private var isInstalled: Bool { UserDefaults.standard.bool(forKey: "tidalTracked") }
    var installCount: Int?
    var rating: AnalyticsService.ExtensionRating?

    private let tidalTeal = Color(red: 0.0, green: 0.80, blue: 0.84)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon, stats, and badge
            HStack(alignment: .top) {
                CachedAsyncImage(url: URL(string: "https://getdroppy.app/assets/icons/tidal.png")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundStyle(tidalTeal)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.ms, style: .continuous))

                Spacer()

                // Stats row: installs + rating + badge
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text(AnalyticsService.shared.isDisabled ? "–" : "\(installCount ?? 0)")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                        if let r = rating, r.ratingCount > 0 {
                            Text(String(format: "%.1f", r.averageRating))
                                .font(.caption2.weight(.medium))
                        } else {
                            Text("–")
                                .font(.caption2.weight(.medium))
                        }
                    }
                    .foregroundStyle(.secondary)

                    Text(isInstalled ? "Installed" : "Media")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isInstalled ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isInstalled ? Color.green.opacity(0.15) : AdaptiveColors.subtleBorderAuto)
                        )
                }
            }

            // Title & Description
            VStack(alignment: .leading, spacing: 4) {
                Text("Tidal Integration")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Extra shuffle, repeat & favorite controls in the media player.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            // Status row - Running indicator
            HStack {
                Circle()
                    .fill(TidalController.shared.isTidalRunning ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(TidalController.shared.isTidalRunning ? "Running" : "Not running")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TidalController.shared.isTidalRunning ? .primary : .secondary)
                Spacer()
            }
        }
        .frame(minHeight: 160)
        .extensionCardStyle(accentColor: tidalTeal)
        .contentShape(Rectangle())
        .onTapGesture {
            showInfoSheet = true
        }
        .sheet(isPresented: $showInfoSheet) {
            ExtensionInfoView(extensionType: .tidal, installCount: installCount, rating: rating)
        }
    }
}
