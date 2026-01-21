//
//  DroppyAnimation.swift
//  Droppy
//
//  Single Source of Truth for all animations.
//  High-quality, buttery-smooth animations with consistent timing.
//

import SwiftUI

// MARK: - Animation Constants (SSOT)

/// Single Source of Truth for Droppy's animation system.
/// Use these presets for consistent, high-quality animations throughout the app.
enum DroppyAnimation {
    
    // MARK: - Hover Animations
    
    /// Standard hover animation - smooth, responsive, slight bounce.
    /// Use for: buttons, cards, list items, interactive elements.
    static let hover = Animation.spring(response: 0.25, dampingFraction: 0.7)
    
    /// Quick hover animation - instant feedback, no bounce.
    /// Use for: small indicators, icons, subtle state changes.
    static let hoverQuick = Animation.easeOut(duration: 0.12)
    
    // MARK: - State Transitions
    
    /// Standard state change - natural, fluid.
    /// Use for: toggle states, selection changes, mode switches.
    static let state = Animation.spring(response: 0.3, dampingFraction: 0.75)
    
    /// Emphasized state change - bouncy, noticeable.
    /// Use for: favorites, flags, important state changes.
    static let stateEmphasis = Animation.spring(response: 0.35, dampingFraction: 0.6)
    
    // MARK: - Layout Animations
    
    /// List reordering animation - smooth, avoids jank.
    /// Use for: sorting, filtering, item insertion/removal.
    static let listChange = Animation.spring(response: 0.35, dampingFraction: 0.8)
    
    /// View transitions - elegant entrance/exit.
    /// Use for: sheets, popovers, panels appearing/disappearing.
    static let transition = Animation.spring(response: 0.4, dampingFraction: 0.75)
    
    // MARK: - Interactive Animations
    
    /// Press feedback - immediate response.
    /// Use for: button press down state.
    static let press = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.8)
    
    /// Release feedback - natural bounce back.
    /// Use for: button release, drag end.
    static let release = Animation.spring(response: 0.3, dampingFraction: 0.65)
    
    /// Drag tracking - follows finger precisely.
    /// Use for: active dragging, live updates.
    static let drag = Animation.interactiveSpring(response: 0.1, dampingFraction: 0.9)
    
    // MARK: - Scale Animations
    
    /// Hover scale animation (small).
    /// Use for: subtle hover feedback on cards.
    static let scaleHover = Animation.spring(response: 0.25, dampingFraction: 0.7)
    
    /// Pop scale animation.
    /// Use for: attention-grabbing effects, notifications.
    static let scalePop = Animation.spring(response: 0.3, dampingFraction: 0.5)
    
    // MARK: - Timing Curves (for non-spring animations)
    
    /// Smooth ease-out curve.
    static let easeOut = Animation.easeOut(duration: 0.15)
    
    /// Smooth ease-in-out curve.
    static let easeInOut = Animation.easeInOut(duration: 0.2)
    
    /// Quick linear (for progress indicators).
    static let linear = Animation.linear(duration: 0.1)
}

// MARK: - View Extension for Animated Hover

extension View {
    /// Applies smooth hover state tracking with DroppyAnimation timing.
    /// - Parameters:
    ///   - isHovering: Binding to the hover state.
    ///   - animation: The animation to use (defaults to `.hover`).
    func droppyHover(
        _ isHovering: Binding<Bool>,
        animation: Animation = DroppyAnimation.hover
    ) -> some View {
        self.onHover { hovering in
            withAnimation(animation) {
                isHovering.wrappedValue = hovering
            }
        }
    }
    
    /// Applies smooth hover tracking with callback instead of binding.
    func droppyHover(
        animation: Animation = DroppyAnimation.hover,
        perform action: @escaping (Bool) -> Void
    ) -> some View {
        self.onHover { hovering in
            withAnimation(animation) {
                action(hovering)
            }
        }
    }
}

// MARK: - Animated State Change Helper

extension View {
    /// Wraps a state change in the standard Droppy animation.
    func animateState<T: Equatable>(
        _ value: T,
        animation: Animation = DroppyAnimation.state
    ) -> some View {
        self.animation(animation, value: value)
    }
}
