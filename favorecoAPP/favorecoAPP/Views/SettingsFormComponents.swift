import SwiftUI

struct FavorecoSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Section {
            content
        } header: {
            FavorecoRegistrationSectionHeader(title)
        }
    }
}

struct FavorecoSettingsSectionWithFooter<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        _ title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        Section {
            content
        } header: {
            FavorecoRegistrationSectionHeader(title)
        } footer: {
            footer
                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
        }
    }
}

extension View {
    func favorecoSettingsListLayout() -> some View {
        self
            .environment(\.defaultMinListRowHeight, 54)
            .listSectionSpacing(24)
    }

    func favorecoSettingsRowLayout() -> some View {
        self
            .padding(.vertical, 5)
            .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}

struct FavorecoSettingsInfoCallout: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    let title: String
    let message: String
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            FavorecoIcon(systemName: "info.circle.fill", size: 12, fallbackWeight: .semibold)
                .foregroundStyle(themePalette.globalTint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FavorecoTypography.jpSans(compact ? 10 : 10.5, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(themePalette.globalTint)

                Text(message)
                    .font(FavorecoTypography.jpSans(compact ? 10.25 : 11, weight: .regular, relativeTo: .caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            themePalette.globalTint.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .listRowSeparator(.hidden)
    }
}

struct FavorecoSettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(.primary)

                if !detail.isEmpty {
                    Text(detail)
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 62)
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}

struct FavorecoSettingsSelectionRow: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    let title: String
    let detail: String
    let status: String
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button {
            guard !isLocked else { return }
            action()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                FavorecoIcon(
                    systemName: isSelected ? "checkmark.circle.fill" : "circle",
                    size: 20,
                    fallbackWeight: .regular
                )
                .foregroundStyle(isSelected ? themePalette.globalTint : .secondary)
                .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(title)
                            .font(FavorecoTypography.jpSans(16, weight: .semibold, relativeTo: .body))
                            .foregroundStyle(.primary)

                        Text(status)
                            .font(FavorecoTypography.jpSans(10.5, weight: .semibold, relativeTo: .caption))
                            .foregroundStyle(isLocked ? .secondary : themePalette.globalTint)
                    }

                    Text(detail)
                        .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
            .frame(minHeight: 62)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}
