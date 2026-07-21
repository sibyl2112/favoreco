import Foundation

enum ExperienceExpenseCalculator {
    private static let securedTicketStatusKeys: Set<String> = [
        "won", "waitingPayment", "waitingIssue", "issued", "attended",
    ]

    static func securedTicketAmount(for plan: Plan?) -> Decimal {
        (plan?.ticketAttempts ?? [])
            .filter { !$0.isArchived && securedTicketStatusKeys.contains($0.statusKey) }
            .reduce(Decimal(0)) { partial, attempt in
                partial + max(
                    (attempt.price + attempt.fee) * Decimal(max(attempt.quantity, 1)),
                    Decimal(0)
                )
            }
    }

    static func photoAmount(for visit: Visit?, purpose: ExperiencePhotoPurpose) -> Decimal {
        (visit?.photos ?? [])
            .filter { ExperiencePhotoPurpose.resolved(from: $0.purpose) == purpose }
            .reduce(Decimal(0)) { $0 + max($1.amount, Decimal(0)) }
    }

    static func travelAmount(for plan: Plan?) -> Decimal {
        (plan?.preparationFields.tasks ?? [])
            .filter { $0.kind.isTravel }
            .reduce(Decimal(0)) { $0 + max($1.amount, Decimal(0)) }
    }
}
