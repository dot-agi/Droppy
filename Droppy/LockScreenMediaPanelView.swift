//
//  LockScreenMediaPanelView.swift
//  Droppy
//
//  Created by Droppy on 26/01/2026.
//  SwiftUI view for the lock screen media widget
//  Displays album art, track info, progress bar, visualizer and playback controls
//

import SwiftUI

/// Lock screen media panel - beautiful glass design
/// Displays on the macOS lock screen via SkyLight.framework
/// Layout: Album art (left) | Title + Artist (center-left) | Visualizer (right)
///         Progress bar (full width)
///         Media controls (centered)
struct LockScreenMediaPanelView: View {
    @EnvironmentObject var musicManager: MusicManager
    @ObservedObject var animator: LockScreenMediaPanelAnimator
    @AppStorage(AppPreferenceKey.useTransparentBackground) private var useTransparentBackground = PreferenceDefault.useTransparentBackground
    
    // MARK: - Layout Constants
    private let panelWidth: CGFloat = 420
    private let panelHeight: CGFloat = 180
    private let albumArtSize: CGFloat = 72
    private let albumArtCornerRadius: CGFloat = 16
    private let controlButtonSize: CGFloat = 44
    private let playPauseButtonSize: CGFloat = 44
    private let horizontalPadding: CGFloat = 24
    private let verticalPadding: CGFloat = 20
    private let cornerRadius: CGFloat = 28
    
    // MARK: - Computed Properties
    
    /// Visualizer color extracted from album art
    private var visualizerColor: Color {
        musicManager.visualizerColor
    }
    
    // MARK: - Body
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: musicManager.isPlaying ? 0.5 : 60)) { context in
            let estimatedTime = musicManager.estimatedPlaybackPosition(at: context.date)
            let progress: Double = musicManager.songDuration > 0 
                ? min(1, max(0, estimatedTime / musicManager.songDuration)) 
                : 0
            
            VStack(spacing: 0) {
                // Row 1: Album Art | Track Info | Visualizer
                headerRow
                    .padding(.bottom, 16)
                
                // Row 2: Progress bar with timestamps (full width)
                progressBar(progress: progress, estimatedTime: estimatedTime)
                    .padding(.bottom, 16)
                
                // Row 3: Playback controls (centered)
                playbackControls
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: panelWidth, height: panelHeight)
            .background(panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(useTransparentBackground ? 0.25 : 0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 40, x: 0, y: 20)
            // Entry/exit animations
            .scaleEffect(animator.isPresented ? 1 : 0.85, anchor: .center)
            .opacity(animator.isPresented ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: animator.isPresented)
        }
    }
    
    // MARK: - Panel Background
    
    @ViewBuilder
    private var panelBackground: some View {
        if useTransparentBackground {
            // Beautiful glass effect
            ZStack {
                // Ultra thin material for glass effect
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                
                // Subtle color tint from album art
                visualizerColor.opacity(0.08)
                
                // Premium glass gradient overlay
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            // Dark solid mode
            ZStack {
                // Solid dark background
                Color.black.opacity(0.85)
                
                // Subtle gradient for depth
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }
    
    // MARK: - Header Row (Album Art | Track Info | Visualizer)
    
    private var headerRow: some View {
        HStack(spacing: 16) {
            // Left: Album art with inner shadow for depth
            albumArtView
            
            // Center-left: Track info (title + artist)
            VStack(alignment: .leading, spacing: 4) {
                // Song title - prominent
                Text(musicManager.songTitle.isEmpty ? "Not Playing" : musicManager.songTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                // Artist name - secondary
                Text(musicManager.artistName.isEmpty ? "Unknown Artist" : musicManager.artistName)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right: Visualizer (matches reference image style)
            AudioSpectrumView(
                isPlaying: musicManager.isPlaying,
                barCount: 4,
                barWidth: 4,
                spacing: 3,
                height: 32,
                color: .white
            )
        }
    }
    
    // MARK: - Album Art
    
    @ViewBuilder
    private var albumArtView: some View {
        ZStack {
            if musicManager.albumArt.size.width > 0 {
                Image(nsImage: musicManager.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: albumArtSize, height: albumArtSize)
                    .clipShape(RoundedRectangle(cornerRadius: albumArtCornerRadius, style: .continuous))
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: albumArtCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: albumArtSize, height: albumArtSize)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                    )
            }
        }
        // Subtle shadow for depth
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        // Inner border for glass effect
        .overlay(
            RoundedRectangle(cornerRadius: albumArtCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
    
    // MARK: - Progress Bar (Full Width with Timestamps)
    
    private func progressBar(progress: Double, estimatedTime: Double) -> some View {
        VStack(spacing: 6) {
            // Progress track (full width)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 5)
                    
                    // Progress fill - beautiful gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.95), .white.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress), height: 5)
                }
            }
            .frame(height: 5)
            
            // Time labels (full width - perfectly symmetric)
            HStack {
                Text(formatTime(estimatedTime))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.55))
                
                Spacer()
                
                Text(formatTime(musicManager.songDuration))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }
    
    // MARK: - Playback Controls (Centered)
    
    private var playbackControls: some View {
        HStack(spacing: 48) {
            // Previous track
            Button {
                musicManager.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: controlButtonSize, height: controlButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Play/Pause - slightly larger
            Button {
                musicManager.togglePlay()
            } label: {
                Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: playPauseButtonSize, height: playPauseButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Next track
            Button {
                musicManager.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: controlButtonSize, height: controlButtonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helpers
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Visual Effect View (NSVisualEffectView wrapper)

private struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.blue.opacity(0.6)
        LockScreenMediaPanelView(animator: LockScreenMediaPanelAnimator())
            .environmentObject(MusicManager.shared)
    }
    .frame(width: 500, height: 300)
}
