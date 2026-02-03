//
//  ReorderableGrid.swift
//  Droppy
//
//  iPhone-style drag-to-rearrange for grid layouts.
//  Items animate apart to make room during drag.
//

import SwiftUI

// MARK: - Reorderable ForEach

/// A ForEach that supports drag-to-rearrange with animated item displacement.
/// Items push apart during drag to show where the dragged item will land.
struct ReorderableForEach<Item: Identifiable, Content: View>: View {
    @Binding var items: [Item]
    let columns: Int
    let itemSize: CGSize
    let spacing: CGFloat
    let content: (Item) -> Content
    
    // Drag state
    @State private var draggingItem: Item.ID?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartPosition: CGPoint = .zero
    @State private var hasStartedDrag = false
    
    // Layout tracking
    @State private var itemPositions: [Item.ID: CGPoint] = [:]
    
    init(
        _ items: Binding<[Item]>,
        columns: Int,
        itemSize: CGSize,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self._items = items
        self.columns = columns
        self.itemSize = itemSize
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Layout items manually with computed positions
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .frame(width: itemSize.width, height: itemSize.height)
                    .offset(offsetFor(item: item, at: index))
                    .zIndex(item.id == draggingItem ? 100 : 0)
                    .scaleEffect(item.id == draggingItem ? 1.05 : 1.0)
                    .shadow(
                        color: item.id == draggingItem ? .black.opacity(0.3) : .clear,
                        radius: item.id == draggingItem ? 8 : 0
                    )
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if draggingItem == nil {
                                    // Start drag
                                    draggingItem = item.id
                                    dragStartPosition = positionFor(index: index)
                                    hasStartedDrag = true
                                    HapticFeedback.tap()
                                }
                                
                                if draggingItem == item.id {
                                    dragOffset = value.translation
                                    
                                    // Calculate target index based on drag position
                                    let currentPos = CGPoint(
                                        x: dragStartPosition.x + dragOffset.width,
                                        y: dragStartPosition.y + dragOffset.height
                                    )
                                    let targetIndex = indexFor(position: currentPos)
                                    let currentIndex = items.firstIndex(where: { $0.id == item.id }) ?? index
                                    
                                    // Move item in array when crossing threshold
                                    if targetIndex != currentIndex && targetIndex >= 0 && targetIndex < items.count {
                                        withAnimation(DroppyAnimation.bouncy) {
                                            items.move(fromOffsets: IndexSet(integer: currentIndex), toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex)
                                        }
                                        HapticFeedback.select()
                                    }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(DroppyAnimation.bouncy) {
                                    draggingItem = nil
                                    dragOffset = .zero
                                    hasStartedDrag = false
                                }
                            }
                    )
                    .animation(item.id == draggingItem ? nil : DroppyAnimation.bouncy, value: items.map(\.id))
            }
        }
        .frame(
            width: CGFloat(columns) * itemSize.width + CGFloat(columns - 1) * spacing,
            height: ceil(CGFloat(items.count) / CGFloat(columns)) * itemSize.height + 
                   max(0, ceil(CGFloat(items.count) / CGFloat(columns)) - 1) * spacing,
            alignment: .topLeading
        )
    }
    
    // MARK: - Layout Helpers
    
    /// Calculate grid position for a given index
    private func positionFor(index: Int) -> CGPoint {
        let row = index / columns
        let col = index % columns
        return CGPoint(
            x: CGFloat(col) * (itemSize.width + spacing),
            y: CGFloat(row) * (itemSize.height + spacing)
        )
    }
    
    /// Calculate offset for an item (base position + drag offset if dragging)
    private func offsetFor(item: Item, at index: Int) -> CGSize {
        let basePosition = positionFor(index: index)
        
        if item.id == draggingItem {
            // Dragged item follows cursor
            return CGSize(
                width: basePosition.x + dragOffset.width,
                height: basePosition.y + dragOffset.height
            )
        } else {
            // Non-dragged items use their calculated position
            return CGSize(width: basePosition.x, height: basePosition.y)
        }
    }
    
    /// Calculate which index a position maps to (for determining drop target)
    private func indexFor(position: CGPoint) -> Int {
        let cellWidth = itemSize.width + spacing
        let cellHeight = itemSize.height + spacing
        
        // Calculate column and row (clamped to valid range)
        let col = max(0, min(columns - 1, Int((position.x + itemSize.width / 2) / cellWidth)))
        let row = max(0, Int((position.y + itemSize.height / 2) / cellHeight))
        
        let index = row * columns + col
        return max(0, min(items.count - 1, index))
    }
}

