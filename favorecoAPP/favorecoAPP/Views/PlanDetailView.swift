//
//  PlanDetailView.swift
//  favorecoAPP
//
//  Created by Codex on 2026/07/10.
//

import SwiftUI

struct PlanDetailView: View {
    let plan: Plan

    private var categoryColor: Color {
        Color(hex: plan.category?.colorHex ?? "#147C88")
    }

    private var attempts: [TicketAttempt] {
        (plan.ticketAttempts ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var dateRangeText: String {
        if Calendar.current.isDate(plan.startsAt, inSameDayAs: plan.endsAt) {
            return "\(plan.startsAt.formatted(date: .long, time: .shortened)) - \(plan.endsAt.formatted(date: .omitted, time: .shortened))"
        }
        return "\(plan.startsAt.formatted(date: .long, time: .shortened)) - \(plan.endsAt.formatted(date: .long, time: .shortened))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                basicSection
                ticketSection
                officialSection
                memoSection
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("予定・チケット")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: plan.category?.iconSymbol ?? "ticket")
                    .font(.title3)
                    .foregroundStyle(categoryColor)
                    .frame(width: 38, height: 38)
                    .background(categoryColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.category?.name ?? "予定")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(categoryColor)
                    Text(TicketStatusDefinition.name(for: attempts.first?.statusKey ?? plan.stateKey))
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(plan.title.isEmpty ? "予定" : plan.title)
                .font(FavorecoTypography.heroLead)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !plan.subtitle.isEmpty {
                Text(plan.subtitle)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
        .planSectionCard()
    }

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            planSectionTitle("基本情報")
            PlanInfoRow(icon: "calendar", title: "日時", value: dateRangeText)
            if plan.opensAt != Date.distantPast {
                PlanInfoRow(icon: "door.left.hand.open", title: "開場", value: plan.opensAt.formatted(date: .omitted, time: .shortened))
            }
            if !plan.venueNameSnapshot.isEmpty {
                PlanInfoRow(icon: "mappin.and.ellipse", title: "会場", value: plan.venueNameSnapshot)
            }
            if !plan.organizerNameSnapshot.isEmpty {
                PlanInfoRow(icon: "building.2", title: "主催", value: plan.organizerNameSnapshot)
            }
        }
        .planSectionCard()
    }

    @ViewBuilder
    private var ticketSection: some View {
        if attempts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("チケット")
                Text("チケット申込はまだ登録されていません。")
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
            }
            .planSectionCard()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("チケット")
                ForEach(attempts) { attempt in
                    TicketAttemptDetailCard(attempt: attempt, accentColor: categoryColor)
                }
            }
            .planSectionCard()
        }
    }

    @ViewBuilder
    private var officialSection: some View {
        if !plan.officialURL.isEmpty || !plan.sourceURL.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("公式情報")
                if let officialURL = URL(string: plan.officialURL), !plan.officialURL.isEmpty {
                    Link(destination: officialURL) {
                        PlanInfoRow(icon: "safari", title: "公式", value: plan.officialURL)
                    }
                    .buttonStyle(.plain)
                }
                if let sourceURL = URL(string: plan.sourceURL), !plan.sourceURL.isEmpty {
                    Link(destination: sourceURL) {
                        PlanInfoRow(icon: "link", title: "参考", value: plan.sourceURL)
                    }
                    .buttonStyle(.plain)
                }
            }
            .planSectionCard()
        }
    }

    @ViewBuilder
    private var memoSection: some View {
        if !plan.memo.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                planSectionTitle("メモ")
                Text(plan.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .planSectionCard()
        }
    }

    private func planSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(FavorecoTypography.sectionTitle)
            .foregroundStyle(.primary)
    }
}

private struct TicketAttemptDetailCard: View {
    let attempt: TicketAttempt
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(TicketStatusDefinition.name(for: attempt.statusKey))
                    .font(FavorecoTypography.bodyStrong)
                    .foregroundStyle(.primary)
                Spacer(minLength: 10)
                if !attempt.entryRouteKey.isEmpty {
                    Text(TicketEntryRouteDefinition.name(for: attempt.entryRouteKey))
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
            }

            if let accountName {
                PlanInfoRow(icon: "person.crop.circle", title: "名義", value: accountName)
            }
            if attempt.saleStartAt != Date.distantPast {
                PlanInfoRow(icon: "ticket", title: "開始", value: attempt.saleStartAt.formatted(date: .long, time: .shortened))
            }
            if attempt.applyDeadlineAt != Date.distantPast {
                PlanInfoRow(icon: "hourglass", title: "締切", value: attempt.applyDeadlineAt.formatted(date: .long, time: .shortened))
            }
            if attempt.resultAnnounceAt != Date.distantPast {
                PlanInfoRow(icon: "checkmark.seal", title: "当落", value: attempt.resultAnnounceAt.formatted(date: .long, time: .shortened))
            }
            if attempt.paymentDeadlineAt != Date.distantPast {
                PlanInfoRow(icon: "yensign.circle", title: "入金", value: attempt.paymentDeadlineAt.formatted(date: .long, time: .shortened))
            }
            if attempt.issueStartAt != Date.distantPast {
                PlanInfoRow(icon: "ticket.fill", title: "発券", value: attempt.issueStartAt.formatted(date: .long, time: .shortened))
            }
            if attempt.price != Decimal(0) || attempt.fee != Decimal(0) {
                PlanInfoRow(icon: "creditcard", title: "金額", value: amountText)
            }
            if !attempt.seatText.isEmpty {
                PlanInfoRow(icon: "chair", title: "座席", value: attempt.seatText)
            }
            if let purchaseURL = URL(string: attempt.purchaseURL), !attempt.purchaseURL.isEmpty {
                Link(destination: purchaseURL) {
                    PlanInfoRow(icon: "safari", title: "購入", value: attempt.purchaseURL)
                }
                .buttonStyle(.plain)
            }
            if !attempt.memo.isEmpty {
                Text(attempt.memo)
                    .font(FavorecoTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var accountName: String? {
        if !attempt.holderName.isEmpty {
            return attempt.holderName
        }
        if let account = attempt.account {
            if !account.accountName.isEmpty {
                return account.accountName
            }
            if !account.serviceName.isEmpty {
                return account.serviceName
            }
        }
        return nil
    }

    private var amountText: String {
        let total = (attempt.price + attempt.fee) * Decimal(attempt.quantity)
        let number = NSDecimalNumber(decimal: total)
        return NumberFormatter.planCurrency.string(from: number) ?? "¥\(number.intValue)"
    }
}

private struct PlanInfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            Text(title)
                .font(FavorecoTypography.body)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            Text(value)
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
        }
    }
}

private extension NumberFormatter {
    static let planCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private extension View {
    func planSectionCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
