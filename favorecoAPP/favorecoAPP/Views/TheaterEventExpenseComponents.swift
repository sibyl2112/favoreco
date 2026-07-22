import SwiftUI

struct TheaterEventExpenseSection: View {
    let snapshot: TheaterEventExpenseSnapshot
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("金額総計")
                        .font(FavorecoTypography.sectionTitle)
                    Text("観劇記録\(snapshot.visitCount)件・予定\(snapshot.planCount)件")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(currencyText(snapshot.total))
                    .font(FavorecoTypography.heroLead)
                    .foregroundStyle(accentColor)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
            }

            if snapshot.total == 0 {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "yensign.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    Text("チケット、グッズ、遠征費を登録すると、この作品・公演全体の金額がまとまります。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    if snapshot.ticketAmount > 0 {
                        expenseTile(
                            title: "チケット",
                            amount: snapshot.ticketAmount,
                            systemImage: "ticket"
                        )
                    }
                    if snapshot.goodsAmount > 0 {
                        expenseTile(
                            title: "グッズ",
                            amount: snapshot.goodsAmount,
                            systemImage: "bag"
                        )
                    }
                    if snapshot.travelAmount > 0 {
                        expenseTile(
                            title: "遠征",
                            amount: snapshot.travelAmount,
                            systemImage: "suitcase.rolling"
                        )
                    }
                    if snapshot.legacyFallbackAmount > 0 {
                        expenseTile(
                            title: "その他・旧入力",
                            amount: snapshot.legacyFallbackAmount,
                            systemImage: "yensign.circle"
                        )
                    }
                }
            }

            if snapshot.usesTicketPhotoFallback {
                Text("申込金額が0円の観劇回は、チケット写真の確認済み金額を使っています。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            if snapshot.ignoredLegacyAmount > 0 {
                Text("構造化明細がある観劇回の旧入力合計 \(currencyText(snapshot.ignoredLegacyAmount)) は参考値として保持し、二重加算していません。")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .theaterEventCard(accentColor: accentColor)
    }

    private func expenseTile(title: String, amount: Decimal, systemImage: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(currencyText(amount))
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
    }

    private func currencyText(_ amount: Decimal) -> String {
        NumberFormatter.planCurrency.string(from: NSDecimalNumber(decimal: amount))
            ?? "¥\(NSDecimalNumber(decimal: amount).intValue)"
    }
}
