import SwiftUI
import MapKit

struct TheaterEventTravelMapSection: View {
    let snapshot: TheaterTravelMapSnapshot
    let accentColor: Color

    @State private var selectedPointID: String?

    private var selectedPoint: TheaterTravelMapPoint? {
        snapshot.points.first(where: { $0.id == selectedPointID })
    }

    private var mappedVisitCount: Int {
        snapshot.points.reduce(0) { $0 + $1.visitCount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("遠征Map")
                    .font(FavorecoTypography.sectionTitle)
                    .foregroundStyle(Color(red: 0.96, green: 0.93, blue: 0.88))
                Spacer(minLength: 8)
                Text("\(snapshot.points.count)会場")
                    .font(FavorecoTypography.captionStrong)
                    .foregroundStyle(.secondary)
            }

            map

            if let selectedPoint {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(accentColor)
                    Text(selectedPoint.name)
                        .font(FavorecoTypography.captionStrong)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text("\(selectedPoint.visitCount)回")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 8) {
                    Label("\(snapshot.points.count)会場", systemImage: "mappin.and.ellipse")
                    Text("\(mappedVisitCount)回")
                    if snapshot.missingCoordinateCount > 0 {
                        Text("位置未設定 \(snapshot.missingCoordinateCount)件")
                    }
                }
                .font(FavorecoTypography.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .theaterEventCard(accentColor: accentColor)
        .onChange(of: snapshot.points.map(\.id)) { _, ids in
            if let selectedPointID, ids.contains(selectedPointID) { return }
            self.selectedPointID = nil
        }
    }

    private var map: some View {
        Map(
            initialPosition: .region(Self.region(for: snapshot.points)),
            interactionModes: [.pan, .zoom]
        ) {
            ForEach(snapshot.points) { point in
                Annotation(
                    point.name,
                    coordinate: CLLocationCoordinate2D(
                        latitude: point.latitude,
                        longitude: point.longitude
                    ),
                    anchor: .bottom
                ) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedPointID = selectedPointID == point.id ? nil : point.id
                        }
                    } label: {
                        TheaterTravelMapMarker(
                            count: point.visitCount,
                            accentColor: accentColor,
                            isSelected: selectedPointID == point.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(point.name)、参加\(point.visitCount)回")
                    .accessibilityHint("タップすると会場名を地図の下に表示します")
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accentColor.opacity(0.24), lineWidth: 0.75)

            if snapshot.points.isEmpty {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.82))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.title2)
                            Text("会場の位置を登録するとMapに表示されます")
                                .font(FavorecoTypography.captionStrong)
                            if snapshot.totalVisitCount > 0 {
                                Text("参加記録の場所をApple Mapsから選ぶか、場所マスターへ座標を登録してください。")
                                    .font(FavorecoTypography.caption)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(24)
                    }
            }
        }
        .id(snapshot.points.map(\.id).joined(separator: "|"))
    }

    private static func region(for points: [TheaterTravelMapPoint]) -> MKCoordinateRegion {
        guard !points.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18)
            )
        }

        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        let minimumLatitude = latitudes.min() ?? 36.2048
        let maximumLatitude = latitudes.max() ?? 36.2048
        let minimumLongitude = longitudes.min() ?? 138.2529
        let maximumLongitude = longitudes.max() ?? 138.2529
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minimumLatitude + maximumLatitude) / 2,
                longitude: (minimumLongitude + maximumLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.08, (maximumLatitude - minimumLatitude) * 1.7),
                longitudeDelta: max(0.08, (maximumLongitude - minimumLongitude) * 1.7)
            )
        )
    }
}

private struct TheaterTravelMapMarker: View {
    let count: Int
    let accentColor: Color
    let isSelected: Bool

    var body: some View {
        VStack(spacing: -3) {
            ZStack {
                Circle()
                    .fill(isSelected ? accentColor : Color.black.opacity(0.88))
                Circle()
                    .stroke(accentColor, lineWidth: isSelected ? 2.5 : 1.5)
                Text("\(count)")
                    .font(FavorecoTypography.jpSans(13, weight: .bold, relativeTo: .caption))
                    .foregroundStyle(isSelected ? Color.black : Color.white)
            }
            .frame(width: 36, height: 36)
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(accentColor)
                .rotationEffect(.degrees(180))
        }
        .scaleEffect(isSelected ? 1.1 : 1)
    }
}
