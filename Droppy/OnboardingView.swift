//
//  OnboardingView.swift
//  Droppy
//
//  Clean, focused onboarding wizard - 4 pages only
//

import SwiftUI
import AppKit

// MARK: - Onboarding Page Model

enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case features
    case setup
    case ready
    
    /// Whether this page should be shown for the current device
    var shouldShow: Bool { true }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    // Essential toggles only
    @AppStorage("enableNotchShelf") private var enableShelf = true
    @AppStorage("enableFloatingBasket") private var enableBasket = true
    @AppStorage("enableClipboardBeta") private var enableClipboard = true  // ON by default
    @AppStorage("enableHUDReplacement") private var enableHUDs = true
    @AppStorage("useDynamicIslandStyle") private var useDynamicIslandStyle = true
    
    @State private var currentPage: OnboardingPage = .welcome
    @State private var isNextHovering = false
    @State private var isBackHovering = false
    @State private var showConfetti = false
    
    // Animation states for features page
    @State private var featuresAnimated = false
    
    let onComplete: () -> Void
    
    /// Check if this Mac has a notch
    private var hasNotch: Bool {
        guard let screen = NSScreen.main else { return false }
        return screen.safeAreaInsets.top > 0
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Page Content
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(currentPage)
                
                Divider()
                    .padding(.horizontal, 20)
                
                // Navigation
                HStack {
                    // Back button
                    if currentPage != .welcome {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = OnboardingPage(rawValue: currentPage.rawValue - 1) ?? .welcome
                                if currentPage == .features {
                                    featuresAnimated = false
                                    triggerFeaturesAnimation()
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Back")
                            }
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(isBackHovering ? 0.15 : 0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .onHover { h in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                isBackHovering = h
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Page indicators
                    HStack(spacing: 6) {
                        ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                            Circle()
                                .fill(page == currentPage ? Color.blue : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .scaleEffect(page == currentPage ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    Spacer()
                    
                    // Next/Done button
                    Button {
                        if currentPage == .ready {
                            onComplete()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                currentPage = OnboardingPage(rawValue: currentPage.rawValue + 1) ?? .ready
                                if currentPage == .features {
                                    triggerFeaturesAnimation()
                                }
                                if currentPage == .ready {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showConfetti = true
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentPage == .ready ? "Get Started" : "Next")
                            Image(systemName: currentPage == .ready ? "arrow.right.circle.fill" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            (currentPage == .ready ? Color.green : Color.blue)
                                .opacity(isNextHovering ? 1.0 : 0.85)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isNextHovering = h
                        }
                    }
                }
                .padding(20)
            }
            
            // Confetti overlay
            if showConfetti {
                OnboardingConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 680, height: 580)
        .background(Color.black)
        .clipped()
    }
    
    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case .welcome:
            welcomePage
        case .features:
            featuresPage
        case .setup:
            setupPage
        case .ready:
            readyPage
        }
    }
    
    private func triggerFeaturesAnimation() {
        featuresAnimated = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                featuresAnimated = true
            }
        }
    }
    
    // MARK: - Page 1: Welcome
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App Icon with glow
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: 140, height: 140)
                    .blur(radius: 40)
                
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            }
            
            VStack(spacing: 10) {
                Text("Your all-in-one Mac")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text("productivity companion")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text("Free forever. No subscriptions. No hidden costs.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.blue)
                
                Text("We built Droppy because you deserve a beautiful,\npowerful tool without paying monthly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Page 2: Features Overview
    
    private var featuresPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Everything in one place")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            
            // Feature cards - staggered animation
            VStack(spacing: 12) {
                featureRow(
                    icon: "tray.and.arrow.down.fill",
                    color: .blue,
                    title: "Shelf",
                    description: "Drop files into your notch for quick access",
                    delay: 0
                )
                
                featureRow(
                    icon: "basket.fill",
                    color: .purple,
                    title: "Basket",
                    description: "Jiggle while dragging to summon a floating drop zone",
                    delay: 0.08
                )
                
                featureRow(
                    icon: "doc.on.clipboard.fill",
                    color: .cyan,
                    title: "Clipboard",
                    description: "Full history with search, OCR text extraction, and drag-out",
                    delay: 0.16
                )
                
                featureRow(
                    icon: "slider.horizontal.3",
                    color: .orange,
                    title: "System HUDs",
                    description: "Beautiful replacements for volume, brightness, and more",
                    delay: 0.24
                )
                
                featureRow(
                    icon: "puzzlepiece.extension.fill",
                    color: .pink,
                    title: "Extensions",
                    description: "AI background removal, Alfred, Spotify, and more",
                    delay: 0.32
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
        .onAppear {
            triggerFeaturesAnimation()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private func featureRow(icon: String, color: Color, title: String, description: String, delay: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(0.15))
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .opacity(featuresAnimated ? 1 : 0)
        .offset(y: featuresAnimated ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: featuresAnimated)
    }
    
    // MARK: - Page 3: Quick Setup
    
    private var setupPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("Quick Setup")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            
            Text("Toggle the features you want. You can always change these in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
            
            // Essential toggles grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    setupToggle(icon: "tray.and.arrow.down.fill", title: "Shelf", color: .blue, isOn: $enableShelf)
                    setupToggle(icon: "basket.fill", title: "Basket", color: .purple, isOn: $enableBasket)
                }
                
                HStack(spacing: 12) {
                    setupToggle(icon: "doc.on.clipboard.fill", title: "Clipboard", color: .cyan, isOn: $enableClipboard)
                    setupToggle(icon: "slider.horizontal.3", title: "System HUDs", color: .orange, isOn: $enableHUDs)
                }
            }
            .padding(.horizontal, 100)
            
            // Display mode picker (only for non-notch Macs)
            if !hasNotch {
                VStack(spacing: 12) {
                    Text("Display Mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        displayModeButton(
                            title: "Notch",
                            isSelected: !useDynamicIslandStyle
                        ) {
                            useDynamicIslandStyle = false
                        }
                        
                        displayModeButton(
                            title: "Dynamic Island",
                            isSelected: useDynamicIslandStyle
                        ) {
                            useDynamicIslandStyle = true
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Keyboard shortcut hint
            HStack(spacing: 6) {
                Text("Tip:")
                    .foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    keyBadge("⌘")
                    keyBadge("⇧")
                    keyBadge("Space")
                }
                Text("opens Clipboard")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.top, 8)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    private func setupToggle(icon: String, title: String, color: Color, isOn: Binding<Bool>) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn.wrappedValue ? color.opacity(0.2) : Color.white.opacity(0.05))
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isOn.wrappedValue ? color : .secondary)
                }
                .frame(width: 40, height: 40)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isOn.wrappedValue ? .white : .secondary)
                
                Spacer()
                
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn.wrappedValue ? .green : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(isOn.wrappedValue ? 0.08 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn.wrappedValue ? color.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func displayModeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue.opacity(0.8) : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private func keyBadge(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
    }
    
    // MARK: - Page 4: Ready
    
    private var readyPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 8) {
                Text("You're all set!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.green)
                
                Text("Droppy is ready to boost your productivity")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            // Extension Store preview card
            Button {
                // Open extension store
                if let url = URL(string: "https://iordv.github.io/Droppy/extensions.html") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .frame(width: 48, height: 48)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Explore Extensions")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("AI background removal, Alfred, Spotify & more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 80)
            .padding(.top, 8)
            
            Text("Look for Droppy in your menu bar")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            
            Spacer()
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
}

// MARK: - Confetti View

struct OnboardingConfettiView: View {
    @State private var particles: [OnboardingParticle] = []
    @State private var isVisible = true
    
    var body: some View {
        GeometryReader { geo in
            if isVisible {
                Canvas { context, size in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.currentX - particle.size / 2,
                            y: particle.currentY - particle.size * 0.75,
                            width: particle.size,
                            height: particle.size * 1.5
                        )
                        context.fill(
                            RoundedRectangle(cornerRadius: 1).path(in: rect),
                            with: .color(particle.color.opacity(particle.opacity))
                        )
                    }
                }
                .onAppear {
                    createParticles(in: geo.size)
                    startAnimation()
                }
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        let colors: [Color] = [.blue, .green, .yellow, .orange, .pink, .purple, .cyan]
        
        for i in 0..<24 {
            var particle = OnboardingParticle(
                id: i,
                x: CGFloat.random(in: 40...(size.width - 40)),
                startY: size.height + 10,
                endY: CGFloat.random(in: -20...size.height * 0.3),
                color: colors[i % colors.count],
                size: CGFloat.random(in: 5...8),
                delay: Double(i) * 0.015
            )
            particle.currentX = particle.x
            particle.currentY = particle.startY
            particles.append(particle)
        }
    }
    
    private func startAnimation() {
        for i in 0..<particles.count {
            let delay = particles[i].delay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard i < particles.count else { return }
                withAnimation(.easeOut(duration: 1.2)) {
                    particles[i].currentY = particles[i].endY
                    particles[i].currentX = particles[i].x + CGFloat.random(in: -30...30)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.9) {
                guard i < particles.count else { return }
                withAnimation(.easeIn(duration: 0.3)) {
                    particles[i].opacity = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isVisible = false
        }
    }
}

struct OnboardingParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let startY: CGFloat
    let endY: CGFloat
    let color: Color
    let size: CGFloat
    let delay: Double
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var opacity: Double = 1
}

// MARK: - Window Controller

final class OnboardingWindowController: NSObject {
    static let shared = OnboardingWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    func show() {
        // If window exists and is visible, just bring to front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Clear any stale reference before creating new window
        window = nil
        
        let contentView = OnboardingView { [weak self] in
            // Defer to next runloop to avoid releasing view while callback is in progress
            DispatchQueue.main.async {
                // Mark onboarding as complete first
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                self?.close()
            }
        }
        
        let hostingView = NSHostingView(rootView: contentView)
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 580),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.backgroundColor = .black
        newWindow.isMovableByWindowBackground = true
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.level = .floating
        
        // Store reference AFTER setup
        window = newWindow
        
        // Fade in - use deferred makeKey to avoid NotchWindow conflicts
        newWindow.alphaValue = 0
        newWindow.orderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            newWindow.makeKeyAndOrderFront(nil)
        }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            newWindow.animator().alphaValue = 1.0
        }
    }
    
    func close() {
        guard let panel = window else { return }
        
        // Capture and nil reference AFTER animation to keep window alive
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // Now safe to release - animation is done
            self?.window = nil
            panel.orderOut(nil)
        })
    }
}
