//
//  MenuBarItemScanner.swift
//  Droppy
//
//  Scans the menu bar for status items using CGWindow API.
//

import Cocoa
import Combine

/// Scans the menu bar to discover status bar items
@MainActor
final class MenuBarItemScanner: ObservableObject {
    
    /// Discovered menu bar items
    @Published var menuBarItems: [ScannedMenuItem] = []
    
    /// Whether scanning is currently in progress
    @Published var isScanning = false
    
    // MARK: - Types
    
    /// A scanned menu bar item
    struct ScannedMenuItem: Identifiable, Equatable {
        var id: Int { windowID }
        
        let windowID: Int
        let ownerName: String
        let ownerPID: Int
        let frame: CGRect
        let icon: NSImage?
        
        static func == (lhs: ScannedMenuItem, rhs: ScannedMenuItem) -> Bool {
            lhs.windowID == rhs.windowID
        }
    }
    
    // MARK: - Scanning
    
    /// Scan the menu bar for status items
    func scan() {
        isScanning = true
        
        // Get all windows on screen
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            isScanning = false
            return
        }
        
        var items: [ScannedMenuItem] = []
        
        for windowInfo in windowList {
            // Only look at status bar items (layer 25 is status bar level)
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 25 else {
                continue
            }
            
            guard let windowID = windowInfo[kCGWindowNumber as String] as? Int,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }
            
            // Skip certain system items we don't want to show
            let skipApps = ["Control Center", "SystemUIServer"]
            if skipApps.contains(ownerName) {
                continue
            }
            
            // Parse the frame
            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            // Try to get the app icon
            let icon = getAppIcon(for: ownerPID)
            
            let item = ScannedMenuItem(
                windowID: windowID,
                ownerName: ownerName,
                ownerPID: ownerPID,
                frame: frame,
                icon: icon
            )
            
            items.append(item)
        }
        
        // Sort by X position (left to right)
        menuBarItems = items.sorted { $0.frame.minX < $1.frame.minX }
        isScanning = false
        
        print("[MenuBarItemScanner] Found \(menuBarItems.count) menu bar items")
    }
    
    /// Get the app icon for a given PID
    private func getAppIcon(for pid: Int) -> NSImage? {
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
            return nil
        }
        return app.icon
    }
    
    /// Capture the actual status item image from screen
    /// This requires screen recording permission
    private func captureStatusItemImage(windowID: Int, frame: CGRect) -> NSImage? {
        // Create image from the specific window
        guard let cgImage = CGWindowListCreateImage(
            frame,
            .optionIncludingWindow,
            CGWindowID(windowID),
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))
    }
    
    /// Check if we have screen recording permission
    var hasScreenCapturePermission: Bool {
        // Try to capture a test image to check permission
        let testImage = CGWindowListCreateImage(
            CGRect(x: 0, y: 0, width: 1, height: 1),
            .optionOnScreenOnly,
            kCGNullWindowID,
            []
        )
        return testImage != nil
    }
    
    /// Scan with screen capture for actual icons (requires permission)
    func scanWithCapture() {
        isScanning = true
        
        // Get all windows on screen
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            isScanning = false
            return
        }
        
        var items: [ScannedMenuItem] = []
        
        for windowInfo in windowList {
            // Only look at status bar items (layer 25 is status bar level)
            guard let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 25 else {
                continue
            }
            
            guard let windowID = windowInfo[kCGWindowNumber as String] as? Int,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat] else {
                continue
            }
            
            // Skip certain system items we don't want to show
            let skipApps = ["Control Center", "SystemUIServer"]
            if skipApps.contains(ownerName) {
                continue
            }
            
            // Parse the frame
            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            
            // Try to capture the actual status item image, fallback to app icon
            let icon = captureStatusItemImage(windowID: windowID, frame: frame)
                ?? getAppIcon(for: ownerPID)
            
            let item = ScannedMenuItem(
                windowID: windowID,
                ownerName: ownerName,
                ownerPID: ownerPID,
                frame: frame,
                icon: icon
            )
            
            items.append(item)
        }
        
        // Sort by X position (left to right)
        menuBarItems = items.sorted { $0.frame.minX < $1.frame.minX }
        isScanning = false
        
        print("[MenuBarItemScanner] Found \(menuBarItems.count) menu bar items (with capture)")
    }
}
