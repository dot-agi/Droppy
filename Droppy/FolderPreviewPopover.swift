//
//  FolderPreviewPopover.swift
//  Droppy
//
//  Shows a preview of folder contents when hovering over a pinned folder.
//  Uses a delay to avoid interfering with drag-and-drop operations.
//

import SwiftUI

/// Popover that shows the contents of a folder
/// Uses fixed height to prevent NSPopover animation crashes
struct FolderPreviewPopover: View {
    let folderURL: URL
    let isPinned: Bool
    @Binding var isHovering: Bool
    let maxItems: Int = 8
    
    // Pre-loaded content to avoid dynamic layout during popover animation
    private let contents: [(name: String, icon: NSImage, isDirectory: Bool)]
    private let totalCount: Int
    
    init(folderURL: URL, isPinned: Bool = false, isHovering: Binding<Bool> = .constant(false)) {
        self.folderURL = folderURL
        self.isPinned = isPinned
        self._isHovering = isHovering
        
        // Load contents synchronously during init to avoid layout changes
        let fm = FileManager.default
        if let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            self.totalCount = urls.count
            
            // Sort: folders first, then by name
            let sorted = urls.sorted { url1, url2 in
                let isDir1 = (try? url1.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let isDir2 = (try? url2.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir1 != isDir2 { return isDir1 }
                return url1.lastPathComponent.localizedCaseInsensitiveCompare(url2.lastPathComponent) == .orderedAscending
            }
            
            self.contents = Array(sorted.prefix(maxItems).map { url in
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                return (name: url.lastPathComponent, icon: icon, isDirectory: isDir)
            })
        } else {
            self.contents = []
            self.totalCount = 0
        }
    }
    
    @State private var hoveredItem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .foregroundColor(isPinned ? .orange : .blue)
                    .font(.system(size: 14))
                Text(folderURL.lastPathComponent)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            if contents.isEmpty {
                Text("Empty folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                // File list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(contents.prefix(maxItems), id: \.name) { item in
                            HStack(spacing: 8) {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                
                                Text(item.name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if item.isDirectory {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(hoveredItem == item.name ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .contentShape(Rectangle())
                            .onHover { isHovering in
                                hoveredItem = isHovering ? item.name : nil
                            }
                            .onTapGesture(count: 2) {
                                // Double click: Open file
                                let fileURL = folderURL.appendingPathComponent(item.name)
                                NSWorkspace.shared.open(fileURL)
                            }
                            .onTapGesture {
                                // Single click: Select (for now just highlight/preview)
                                // In a real finder usage this would select.
                                // For basic interactivity, maybe just preview?
                                // User asked for spacebar preview - this usually requires focus.
                                // For now, we enable opening.
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                }
                .scrollDisabled(true) // We limit items anyway
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Footer: Open Folder button
            Button {
                NSWorkspace.shared.open(folderURL)
            } label: {
                HStack(spacing: 4) {
                    Text("Open Folder")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 10))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        .frame(width: 200)
        .background(
            // Use standard material background
            Material.regular
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    FolderPreviewPopover(folderURL: URL(fileURLWithPath: NSHomeDirectory()), isPinned: true)
        .padding()
        .background(Color.black)
}
