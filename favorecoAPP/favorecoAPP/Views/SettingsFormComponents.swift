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
            settingsCardRows(content)
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
            settingsCardRows(content)
        } header: {
            FavorecoRegistrationSectionHeader(title)
        } footer: {
            footer
                .font(FavorecoTypography.jpSans(11, weight: .regular, relativeTo: .caption))
        }
    }
}

/// A headerless settings card for status, warning, preview, and action rows.
/// It deliberately uses the same row treatment as named settings sections.
struct FavorecoSettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Section {
            settingsCardRows(content)
        }
    }
}

/// Settings rows use the native symbol treatment of the Master Data row as
/// their optical baseline. Keeping this separate from the app-wide icon font
/// prevents mixed fallback symbols from changing size or stroke weight.
struct FavorecoSettingsRowIcon: View {
    @Environment(\.favorecoThemePalette) private var themePalette

    let systemImage: String
    var color: Color? = nil

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color ?? themePalette.globalTint)
            .frame(width: 30, height: 24, alignment: .center)
            .accessibilityHidden(true)
    }
}

struct FavorecoSettingsIconLabel: View {
    let title: String
    let systemImage: String
    var color: Color? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            FavorecoSettingsRowIcon(systemImage: systemImage, color: color)

            Text(title)
                .foregroundStyle(color ?? .primary)
                .frame(minHeight: 24, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

@ViewBuilder
private func settingsCardRows<Content: View>(_ content: Content) -> some View {
    Group(subviews: content) { subviews in
        ForEach(subviews.indices, id: \.self) { index in
            let isFirst = index == subviews.startIndex
            let isLast = index == subviews.index(before: subviews.endIndex)
            subviews[index]
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                .listRowBackground(
                    FavorecoSettingsCardRowBackground(isFirst: isFirst, isLast: isLast)
                )
                .listRowSeparator(.hidden)
        }
    }
}

private struct FavorecoSettingsCardRowBackground: View {
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: isFirst ? 8 : 0,
            bottomLeadingRadius: isLast ? 8 : 0,
            bottomTrailingRadius: isLast ? 8 : 0,
            topTrailingRadius: isFirst ? 8 : 0,
            style: .continuous
        )
        .fill(TheaterLifecycleFlatStyle.fieldBackground)
        .overlay {
            GeometryReader { proxy in
                ZStack {
                    settingsCardBorder(in: proxy.size)
                        .stroke(Color.secondary.opacity(0.20), lineWidth: 1)

                    if !isLast {
                        settingsCardSeparator(in: proxy.size)
                            .stroke(ExplicitFormMetrics.rowSeparatorColor, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func settingsCardBorder(in size: CGSize) -> Path {
        let radius: CGFloat = 8
        var path = Path()

        if isFirst {
            path.move(to: CGPoint(x: 0, y: radius))
            path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
            path.addLine(to: CGPoint(x: size.width - radius, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: size.width, y: radius),
                control: CGPoint(x: size.width, y: 0)
            )
        }

        path.move(to: CGPoint(x: 0, y: isFirst ? radius : 0))
        path.addLine(to: CGPoint(x: 0, y: size.height - (isLast ? radius : 0)))
        path.move(to: CGPoint(x: size.width, y: isFirst ? radius : 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height - (isLast ? radius : 0)))

        if isLast {
            path.move(to: CGPoint(x: 0, y: size.height - radius))
            path.addQuadCurve(
                to: CGPoint(x: radius, y: size.height),
                control: CGPoint(x: 0, y: size.height)
            )
            path.addLine(to: CGPoint(x: size.width - radius, y: size.height))
            path.addQuadCurve(
                to: CGPoint(x: size.width, y: size.height - radius),
                control: CGPoint(x: size.width, y: size.height)
            )
        }
        return path
    }

    private func settingsCardSeparator(in size: CGSize) -> Path {
        var path = Path()
        let y = max(0, size.height - 0.5)
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        return path
    }
}

extension View {
    func favorecoSettingsListLayout() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(TheaterLifecycleFlatStyle.canvasBackground.ignoresSafeArea())
            .environment(\.defaultMinListRowHeight, 52)
            .listSectionSpacing(18)
            .contentMargins(.top, 12, for: .scrollContent)
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
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(themePalette.globalTint.opacity(0.14), lineWidth: 1)
        }
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
        .padding(.vertical, 5)
        .frame(minHeight: 54)
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
            .padding(.vertical, 5)
            .frame(minHeight: 54)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .listRowSeparatorTint(ExplicitFormMetrics.rowSeparatorColor)
    }
}
