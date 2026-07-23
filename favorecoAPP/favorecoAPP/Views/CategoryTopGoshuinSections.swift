import SwiftUI
import UIKit
import MapKit

enum GoshuinVisitFilter: String, CaseIterable, Identifiable {
    case all
    case shrine
    case temple
    case limited
    case special

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全て"
        case .shrine: return "神社"
        case .temple: return "お寺"
        case .limited: return "限定"
        case .special: return "特別"
        }
    }

    func matches(_ visit: Visit) -> Bool {
        switch self {
        case .all:
            return true
        case .shrine:
            return placeKind(for: visit) == .shrine
        case .temple:
            return placeKind(for: visit) == .temple
        case .limited:
            return searchableText(for: visit).contains("限定")
        case .special:
            let text = searchableText(for: visit)
            return text.contains("特別") || text.contains("特製") || text.contains("記念")
        }
    }

    private func placeKind(for visit: Visit) -> GoshuinPlaceKind {
        let text = searchableText(for: visit)
        if text.contains("寺") || text.contains("院") || text.contains("観音") || text.contains("薬師") {
            return .temple
        }
        if text.contains("神社") || text.contains("大社") || text.contains("宮") || text.contains("稲荷") {
            return .shrine
        }
        return .unknown
    }

    private func searchableText(for visit: Visit) -> String {
        [
            visit.event?.title ?? "",
            visit.venueNameSnapshot,
            visit.placeMaster?.name ?? "",
            visit.placeMaster?.placeTagsRaw ?? "",
            visit.placeMaster?.address ?? "",
            visit.note,
            VisitUnitFields(rawValue: visit.unitFieldsRaw).ocrText,
        ].joined(separator: " ")
    }
}

enum GoshuinPlaceKind {
    case shrine
    case temple
    case unknown
}

struct GoshuinFilterBar: View {
    @Binding var selection: GoshuinVisitFilter
    let options: [GoshuinVisitFilter]

