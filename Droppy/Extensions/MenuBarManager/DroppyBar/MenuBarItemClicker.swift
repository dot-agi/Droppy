//
//  MenuBarItemClicker.swift
//  Droppy
//
//  Handles clicking menu bar items.
//  Simplified implementation based on Ice's approach.
//

import Cocoa

/// Handles clicking menu bar items
@MainActor
final class MenuBarItemClicker {
    
    /// Shared instance
    static let shared = MenuBarItemClicker()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Click a menu bar item
    /// - Parameters:
    ///   - item: The menu bar item to click
    ///   - mouseButton: Which mouse button to use (.left or .right)
    func clickItem(_ item: MenuBarItem, mouseButton: CGMouseButton = .left) {
        Task { @MainActor in
            await performClick(item: item, mouseButton: mouseButton)
        }
    }
    
    // MARK: - Private Implementation
    
    /// Perform a click on the item
    private func performClick(item: MenuBarItem, mouseButton: CGMouseButton) async {
        // Get current frame (item may have moved)
        guard let currentFrame = MenuBarItem.getCurrentFrame(for: item.windowID),
              currentFrame.width > 0 else {
            print("[Clicker] Could not get frame for \(item.displayName)")
            // Fallback: activate the app
            if let app = item.owningApplication {
                app.activate()
            }
            return
        }
        
        // Save current cursor position
        guard let cursorLocation = CGEvent(source: nil)?.location else {
            print("[Clicker] Could not get cursor location")
            return
        }
        
        // Calculate click point (center of item in CoreGraphics coordinates)
        let clickPoint = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        
        print("[Clicker] Clicking \(item.displayName) at (\(clickPoint.x), \(clickPoint.y))")
        
        // Create event source
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("[Clicker] Could not create event source")
            return
        }
        
        // Permit events during suppression states (like Ice does)
        source.setLocalEventsFilterDuringSuppressionState(
            .permitLocalMouseEvents,
            state: .eventSuppressionStateRemoteMouseDrag
        )
        source.setLocalEventsFilterDuringSuppressionState(
            .permitLocalMouseEvents,
            state: .eventSuppressionStateSuppressionInterval
        )
        source.localEventsSuppressionInterval = 0
        
        // Get mouse button event types
        let (downType, upType) = getEventTypes(for: mouseButton)
        
        // Create events
        guard let mouseDown = CGEvent(
            mouseEventSource: source,
            mouseType: downType,
            mouseCursorPosition: clickPoint,
            mouseButton: mouseButton
        ) else {
            print("[Clicker] Could not create mouseDown event")
            return
        }
        
        guard let mouseUp = CGEvent(
            mouseEventSource: source,
            mouseType: upType,
            mouseCursorPosition: clickPoint,
            mouseButton: mouseButton
        ) else {
            print("[Clicker] Could not create mouseUp event")
            return
        }
        
        // Set target fields (like Ice does)
        let windowNumber = Int64(item.windowID)
        mouseDown.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(item.ownerPID))
        mouseUp.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(item.ownerPID))
        
        // Also set window-related fields for better targeting
        mouseDown.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowNumber)
        mouseUp.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowNumber)
        
        // Hide cursor (like Ice)
        CGDisplayHideCursor(CGMainDisplayID())
        
        // Warp cursor to click point
        CGWarpMouseCursorPosition(clickPoint)
        
        // Small delay for warp to settle
        try? await Task.sleep(for: .milliseconds(10))
        
        // Post events
        mouseDown.post(tap: .cgSessionEventTap)
        
        // Small delay between down and up
        try? await Task.sleep(for: .milliseconds(50))
        
        mouseUp.post(tap: .cgSessionEventTap)
        
        // Wait a bit then restore cursor
        try? await Task.sleep(for: .milliseconds(100))
        
        // Restore cursor position
        CGWarpMouseCursorPosition(cursorLocation)
        CGDisplayShowCursor(CGMainDisplayID())
        
        print("[Clicker] Click complete for \(item.displayName)")
    }
    
    /// Get event types for mouse button
    private func getEventTypes(for button: CGMouseButton) -> (down: CGEventType, up: CGEventType) {
        switch button {
        case .left:
            return (.leftMouseDown, .leftMouseUp)
        case .right:
            return (.rightMouseDown, .rightMouseUp)
        case .center:
            return (.otherMouseDown, .otherMouseUp)
        @unknown default:
            return (.leftMouseDown, .leftMouseUp)
        }
    }
}
