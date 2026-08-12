//
//  ExperienceMoneyUnitEditor.swift
//  favorecoAPP
//

import SwiftUI

struct ExperienceMoneyUnitEditor: View {
    @Binding var amountText: String
    @Binding var expenseEntries: [VisitExpenseEntry]
    var usesExplicitTheaterLayout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($expenseEntries) { $entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        TextField("費用の項目（例：チケット代）", text: $entry.title)
                            .textInputAutocapitalization(.never)

                        TextField("0", text: amountBinding(for: $entry))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 92)
                        Text("円")
                            .foregroundStyle(.secondary)

                        Button(role: .destructive) {
                            expenseEntries.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("費用内訳を削除")
                    }
                    Divider()
                }
            }

            Button {
                expenseEntries.append(VisitExpenseEntry())
            } label: {
                FavorecoIconLabel("費用内訳を追加", systemImage: "plus.circle.fill", iconSize: 15)
                    .font(FavorecoTypography.bodyStrong)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            }
            .buttonStyle(.plain)

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("合計")
                    .font(FavorecoTypography.bodyStrong)
                Spacer()
                Text(currencyText(totalAmount))
                    .font(FavorecoTypography.heroLead)
            }

            Text("チケット代、購入額、交通費などを項目ごとに追加し、合計をこの記録の金額として保存します。")
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear(perform: restoreLegacyAmountIfNeeded)
        .onChange(of: expenseEntries) { _, _ in
            amountText = totalAmount == Decimal(0)
                ? ""
                : NSDecimalNumber(decimal: totalAmount).stringValue
        }
    }

    private var totalAmount: Decimal {
        expenseEntries.reduce(Decimal(0)) { $0 + $1.normalizedAmount }
    }

    private func amountBinding(for entry: Binding<VisitExpenseEntry>) -> Binding<String> {
        Binding {
            guard entry.wrappedValue.amount > Decimal(0) else { return "" }
            return NSDecimalNumber(decimal: entry.wrappedValue.amount).stringValue
        } set: { value in
            let digits = value.filter(\.isNumber)
            entry.wrappedValue.amount = Decimal(string: digits) ?? Decimal(0)
        }
    }

    private func restoreLegacyAmountIfNeeded() {
        guard expenseEntries.isEmpty else { return }
        let normalized = amountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "￥", with: "")
        guard let amount = Decimal(string: normalized), amount > Decimal(0) else { return }
        expenseEntries = [VisitExpenseEntry(title: "その他", amount: amount)]
    }

    private func currencyText(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0"
    }
}
