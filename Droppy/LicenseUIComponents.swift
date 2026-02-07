import SwiftUI

// MARK: - Shimmer Effect

private struct ShimmerOverlay: View {
    let cornerRadius: CGFloat
    @State private var phase: CGFloat = -1.0

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear, location: max(0, phase - 0.15)),
                    .init(color: .white.opacity(0.08), location: phase),
                    .init(color: .clear, location: min(1, phase + 0.15))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: width * 2.4)
            .offset(x: -width * 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: false)) {
                phase = 2.0
            }
        }
    }
}

// MARK: - Live Preview Card (Activation Window — pre-activation)

struct LicenseLivePreviewCard: View {
    let email: String
    let keyDisplay: String
    let isActivated: Bool
    var accentColor: Color = .blue
    var enableInteractiveEffects: Bool = true

    @State private var isHovering = false

    var body: some View {
        let hoverActive = enableInteractiveEffects && isHovering

        VStack(alignment: .leading, spacing: 14) {
            // Top row: brand + status badge
            HStack(spacing: 8) {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))

                Text("DROPPY LICENSE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.88))

                Spacer(minLength: 8)

                Text(isActivated ? "ACTIVE" : "PENDING")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isActivated
                                  ? Color.green.opacity(0.35)
                                  : Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule()
                            .stroke(isActivated
                                    ? Color.green.opacity(0.5)
                                    : Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                    .foregroundStyle(isActivated ? .green : .white.opacity(0.85))
            }

            // License key
            Text(keyDisplay)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .truncationMode(.middle)

            // Email row
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Text(nonEmpty(email) ?? "you@yourmail.com")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(hoverActive ? 0.35 : 0.22),
                            Color.white.opacity(hoverActive ? 0.12 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(ShimmerOverlay(cornerRadius: DroppyRadius.large))
        .shadow(color: accentColor.opacity(hoverActive ? 0.38 : 0.24), radius: hoverActive ? 18 : 12, y: hoverActive ? 8 : 5)
        .scaleEffect(hoverActive ? 1.012 : 1.0)
        .parallax3D(magnitude: 12, enableOverride: true, suspended: !enableInteractiveEffects)
        .onHover { hovering in
            guard enableInteractiveEffects else { return }
            withAnimation(DroppyAnimation.hover) {
                isHovering = hovering
            }
        }
    }

    private var cardBackground: some View {
        ZStack {
            // Base deep gradient
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.68),
                            accentColor.opacity(0.38),
                            Color(white: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Top-left highlight for depth
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.14), Color.clear, Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner edge glow
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.18), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Identity Card (Activated state — settings & activation window)

struct LicenseIdentityCard: View {
    let title: String
    let subtitle: String
    let email: String
    let keyHint: String?
    let verifiedAt: Date?
    var accentColor: Color = .blue
    let footer: AnyView?
    var enableInteractiveEffects: Bool

    @State private var isHovering = false

    init(
        title: String,
        subtitle: String,
        email: String,
        keyHint: String?,
        verifiedAt: Date?,
        accentColor: Color = .blue,
        footer: AnyView? = nil,
        enableInteractiveEffects: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.email = email
        self.keyHint = keyHint
        self.verifiedAt = verifiedAt
        self.accentColor = accentColor
        self.footer = footer
        self.enableInteractiveEffects = enableInteractiveEffects
    }

    var body: some View {
        let hoverActive = enableInteractiveEffects && isHovering

        VStack(alignment: .leading, spacing: 12) {
            // Header: verified badge + title + key icon
            HStack(alignment: .center, spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.9), accentColor.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            RoundedRectangle(cornerRadius: DroppyRadius.medium, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Subtle "PRO" badge instead of bare key icon
                Text("PRO")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(accentColor.opacity(0.3), lineWidth: 0.5)
                    )
            }

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 1)

            // Meta rows
            VStack(alignment: .leading, spacing: 7) {
                licenseMetaRow(
                    icon: "envelope.fill",
                    label: "Email",
                    value: nonEmpty(email) ?? "Not provided"
                )

                if let keyHint = nonEmpty(keyHint) {
                    licenseMetaRow(
                        icon: "key.fill",
                        label: "Key",
                        value: keyHint
                    )
                }

                if let verifiedAt {
                    licenseMetaRow(
                        icon: "checkmark.shield.fill",
                        label: "Verified",
                        value: verifiedAt.formatted(date: .abbreviated, time: .shortened),
                        trailing: footer
                    )
                } else if let footer {
                    HStack {
                        Spacer(minLength: 0)
                        footer
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(hoverActive ? 0.26 : 0.14),
                            Color.white.opacity(hoverActive ? 0.08 : 0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(ShimmerOverlay(cornerRadius: DroppyRadius.large))
        .shadow(color: accentColor.opacity(hoverActive ? 0.32 : 0.18), radius: hoverActive ? 18 : 12, y: hoverActive ? 8 : 5)
        .scaleEffect(hoverActive ? 1.012 : 1.0)
        .parallax3D(magnitude: 12, enableOverride: true, suspended: !enableInteractiveEffects)
        .onHover { hovering in
            guard enableInteractiveEffects else { return }
            withAnimation(DroppyAnimation.hover) {
                isHovering = hovering
            }
        }
    }

    private var cardBackground: some View {
        ZStack {
            // Deep base gradient
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(0.22),
                            accentColor.opacity(0.10),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner radial glow
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [accentColor.opacity(0.10), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
        }
    }

    private func licenseMetaRow(
        icon: String,
        label: String,
        value: String,
        trailing: AnyView? = nil
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(accentColor.opacity(0.85))
                .frame(width: 14)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.8))
                .frame(width: 50, alignment: .leading)

            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary.opacity(0.88))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing {
                trailing
            }
        }
        .frame(minHeight: 20, alignment: .center)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
