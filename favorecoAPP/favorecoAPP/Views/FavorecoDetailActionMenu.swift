import SwiftUI

struct FavorecoDetailAction {
    let title: String
    let systemImage: String
    var isDestructive = false
    let action: () -> Void
}

struct FavorecoDetailActionMenuButton: View {
    @Binding var isPresented: Bool
    let genreColor: Color
    let accentColor: Color
    var size: CGFloat = 50
    var accessibilityLabel = "メニュー"

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.16)) {
                isPresented.toggle()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: size >= 44 ? 20 : 16, weight: .bold))
                // ジャンル色の円とアクセント色が近い場合も、操作記号を埋もれさせない。
                .foregroundStyle(Color(red: 0.98, green: 0.96, blue: 0.91))
                .frame(width: size, height: size)
                .background(genreColor.opacity(0.88), in: Circle())
                .overlay {
                    Circle().stroke(accentColor.opacity(0.72), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isPresented ? "展開中" : "閉じています")
    }
}

private struct FavorecoDetailActionPanel: View {
    @Binding var isPresented: Bool
    let genreColor: Color
    let accentColor: Color
    let actions: [FavorecoDetailAction]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Rectangle()
                        .fill(accentColor.opacity(0.20))
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.12)) {
                        isPresented = false
                    }
                    item.action()
                } label: {
                    FavorecoIconLabel(item.title, systemImage: item.systemImage, iconSize: 17)
                        .font(FavorecoTypography.bodyStrong)
                        .foregroundStyle(
                            item.isDestructive
                                ? Color(red: 0.96, green: 0.45, blue: 0.45)
                                : Color(red: 0.96, green: 0.93, blue: 0.88)
                        )
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 250)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.96))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [genreColor.opacity(0.58), genreColor.opacity(0.14), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accentColor.opacity(0.78), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.52), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }
}

private struct FavorecoDetailActionMenuModifier: ViewModifier {
    @Binding var isPresented: Bool
    let genreColor: Color
    let accentColor: Color
    let topPadding: CGFloat
    let trailingPadding: CGFloat
    let actions: [FavorecoDetailAction]

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if isPresented {
                ZStack(alignment: .topTrailing) {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.12)) {
                                isPresented = false
                            }
                        }

                    FavorecoDetailActionPanel(
                        isPresented: $isPresented,
                        genreColor: genreColor,
                        accentColor: accentColor,
                        actions: actions
                    )
                    .padding(.top, topPadding)
                    .padding(.trailing, trailingPadding)
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: 0.94, anchor: .topTrailing)
                        )
                    )
                }
                .zIndex(100)
                .accessibilityAction(.escape) {
                    isPresented = false
                }
            }
        }
    }
}

extension View {
    func favorecoDetailActionMenu(
        isPresented: Binding<Bool>,
        genreColor: Color,
        accentColor: Color,
        topPadding: CGFloat,
        trailingPadding: CGFloat = 20,
        actions: [FavorecoDetailAction]
    ) -> some View {
        modifier(
            FavorecoDetailActionMenuModifier(
                isPresented: isPresented,
                genreColor: genreColor,
                accentColor: accentColor,
                topPadding: topPadding,
                trailingPadding: trailingPadding,
                actions: actions
            )
        )
    }
}