/// iOS-style persistent reorder mode modifier.
///
/// ## Behavior:
/// 1. Long-press any item → Enter persistent "edit mode" (all items jiggle)
/// 2. Simple drag (no long-press) to reorder items
/// 3. Click outside or press Escape to exit edit mode
///
/// ## Usage:
/// Parent view must provide `isEditModeActive` binding and handle exit via
/// background tap or keyboard commands.
struct ReorderableItemModifier<Item: Identifiable>: ViewModifier {
    let item: Item
    @Binding var items: [Item]
    @Binding var draggingItem: Item.ID?
    @Binding var isEditModeActive: Bool
    
    let columns: Int
    let itemSize: CGSize
    let spacing: CGFloat
    
    // MARK: - State
    
    /// Current drag offset
    @State private var dragOffset: CGSize = .zero
    
    /// Timestamp of last swap for debouncing
    @State private var lastSwapTime: Date = .distantPast
    
    /// Long-press detection for entering edit mode
    @GestureState private var isDetectingLongPress = false
    
    // MARK: - Constants
    
    private let swapDebounceInterval: TimeInterval = 0.15
    
    // MARK: - Computed Properties
    
    private var isDragging: Bool {
        draggingItem == item.id
    }
    
    private var cellWidth: CGFloat {
        itemSize.width + spacing
    }
    
    private var cellHeight: CGFloat {
        itemSize.height + spacing
    }
    
    private var longPressDuration: TimeInterval {
        UserDefaults.standard.preference(
            AppPreferenceKey.reorderLongPressDuration,
            default: PreferenceDefault.reorderLongPressDuration
        )
    }
    
    // MARK: - Body
    
