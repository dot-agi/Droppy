//
//  MenuBarManagerManager.swift
//  Droppy
//
//  Menu Bar Manager - Hide/show menu bar icons using divider expansion pattern
//

import SwiftUI
import AppKit
import Combine

// MARK: - Menu Bar Manager

@MainActor
final class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    // MARK: - State
    
    enum HidingState {
        case hideItems  // Separator expanded to 10,000pt, icons pushed off
        case showItems  // Separator at normal width, icons visible
    }
    
    /// Whether the extension is enabled
    @Published private(set) var isEnabled = false
    
    /// Current hiding state
    @Published private(set) var state = HidingState.showItems
    
    /// Convenience: whether icons are currently visible
    var isExpanded: Bool { state == .showItems }
    
    // MARK: - Status Items
    
    /// The main toggle button (rightmost, user clicks to toggle visibility)
    private var mainItem: NSStatusItem?
    
    /// The hidden section divider (to the LEFT of main, expands to push icons off screen)
    private var dividerItem: NSStatusItem?
    
    // Autosave names - following Ice's pattern
    private static let mainAutosaveName = "DroppyMBM_Icon"
    private static let dividerAutosaveName = "DroppyMBM_Hidden"
    
    // MARK: - Constants (from Ice)
    
    /// Standard length for visible control items
    private let lengthStandard = NSStatusItem.variableLength
    
    /// Expanded length to push items off screen (Ice uses 10_000)
    private let lengthExpanded: CGFloat = 10_000
    
    // MARK: - Persistence Keys
    
    private let enabledKey = "menuBarManagerEnabled"
    private let stateKey = "menuBarManagerState"  // "hideItems" or "showItems"
    
    // MARK: - Initialization
    
    private init() {
        // Only start if extension is not removed
        guard !ExtensionType.menuBarManager.isRemoved else { return }
        
        if UserDefaults.standard.bool(forKey: enabledKey) {
            enable()
        }
    }
    
    // MARK: - Position Management (Ice Pattern)
    
    /// Get the preferred position from UserDefaults
    private static func getPreferredPosition(for autosaveName: String) -> CGFloat? {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        return UserDefaults.standard.object(forKey: key) as? CGFloat
    }
    
    /// Set the preferred position in UserDefaults
    private static func setPreferredPosition(_ position: CGFloat?, for autosaveName: String) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        if let position = position {
            UserDefaults.standard.set(position, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    /// Seed initial positions BEFORE creating items (Ice pattern)
    /// Only seeds if positions are not already set
    private static func seedPositionsIfNeeded() {
        // Main icon at position 0 (rightmost)
        if getPreferredPosition(for: mainAutosaveName) == nil {
            setPreferredPosition(0, for: mainAutosaveName)
            print("[MenuBarManager] Seeded main icon position")
        }
        // Divider at position 1 (to the left of main)
        if getPreferredPosition(for: dividerAutosaveName) == nil {
            setPreferredPosition(1, for: dividerAutosaveName)
            print("[MenuBarManager] Seeded divider position")
        }
    }
    
    // MARK: - Public API
    
    /// Enable the menu bar manager
    func enable() {
        guard !isEnabled else { return }
        
        isEnabled = true
        UserDefaults.standard.set(true, forKey: enabledKey)
        
        // Seed positions BEFORE creating items (critical Ice pattern)
        Self.seedPositionsIfNeeded()
        
        // Create status items
        createStatusItems()
        
        // Restore previous state
        if let savedState = UserDefaults.standard.string(forKey: stateKey) {
            state = savedState == "hideItems" ? .hideItems : .showItems
        } else {
            state = .showItems  // Default: show all icons
        }
        applyState()
        
        print("[MenuBarManager] Enabled, state: \(state)")
    }
    
    /// Disable the menu bar manager
    func disable() {
        guard isEnabled else { return }
        
        // Show all items before disabling
        if state == .hideItems {
            state = .showItems
            applyState()
        }
        
        isEnabled = false
        UserDefaults.standard.set(false, forKey: enabledKey)
        
        // Remove status items (with position preservation)
        removeStatusItems()
        
        print("[MenuBarManager] Disabled")
    }
    
    /// Toggle between showing and hiding items
    func toggle() {
        state = (state == .showItems) ? .hideItems : .showItems
        UserDefaults.standard.set(state == .hideItems ? "hideItems" : "showItems", forKey: stateKey)
        applyState()
        
        // Notify for Droppy menu refresh
        NotificationCenter.default.post(name: .menuBarManagerStateChanged, object: nil)
        
        print("[MenuBarManager] Toggled to: \(state)")
    }
    
    /// Legacy compatibility
    func toggleExpanded() {
        toggle()
    }
    
    /// Clean up all resources
    func cleanup() {
        disable()
        UserDefaults.standard.removeObject(forKey: enabledKey)
        UserDefaults.standard.removeObject(forKey: stateKey)
        
        // Clear saved positions for fresh start on next enable
        Self.setPreferredPosition(nil, for: Self.mainAutosaveName)
        Self.setPreferredPosition(nil, for: Self.dividerAutosaveName)
        
        print("[MenuBarManager] Cleanup complete")
    }
    
    // MARK: - Status Items Creation
    
    private func createStatusItems() {
        // Create MAIN item (user's toggle button)
        mainItem = NSStatusBar.system.statusItem(withLength: lengthStandard)
        mainItem?.autosaveName = Self.mainAutosaveName
        
        if let button = mainItem?.button {
            button.target = self
            button.action = #selector(mainItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create DIVIDER item (the hidden section marker that expands)
        dividerItem = NSStatusBar.system.statusItem(withLength: lengthStandard)
        dividerItem?.autosaveName = Self.dividerAutosaveName
        
        if let button = dividerItem?.button {
            button.target = self
            button.action = #selector(dividerClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        print("[MenuBarManager] Created status items")
    }
    
    private func removeStatusItems() {
        // Ice pattern: Cache positions before removing, then restore after
        // This prevents NSStatusBar from clearing the preferred positions
        
        if let item = mainItem {
            let autosave = item.autosaveName as String
            let cached = Self.getPreferredPosition(for: autosave)
            NSStatusBar.system.removeStatusItem(item)
            Self.setPreferredPosition(cached, for: autosave)
            mainItem = nil
        }
        
        if let item = dividerItem {
            let autosave = item.autosaveName as String
            let cached = Self.getPreferredPosition(for: autosave)
            NSStatusBar.system.removeStatusItem(item)
            Self.setPreferredPosition(cached, for: autosave)
            dividerItem = nil
        }
        
        print("[MenuBarManager] Removed status items")
    }
    
    // MARK: - State Application (Ice Pattern)
    
    private func applyState() {
        updateMainItem()
        updateDividerItem()
    }
    
    private func updateMainItem() {
        guard let button = mainItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        
        switch state {
        case .showItems:
            // Icons are visible - show eye icon
            button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "Hide menu bar icons")?
                .withSymbolConfiguration(config)
        case .hideItems:
            // Icons are hidden - show slashed eye
            button.image = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: "Show menu bar icons")?
                .withSymbolConfiguration(config)
        }
        button.image?.isTemplate = true
    }
    
    private func updateDividerItem() {
        guard let dividerItem = dividerItem, let button = dividerItem.button else { return }
        
        switch state {
        case .showItems:
            // Normal width - show chevron indicator
            dividerItem.length = lengthStandard
            button.cell?.isEnabled = true
            button.alphaValue = 0.7
            
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            button.image = NSImage(systemSymbolName: "chevron.compact.left", accessibilityDescription: "Drag icons left to hide")?
                .withSymbolConfiguration(config)
            button.image?.isTemplate = true
            
        case .hideItems:
            // Expanded to push icons off - hide the button content (Ice pattern)
            dividerItem.length = lengthExpanded
            button.cell?.isEnabled = false  // Prevent highlighting
            button.isHighlighted = false     // Force unhighlight
            button.image = nil               // Hide the chevron
        }
    }
    
    // MARK: - Actions
    
    @objc private func mainItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            toggle()
        }
    }
    
    @objc private func dividerClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        switch event.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            toggle()
        }
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        
        let toggleTitle = (state == .showItems) ? "Hide Menu Bar Icons" : "Show Menu Bar Icons"
        menu.addItem(withTitle: toggleTitle, action: #selector(toggleFromMenu), keyEquivalent: "")
        menu.items.last?.target = self
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "How to Use", action: #selector(showHowTo), keyEquivalent: "")
        menu.items.last?.target = self
        
        menu.addItem(.separator())
        
        menu.addItem(withTitle: "Disable Menu Bar Manager", action: #selector(disableFromMenu), keyEquivalent: "")
        menu.items.last?.target = self
        
        mainItem?.menu = menu
        mainItem?.button?.performClick(nil)
        mainItem?.menu = nil
    }
    
    @objc private func toggleFromMenu() {
        toggle()
    }
    
    @objc private func showHowTo() {
        DroppyAlertController.shared.showSimple(
            style: .info,
            title: "How to Use Menu Bar Manager",
            message: "1. Hold ⌘ and drag icons to the LEFT of the chevron ‹\n2. Click the eye icon to hide/show those icons\n\nIcons to the RIGHT of the chevron stay visible."
        )
    }
    
    @objc private func disableFromMenu() {
        disable()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openMenuBarManagerSettings = Notification.Name("openMenuBarManagerSettings")
    static let menuBarManagerStateChanged = Notification.Name("menuBarManagerStateChanged")
}
