import SwiftUI
import UIKit

private extension Notification.Name {
    static let favorecoInteractionFeedback = Notification.Name(
        "com.nori.favoreco.interactionFeedback"
    )
}

@MainActor
enum FavorecoInteractionFeedbackCenter {
    private static let messageKey = "message"

    static func show(message: String) {
        NotificationCenter.default.post(
            name: .favorecoInteractionFeedback,
            object: nil,
            userInfo: [messageKey: message]
        )
    }

    static func showSaveCompleted() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        show(message: "保存しました")
    }

    static func notifyValidationFailure() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func notifySelectionChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    fileprivate static func message(from notification: Notification) -> String? {
        notification.userInfo?[messageKey] as? String
    }
}

@MainActor
enum FavorecoKeyboardNavigation {
    static func moveToPreviousField() {
        moveFocus(by: -1)
    }

    static func moveToNextField() {
        moveFocus(by: 1)
    }

    static func dismissKeyboard() {
        keyWindow?.endEditing(true)
    }

    private static func moveFocus(by offset: Int) {
        guard let window = keyWindow else { return }
        let responders = editableResponders(in: window)
            .sorted { lhs, rhs in
                let lhsFrame = lhs.convert(lhs.bounds, to: window)
                let rhsFrame = rhs.convert(rhs.bounds, to: window)
                if abs(lhsFrame.minY - rhsFrame.minY) > 4 {
                    return lhsFrame.minY < rhsFrame.minY
                }
                return lhsFrame.minX < rhsFrame.minX
            }
        guard let currentIndex = responders.firstIndex(where: \.isFirstResponder) else { return }
        let destinationIndex = currentIndex + offset
        guard responders.indices.contains(destinationIndex) else {
            if offset > 0 {
                dismissKeyboard()
            }
            return
        }
        responders[destinationIndex].becomeFirstResponder()
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func editableResponders(in view: UIView) -> [UIView] {
        let current: [UIView]
        if let textField = view as? UITextField,
           textField.isEnabled,
           textField.isUserInteractionEnabled,
           !textField.isHidden,
           textField.alpha > 0.01 {
            current = [textField]
        } else if let textView = view as? UITextView,
                  textView.isEditable,
                  textView.isUserInteractionEnabled,
                  !textView.isHidden,
                  textView.alpha > 0.01 {
            current = [textView]
        } else {
            current = []
        }
        return current + view.subviews.flatMap(editableResponders(in:))
    }
}

private struct FavorecoInteractionFeedbackItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

private struct FavorecoInteractionFeedbackOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.favorecoThemePalette) private var themePalette
    @State private var item: FavorecoInteractionFeedbackItem?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let item {
                    Label(item.message, systemImage: "checkmark.circle.fill")
                        .font(FavorecoTypography.jpSans(14, weight: .semibold, relativeTo: .body))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .background(
                            themePalette.globalTint.opacity(0.96),
                            in: Capsule()
                        )
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                        .padding(.top, 14)
                        .padding(.horizontal, 20)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity)
                        )
                        .zIndex(1_000)
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .favorecoInteractionFeedback)) {
                guard let message = FavorecoInteractionFeedbackCenter.message(from: $0) else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    item = FavorecoInteractionFeedbackItem(message: message)
                }
            }
            .task(id: item?.id) {
                guard let currentItem = item else { return }
                try? await Task.sleep(for: .seconds(1.8))
                guard !Task.isCancelled, item?.id == currentItem.id else { return }
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.16)) {
                    item = nil
                }
            }
    }
}

extension View {
    func favorecoInteractionFeedbackOverlay() -> some View {
        modifier(FavorecoInteractionFeedbackOverlay())
    }
}
