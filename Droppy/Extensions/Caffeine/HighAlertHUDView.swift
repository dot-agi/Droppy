//
//  HighAlertHUDView.swift
//  Droppy
//
//  High Alert HUD matching CapsLockHUDView style exactly
//  Shows eyes icon on left wing, Active/Inactive on right wing
//

import SwiftUI

/// Compact High Alert HUD that sits inside the notch
/// Matches CapsLockHUDView layout: icon on left wing, status on right wing
struct HighAlertHUDView: View {
    let isActive: Bool
    let hudWidth: CGFloat     // Total HUD width
    var targetScreen: NSScreen? = nil  // Target screen for multi-monitor support
    
    /// Centralized layout calculator - Single Source of Truth
    private var layout: HUDLayoutCalculator {
        HUDLayoutCalculator(screen: targetScreen ?? NSScreen.main ?? NSScreen.screens.first)
    }
    
    /// Accent color based on High Alert state
    private var accentColor: Color {
        isActive ? .orange : .white
    }
    
    /// High Alert icon - use filled variant when active
    private var alertIcon: String {
        isActive ? "eyes" : "eyes"  // Same icon, color changes
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if layout.isDynamicIslandMode {
                // DYNAMIC ISLAND: Icon on left edge, Active/Inactive on right edge
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                
                HStack {
                    // High Alert icon - .leading alignment within frame
                    Image(systemName: alertIcon)
                        .font(.system(size: iconSize, weight: .semibold))
                        .foregroundStyle(layout.adjustedColor(accentColor))
                        .symbolEffect(.bounce.up, value: isActive)
                        .frame(width: 24, height: iconSize, alignment: .leading)
                    
                    Spacer()
                    
                    // Active/Inactive text
                    Text(isActive ? "Active" : "Inactive")
                        .font(.system(size: layout.labelFontSize, weight: .semibold))
                        .foregroundStyle(layout.adjustedColor(accentColor))
                        .contentTransition(.interpolate)
                }
                .padding(.horizontal, symmetricPadding)
                .frame(height: layout.notchHeight)
            } else {
                // NOTCH MODE: Two wings separated by the notch space
                let iconSize = layout.iconSize
                let symmetricPadding = layout.symmetricPadding(for: iconSize)
                let wingWidth = layout.wingWidth(for: hudWidth)
                
                HStack(spacing: 0) {
                    // Left wing: High Alert icon near left edge
                    HStack {
                        Image(systemName: alertIcon)
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .symbolEffect(.bounce.up, value: isActive)
                            .frame(width: iconSize + 4, height: iconSize, alignment: .leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, symmetricPadding)
                    .frame(width: wingWidth)
                    
                    // Camera notch area (spacer)
                    Spacer()
                        .frame(width: layout.notchWidth)
                    
                    // Right wing: Active/Inactive near right edge
                    HStack {
                        Spacer(minLength: 0)
                        Text(isActive ? "Active" : "Inactive")
                            .font(.system(size: layout.labelFontSize, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .contentTransition(.interpolate)
                            .animation(DroppyAnimation.notchState, value: isActive)
                    }
                    .padding(.trailing, symmetricPadding)
                    .frame(width: wingWidth)
                }
                .frame(height: layout.notchHeight)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        HighAlertHUDView(
            isActive: true,
            hudWidth: 300
        )
    }
    .frame(width: 350, height: 60)
}
