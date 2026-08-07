import SwiftUI

private struct TicketPostAcquisitionDetailsPromptModifier: ViewModifier {
    @Binding var attempt: TicketAttempt?
    let onEdit: (TicketAttempt) -> Void
    let onLater: (TicketAttempt) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "金額・座席も入力しますか？",
            isPresented: Binding(
                get: { attempt != nil },
                set: { isPresented in
                    guard !isPresented, let pendingAttempt = attempt else { return }
                    attempt = nil
                    onLater(pendingAttempt)
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingAttempt = attempt {
                Button("金額・座席を入力") {
                    attempt = nil
                    onEdit(pendingAttempt)
                }
                Button("あとで", role: .cancel) {
                    attempt = nil
                    onLater(pendingAttempt)
                }
            }
        } message: {
            Text("任意です。チケット代、手数料、枚数、座席・整理番号を入力できます。")
        }
    }
}

extension View {
    func ticketPostAcquisitionDetailsPrompt(
        attempt: Binding<TicketAttempt?>,
        onEdit: @escaping (TicketAttempt) -> Void,
        onLater: @escaping (TicketAttempt) -> Void
    ) -> some View {
        modifier(
            TicketPostAcquisitionDetailsPromptModifier(
                attempt: attempt,
                onEdit: onEdit,
                onLater: onLater
            )
        )
    }
}
