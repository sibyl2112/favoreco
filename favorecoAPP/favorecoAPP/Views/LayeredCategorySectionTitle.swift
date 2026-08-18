import SwiftUI

struct LayeredCategorySectionTitle: View {
    let englishTitle: String
    let japaneseTitle: String
    let foregroundColor: Color

    private var displayedJapaneseTitle: String {
        let normalizedTitle = String(japaneseTitle.filter { !$0.isWhitespace })
        guard normalizedTitle.count <= 5 else { return normalizedTitle }
        return normalizedTitle.map(String.init).joined(separator: " ")
    }

    var body: some View {
        Text(englishTitle)
            .font(FavorecoTypography.latinDisplay(22, weight: .semibold, relativeTo: .title3))
            .foregroundStyle(foregroundColor)
            .background(alignment: .leading) {
                Text(displayedJapaneseTitle)
                    .font(FavorecoTypography.jpSerif(20, weight: .semibold, relativeTo: .body))
                    .foregroundStyle(foregroundColor.opacity(0.18))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
                    .offset(x: 17, y: -10)
                    .allowsHitTesting(false)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.top, 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(japaneseTitle)
    }
}