    func body(content: Content) -> some View {
        content
            // Layer ordering
            .zIndex(isDragging ? 100 : 0)
            
            // Visual feedback
            .scaleEffect(isDragging ? 1.05 : (isDetectingLongPress ? 0.96 : 1.0))
            
            // Shadow when dragging
            .shadow(
                color: isDragging ? .black.opacity(0.25) : .clear,
                radius: isDragging ? 10 : 0,
                y: isDragging ? 5 : 0
            )
            
            // Offset for dragged item
            .offset(isDragging ? dragOffset : .zero)
            
            // Jiggle animation when in edit mode (but not the dragged item)
            .modifier(JiggleModifier(isJiggling: isEditModeActive && !isDragging))
            
            // Animations
            .animation(DroppyAnimation.bouncy, value: isDetectingLongPress)
            .animation(isDragging ? nil : DroppyAnimation.bouncy, value: isDragging)
            .animation(isDragging ? nil : DroppyAnimation.bouncy, value: items.map(\.id))
            
            // Gesture depends on mode
            .gesture(isEditModeActive ? dragGesture : nil)
            .highPriorityGesture(isEditModeActive ? nil : longPressToEnterEditMode)
            // Tap to exit edit mode (works on items since background is blocked by grid)
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if isEditModeActive {
                            withAnimation(DroppyAnimation.bouncy) {
                                isEditModeActive = false
                            }
                            DroppyState.shared.isReorderModeActive = false
                        }
                    }
            )
            
            // Cleanup on disappear
            .onDisappear {
                if isDragging { cleanupDrag() }
            }
            .onChange(of: items.count) { _, _ in
                if isDragging, !items.contains(where: { $0.id == item.id }) {
                    cleanupDrag()
                }
            }
            .onChange(of: isEditModeActive) { wasActive, isActive in
                if wasActive && !isActive {
                    // Mode deactivated - cleanup any drag state
                    cleanupDrag()
                    DroppyState.shared.isReorderModeActive = false
                }
            }
    }
    
    // MARK: - Gestures
    
    /// Long-press gesture to enter edit mode (used when NOT in edit mode)
    private var longPressToEnterEditMode: some Gesture {
        LongPressGesture(minimumDuration: longPressDuration)
            .updating($isDetectingLongPress) { current, state, _ in
                state = current
            }
            .onEnded { _ in
                withAnimation(DroppyAnimation.bouncy) {
                    isEditModeActive = true
                }
                DroppyState.shared.isReorderModeActive = true
                HapticFeedback.expand()
            }
    }
    
    /// Simple drag gesture for reordering (used when IN edit mode)
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if draggingItem == nil {
                    // Start dragging this item
                    draggingItem = item.id
                    HapticFeedback.tap()
                }
                
                if isDragging {
                    processDrag(translation: value.translation)
                }
            }
            .onEnded { _ in
                cleanupDrag()
            }
    }
    
    // MARK: - Drag Processing
    
    private func processDrag(translation: CGSize) {
        dragOffset = translation
        
        guard let currentIndex = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        let colOffset = translation.width / cellWidth
        let rowOffset = translation.height / cellHeight
        
        let currentRow = currentIndex / columns
        let currentCol = currentIndex % columns
        
        var targetIndex = currentIndex
        
        // Single-axis swap based on larger offset
        if abs(colOffset) >= 0.5 && abs(colOffset) >= abs(rowOffset) {
            if colOffset > 0 && currentCol < columns - 1 {
                targetIndex = currentIndex + 1
            } else if colOffset < 0 && currentCol > 0 {
                targetIndex = currentIndex - 1
            }
        } else if abs(rowOffset) >= 0.5 {
            let maxRow = (items.count - 1) / columns
            if rowOffset > 0 && currentRow < maxRow && currentIndex + columns < items.count {
                targetIndex = currentIndex + columns
            } else if rowOffset < 0 && currentRow > 0 {
                targetIndex = currentIndex - columns
            }
        }
        
        guard targetIndex != currentIndex else { return }
        guard targetIndex >= 0 && targetIndex < items.count else { return }
        
        let now = Date()
        guard now.timeIntervalSince(lastSwapTime) >= swapDebounceInterval else { return }
        lastSwapTime = now
        
        withAnimation(DroppyAnimation.bouncy) {
            items.move(
                fromOffsets: IndexSet(integer: currentIndex),
                toOffset: targetIndex > currentIndex ? targetIndex + 1 : targetIndex
            )
        }
        
        HapticFeedback.select()
    }
    
    private func cleanupDrag() {
        lastSwapTime = .distantPast
        withAnimation(DroppyAnimation.bouncy) {
            draggingItem = nil
            dragOffset = .zero
        }
    }
}

// MARK: - Jiggle Animation

/// Subtle jiggle animation for iOS-style edit mode indication
struct JiggleModifier: ViewModifier {
    let isJiggling: Bool
    
    // Use a timer to toggle the jiggle direction
    @State private var jiggleDirection: CGFloat = 1
    @State private var jiggleTimer: Timer?
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isJiggling ? jiggleDirection : 0))
            .animation(.easeInOut(duration: 0.1), value: jiggleDirection)
            .animation(.easeOut(duration: 0.1), value: isJiggling)
            .onChange(of: isJiggling) { _, newValue in
                if newValue {
                    startJiggle()
                } else {
                    stopJiggle()
                }
            }
            .onAppear {
                if isJiggling { startJiggle() }
            }
            .onDisappear {
                stopJiggle()
            }
    }
    
    private func startJiggle() {
        stopJiggle() // Clear any existing timer
        jiggleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                jiggleDirection = jiggleDirection > 0 ? -1 : 1
            }
        }
    }
    
    private func stopJiggle() {
        jiggleTimer?.invalidate()
        jiggleTimer = nil
        jiggleDirection = 0
    }
}

// MARK: - Comparable Clamping Extension

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension View {
    /// Make this item reorderable within an iOS-style persistent edit mode grid
    func reorderable<Item: Identifiable>(
        item: Item,
        in items: Binding<[Item]>,
        draggingItem: Binding<Item.ID?>,
        isEditModeActive: Binding<Bool>,
        columns: Int,
        itemSize: CGSize,
        spacing: CGFloat = 12
    ) -> some View {
        modifier(ReorderableItemModifier(
            item: item,
            items: items,
            draggingItem: draggingItem,
            isEditModeActive: isEditModeActive,
            columns: columns,
            itemSize: itemSize,
            spacing: spacing
        ))
    }
}

