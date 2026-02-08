import SwiftUI
import Darwin

struct LicenseSettingsSection: View {
    @ObservedObject private var licenseManager = LicenseManager.shared

    @State private var emailInput: String = ""
    @State private var licenseKeyInput: String = ""
    @State private var showConfetti = false
    @State private var isLicenseKeyVisible = true

    @FocusState private var focusedField: FocusedField?

    private enum FocusedField {
        case email
        case key
    }

    var body: some View {
        Group {
            if licenseManager.requiresLicenseEnforcement {
                if licenseManager.isActivated {
                    Section {
                        activeLicenseCard
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .overlay {
                                if showConfetti {
                                    OnboardingConfettiView()
                                        .allowsHitTesting(false)
                                        .transition(.opacity)
                                }
                            }

                        activatedDeviceCard
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0))
                    } header: {
                        Text("License")
                    }
                } else {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            headerRow
                            activationCard
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                        .overlay {
                            if showConfetti {
                                OnboardingConfettiView()
                                    .allowsHitTesting(false)
                                    .transition(.opacity)
                            }
                        }
                    } header: {
                        Text("License")
                    } footer: {
                        Text("Droppy verifies this key with Gumroad so your license follows Gumroad seat limits.")
                    }
                }
            }
        }
        .onAppear {
            if emailInput.isEmpty {
                emailInput = licenseManager.licensedEmail
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill((licenseManager.isActivated ? Color.green : Color.orange).opacity(0.2))
                    .frame(width: 26, height: 26)

                Image(systemName: licenseManager.isActivated ? "checkmark.seal.fill" : "key.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(licenseManager.isActivated ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(licenseManager.isActivated ? "Licensed" : "Activation Required")
                    .font(.system(size: 13, weight: .semibold))
                Text(licenseManager.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if licenseManager.isChecking {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var activeLicenseCard: some View {
        LicenseIdentityCard(
            title: "Droppy License",
            subtitle: "Activated on this Mac",
            email: licenseManager.licensedEmail,
            deviceName: licenseManager.activatedDeviceName,
            keyHint: normalized(licenseManager.licenseKeyHint),
            verifiedAt: licenseManager.lastVerifiedAt,
            accentColor: .blue,
            footer: nil,
            enableInteractiveEffects: false
        )
    }

    private var licenseActionRow: some View {
        HStack(spacing: 8) {
            Text("Manage")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button {
                Task {
                    await licenseManager.revalidateStoredLicense()
                }
            } label: {
                HStack(spacing: 5) {
                    if licenseManager.isChecking {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    Text("Re-check")
                }
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            .disabled(licenseManager.isChecking)

            Button {
                Task {
                    await licenseManager.deactivateCurrentDevice()
                    licenseKeyInput = ""
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Remove")
                }
            }
            .buttonStyle(DroppyPillButtonStyle(size: .small))
            .disabled(licenseManager.isChecking)
        }
    }

    private var activationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activate this Mac")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            inputField(icon: "envelope.fill", isFocused: focusedField == .email) {
                TextField("Purchase email (optional)", text: $emailInput)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .email)
            }

            inputField(icon: "key.fill", isFocused: focusedField == .key) {
                HStack(spacing: 8) {
                    if isLicenseKeyVisible {
                        TextField("Gumroad license key", text: $licenseKeyInput)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .key)
                    } else {
                        SecureField("Gumroad license key", text: $licenseKeyInput)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .key)
                    }

                    Button {
                        isLicenseKeyVisible.toggle()
                    } label: {
                        Image(systemName: isLicenseKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isLicenseKeyVisible ? "Hide license key" : "Show license key")
                }
            }

            HStack(spacing: 8) {
                if let purchaseURL = licenseManager.purchaseURL {
                    Link(destination: purchaseURL) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right")
                            Text("Buy License")
                        }
                    }
                    .buttonStyle(DroppyPillButtonStyle(size: .small))
                }

                Spacer()

                Button {
                    activateLicense()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                        Text("Activate")
                    }
                }
                .buttonStyle(DroppyAccentButtonStyle(color: .blue, size: .small))
                .disabled(licenseManager.isChecking)
            }
        }
        .padding(14)
        .background(AdaptiveColors.overlayAuto(0.03))
        .clipShape(RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.large, style: .continuous)
                .stroke(AdaptiveColors.overlayAuto(0.08), lineWidth: 1)
        )
    }

    private var activatedDeviceCard: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activated Device")
                Text("\(displayDeviceName) • \(localMacFriendlyModel) • \(localMacOSVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 8) {
                SettingsSegmentButtonWithContent(
                    label: "This Mac",
                    isSelected: true,
                    tileWidth: 106,
                    tileHeight: 46,
                    action: {}
                ) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.blue)
                }
                .allowsHitTesting(false)
                .fixedSize(horizontal: true, vertical: false)

                SettingsSegmentButtonWithContent(
                    label: "Re-check",
                    isSelected: false,
                    tileWidth: 96,
                    tileHeight: 46,
                    action: {
                        Task {
                            await licenseManager.revalidateStoredLicense()
                        }
                    }
                ) {
                    if licenseManager.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                    }
                }
                .disabled(licenseManager.isChecking)
                .fixedSize(horizontal: true, vertical: false)

                SettingsSegmentButtonWithContent(
                    label: "Remove",
                    isSelected: false,
                    tileWidth: 96,
                    tileHeight: 46,
                    action: {
                        Task {
                            await licenseManager.deactivateCurrentDevice()
                            licenseKeyInput = ""
                        }
                    }
                ) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.secondaryTextAuto)
                }
                .disabled(licenseManager.isChecking)
                .fixedSize(horizontal: true, vertical: false)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func activateLicense() {
        let key = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let success = await licenseManager.activate(licenseKey: key, email: emailInput)
            guard success else { return }

            withAnimation(DroppyAnimation.state) {
                showConfetti = true
                licenseKeyInput = ""
                emailInput = licenseManager.licensedEmail
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(DroppyAnimation.hoverQuick) {
                    showConfetti = false
                }
            }
        }
    }

    private func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not available" : trimmed
    }

    private var displayDeviceName: String {
        let trimmed = licenseManager.activatedDeviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let hostName = Host.current().localizedName, !hostName.isEmpty {
            return hostName
        }
        return "This Mac"
    }

    private var localMacOSVersion: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    private var localMacFriendlyModel: String {
        let identifier = localMacModelIdentifier
        let chip = localChipName
        let modelName = mappedMacModelName(for: identifier) ?? fallbackMacFamilyName(from: identifier) ?? identifier
        return "\(modelName) (\(chip))"
    }

    private var localChipName: String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else {
            return "Apple Silicon"
        }

        var cpu = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &cpu, &size, nil, 0) == 0 else {
            return "Apple Silicon"
        }

        let value = String(cString: cpu).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Apple Silicon" : value
    }

    private var localMacModelIdentifier: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "Mac"
        }

        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &model, &size, nil, 0) == 0 else {
            return "Mac"
        }
        return String(cString: model)
    }

    private func mappedMacModelName(for identifier: String) -> String? {
        let known: [String: String] = [
            "MacBookPro17,1": "MacBook Pro 13-inch",
            "MacBookPro18,1": "MacBook Pro 16-inch",
            "MacBookPro18,2": "MacBook Pro 16-inch",
            "MacBookPro18,3": "MacBook Pro 14-inch",
            "MacBookPro18,4": "MacBook Pro 14-inch",
            "MacBookPro19,1": "MacBook Pro 14-inch",
            "MacBookPro19,2": "MacBook Pro 16-inch",
            "MacBookPro20,1": "MacBook Pro 13-inch",
            "MacBookPro20,2": "MacBook Pro 13-inch",
            "MacBookPro21,1": "MacBook Pro 14-inch",
            "MacBookPro21,2": "MacBook Pro 16-inch",
            "MacBookPro21,3": "MacBook Pro 14-inch",
            "MacBookPro21,4": "MacBook Pro 16-inch",
        ]
        return known[identifier]
    }

    private func fallbackMacFamilyName(from identifier: String) -> String? {
        if identifier.hasPrefix("MacBookPro") { return "MacBook Pro" }
        if identifier.hasPrefix("MacBookAir") { return "MacBook Air" }
        if identifier.hasPrefix("MacBook") { return "MacBook" }
        if identifier.hasPrefix("Macmini") { return "Mac mini" }
        if identifier.hasPrefix("MacStudio") { return "Mac Studio" }
        if identifier.hasPrefix("MacPro") { return "Mac Pro" }
        if identifier.hasPrefix("iMacPro") { return "iMac Pro" }
        if identifier.hasPrefix("iMac") { return "iMac" }
        return nil
    }

    private func inputField<Content: View>(icon: String, isFocused: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue.opacity(0.92))
                .frame(width: 16)

            content()
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .disableAutocorrection(true)
        }
        .droppyTextInputChrome(cornerRadius: DroppyRadius.ml, horizontalPadding: 12, verticalPadding: 10)
        .overlay(
            RoundedRectangle(cornerRadius: DroppyRadius.ml, style: .continuous)
                .stroke(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.2)
        )
    }
}