    @Environment(\.favorecoThemePalette) private var themePalette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    Button {
                        selection = option
                    } label: {
                        Text(option.title)
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(selection == option ? .white : .primary)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(
                                selection == option
                                ? themePalette.globalTint
                                : Color(.secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct GoshuinTopHero: View {
    let category: RecordCategory
    let visits: [Visit]
    @Binding var selectedIndex: Int
    let onAdd: () -> Void

    @Environment(\.favorecoThemePalette) private var themePalette

    private var accent: Color {
        themePalette.categoryColor(hex: category.colorHex)
    }

    var body: some View {
        VStack(spacing: 10) {
            if visits.isEmpty {
                heroCard(visit: nil)
            } else if visits.count == 1 {
                heroCard(visit: visits[0])
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(visits.enumerated()), id: \.element.id) { index, visit in
                        heroCard(visit: visit)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 196)

                HStack(spacing: 7) {
                    ForEach(visits.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? accent : Color.secondary.opacity(0.28))
                            .frame(width: 7, height: 7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(selectedIndex + 1)件目／全\(visits.count)件")
            }
        }
    }

    private func heroCard(visit: Visit?) -> some View {
        HStack(alignment: .center, spacing: 16) {
            goshuinImage(visit: visit)

            VStack(alignment: .leading, spacing: 8) {
                Text("最近いただいた御朱印")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(accent)

                Text(visit?.event?.title.isEmpty == false ? visit?.event?.title ?? "参拝先" : "御朱印を残す")
                    .font(FavorecoTypography.jpSerif(22, weight: .bold, relativeTo: .title3))
                    .lineLimit(2, reservesSpace: true)

                if let visit {
                    Text("\(FavorecoDateText.compactDate(visit.visitedAt)) ・ \(visit.venueNameSnapshot.isEmpty ? "場所未設定" : visit.venueNameSnapshot)")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("御朱印帳のサイズに合わせて、参拝の証を美しく残せます。")
                        .font(FavorecoTypography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onAdd) {
                    Label(visit == nil ? "最初の御朱印を追加" : "御朱印を追加", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
        .padding(14)
        .background {
            GoshuinWashiBackground(accent: accent)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.18), lineWidth: 0.75)
        }
    }

    @ViewBuilder
    private func goshuinImage(visit: Visit?) -> some View {
        let sizeKey = visit.map { VisitUnitFields(rawValue: $0.unitFieldsRaw).goshuinBookSizeKey } ?? ""
        let size = GoshuinBookSize.option(for: sizeKey)
        let isWide = size.key == GoshuinBookSize.wide.key
        let imageWidth: CGFloat = isWide ? 132 : 104
        let imageHeight = imageWidth / CGFloat(size.aspectRatio)
        let photo = visit.flatMap { firstPhoto(in: $0) }

        ZStack(alignment: .bottomLeading) {
            if let photo {
                RepresentativePhotoImage(photo: photo, maxPixelSize: 480, contentMode: .fill)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                    .background(Color.white.opacity(0.72))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.72))
                    .frame(width: imageWidth, height: imageHeight)
                    .overlay {
                        Image(systemName: "seal")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(accent.opacity(0.8))
                    }
            }

            if isWide {
                Text("見開き")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    private func firstPhoto(in visit: Visit) -> PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .min { $0.createdAt < $1.createdAt }
    }
}

struct GoshuinWashiBackground: View {
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.96, blue: 0.90),
                    accent.opacity(0.26),
                    Color(red: 0.93, green: 0.84, blue: 0.76),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Canvas { context, size in
                for index in 0..<90 {
                    let x = CGFloat((index * 37) % 100) / 100 * size.width
                    let y = CGFloat((index * 61) % 100) / 100 * size.height
                    let radius = CGFloat((index % 3) + 1) * 0.42
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.26 : 0.14))
                    )
                }
            }
        }
    }
}

struct GoshuinStampTile: View {
    let visit: Visit
    let photo: PhotoBlob?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            stampImage
            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先")
                .font(FavorecoTypography.captionStrong)
                .lineLimit(1)
            Text(FavorecoDateText.compactDate(visit.visitedAt))
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var stampImage: some View {
        let fields = VisitUnitFields(rawValue: visit.unitFieldsRaw)
        let size = GoshuinBookSize.option(for: fields.goshuinBookSizeKey)
        if let photo {
            RepresentativePhotoImage(photo: photo, maxPixelSize: 360, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(CGFloat(size.aspectRatio), contentMode: .fit)
                .frame(minHeight: 120)
                .clipped()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .aspectRatio(CGFloat(size.aspectRatio), contentMode: .fit)
                .overlay {
                    Image(systemName: "seal")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

struct GoshuinBookSelection: Identifiable {
    let size: GoshuinBookSize
    let visits: [Visit]
    let coverPhoto: PhotoBlob?

    var id: String { size.key }
}

struct GoshuinBookRow: View {
    let selection: GoshuinBookSelection

    var body: some View {
        HStack(spacing: 12) {
            if let coverPhoto = selection.coverPhoto {
                RepresentativePhotoImage(photo: coverPhoto, maxPixelSize: 240, contentMode: .fill)
                    .frame(width: 56, height: 56 / CGFloat(selection.size.aspectRatio))
                    .clipped()
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 56, height: 56 / CGFloat(selection.size.aspectRatio))
                    .overlay { Image(systemName: "book.closed") }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(selection.size.name)
                    .font(FavorecoTypography.bodyStrong)
                Text("\(selection.visits.count)件 ・ \(selection.size.displaySize)")
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct GoshuinBookGalleryView: View {
    let selection: GoshuinBookSelection
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(selection.visits) { visit in
                        NavigationLink {
                            CategoryVisitDestination(visitID: visit.id)
                        } label: {
                            GoshuinStampTile(visit: visit, photo: firstPhoto(in: visit))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(selection.size.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func firstPhoto(in visit: Visit) -> PhotoBlob? {
        (visit.photos ?? [])
            .filter { $0.mediaKind == "photo" && $0.hasStoredData }
            .min { $0.createdAt < $1.createdAt }
    }
}

struct GoshuinMapItem: Identifiable {
    let id: UUID
    let title: String
    let coordinate: CLLocationCoordinate2D
}

struct GoshuinMapPreview: View {
    let visits: [Visit]

    private var items: [GoshuinMapItem] {
        visits.compactMap { visit in
            let hasVisitCoordinate = visit.latitude != 0 || visit.longitude != 0
            let latitude = hasVisitCoordinate ? visit.latitude : (visit.placeMaster?.latitude ?? 0)
            let longitude = hasVisitCoordinate ? visit.longitude : (visit.placeMaster?.longitude ?? 0)
            guard latitude != 0 || longitude != 0 else { return nil }
            return GoshuinMapItem(
                id: visit.id,
                title: visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先",
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            )
        }
    }

    var body: some View {
        Map(initialPosition: .region(Self.region(for: items))) {
            ForEach(items) { item in
                Marker(item.title, coordinate: item.coordinate)
            }
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if items.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.title2)
                            Text("場所を登録するとMAPにピンが立ちます")
                                .font(FavorecoTypography.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
    }

    private static func region(for items: [GoshuinMapItem]) -> MKCoordinateRegion {
        guard !items.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18)
            )
        }

        let latitudes = items.map { $0.coordinate.latitude }
        let longitudes = items.map { $0.coordinate.longitude }
        let minLatitude = latitudes.min() ?? 36.2048
        let maxLatitude = latitudes.max() ?? 36.2048
        let minLongitude = longitudes.min() ?? 138.2529
        let maxLongitude = longitudes.max() ?? 138.2529
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.5, (maxLatitude - minLatitude) * 1.8),
                longitudeDelta: max(0.5, (maxLongitude - minLongitude) * 1.8)
            )
        )
    }
}

struct GoshuinVisitedPlaceRow: View {
    let visit: Visit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先")
                    .font(FavorecoTypography.bodyStrong)
                    .lineLimit(1)
                Text(placeText)
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(FavorecoDateText.compactDate(visit.visitedAt))
                    .font(FavorecoTypography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var placeText: String {
        let address = visit.placeMaster?.address.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !address.isEmpty { return address }
        if !visit.venueNameSnapshot.isEmpty { return visit.venueNameSnapshot }
        return "場所未設定"
    }
}

enum CategoryTopJapanPrefecture: String, CaseIterable {
    case hokkaido = "北海道"
    case aomori = "青森県"
    case iwate = "岩手県"
    case miyagi = "宮城県"
    case akita = "秋田県"
    case yamagata = "山形県"
    case fukushima = "福島県"
    case ibaraki = "茨城県"
    case tochigi = "栃木県"
    case gunma = "群馬県"
    case saitama = "埼玉県"
    case chiba = "千葉県"
    case tokyo = "東京都"
    case kanagawa = "神奈川県"
    case niigata = "新潟県"
    case toyama = "富山県"
    case ishikawa = "石川県"
    case fukui = "福井県"
    case yamanashi = "山梨県"
    case nagano = "長野県"
    case gifu = "岐阜県"
    case shizuoka = "静岡県"
    case aichi = "愛知県"
    case mie = "三重県"
    case shiga = "滋賀県"
    case kyoto = "京都府"
    case osaka = "大阪府"
    case hyogo = "兵庫県"
    case nara = "奈良県"
    case wakayama = "和歌山県"
    case tottori = "鳥取県"
    case shimane = "島根県"
    case okayama = "岡山県"
    case hiroshima = "広島県"
    case yamaguchi = "山口県"
    case tokushima = "徳島県"
    case kagawa = "香川県"
    case ehime = "愛媛県"
    case kochi = "高知県"
    case fukuoka = "福岡県"
    case saga = "佐賀県"
    case nagasaki = "長崎県"
    case kumamoto = "熊本県"
    case oita = "大分県"
    case miyazaki = "宮崎県"
    case kagoshima = "鹿児島県"
    case okinawa = "沖縄県"
}

struct GoshuinPrefectureSearchView: View {
    @Binding var selectedPrefecture: String
    let availablePrefectures: [String]
    @Environment(\.dismiss) private var dismiss

    private var prefectures: [String] {
        let base = availablePrefectures.isEmpty ? CategoryTopJapanPrefecture.allCases.map(\.rawValue) : availablePrefectures
        return base.sorted()
    }

    var body: some View {
        NavigationStack {
            List {
                Button("すべての都道府県") {
                    selectedPrefecture = ""
                    dismiss()
                }
                ForEach(prefectures, id: \.self) { prefecture in
                    Button {
                        selectedPrefecture = prefecture
                        dismiss()
                    } label: {
                        HStack {
                            Text(prefecture)
                            Spacer()
                            if selectedPrefecture == prefecture {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .navigationTitle("県で絞り込み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct GoshuinVisitedShareCard: View {
    let visits: [Visit]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Favoreco")
                .font(FavorecoTypography.latinDisplay(34, weight: .bold, relativeTo: .title))
            Text("行った神社・お寺リスト")
                .font(FavorecoTypography.jpSerif(28, weight: .bold, relativeTo: .title2))
            Text("\(visits.count)件の参拝記録")
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(visits.prefix(12).enumerated()), id: \.element.id) { index, visit in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(FavorecoTypography.captionStrong)
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color(red: 0.58, green: 0.18, blue: 0.22), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(visit.event?.title.isEmpty == false ? visit.event?.title ?? "参拝先" : "参拝先")
                                .font(FavorecoTypography.bodyStrong)
                                .lineLimit(1)
                            Text("\(FavorecoDateText.compactDate(visit.visitedAt)) ・ \(visit.venueNameSnapshot.isEmpty ? "場所未設定" : visit.venueNameSnapshot)")
                                .font(FavorecoTypography.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Spacer()
            Text("#Favoreco")
                .font(FavorecoTypography.bodyStrong)
                .foregroundStyle(Color(red: 0.58, green: 0.18, blue: 0.22))
        }
        .padding(28)
        .frame(width: 390, height: 760, alignment: .topLeading)
        .background(GoshuinWashiBackground(accent: Color(red: 0.58, green: 0.18, blue: 0.22)))
    }
}

struct GoshuinActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
