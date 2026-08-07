import SwiftUI
import MapKit

struct TheaterEventTravelMapSection: View {
    let visitSnapshot: TheaterTravelMapSnapshot
    let schedules: [TheaterPerformanceScheduleItem]
    let accentColor: Color

    @State private var selectedPointID: String?
    @State private var resolvedVenues: [TheaterTravelMapVenue] = []
    @State private var missingVenueCoordinateCount = 0
    @State private var isResolvingVenues = false
    @State private var mapDestination: FavorecoMapDestination?

    private var snapshot: TheaterTravelMapSnapshot {
        TheaterTravelMapSnapshot.make(
            visits: [],
            venues: resolvedVenues,
            missingVenueCoordinateCount: missingVenueCoordinateCount
        )
        .mergingVisitSnapshot(visitSnapshot)
    }

    private var selectedPoint: TheaterTravelMapPoint? {
        snapshot.points.first(where: { $0.id == selectedPointID })
    }

    private var mappedVisitCount: Int {
        snapshot.points.reduce(0) { $0 + $1.visitCount }
    }

    private var hasMappedVisits: Bool {
        mappedVisitCount > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(hasMappedVisits ? "遠征Map" : "公演地Map")
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
                    FavorecoIcon(systemName: "mappin.and.ellipse", size: 16)
                        .foregroundStyle(accentColor)
                    Text(selectedPoint.name)
                        .font(FavorecoTypography.captionStrong)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(selectedPoint.visitCount > 0 ? "\(selectedPoint.visitCount)回" : "公演地")
                        .font(FavorecoTypography.captionStrong)
                        .foregroundStyle(accentColor)
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 8) {
                    FavorecoIconLabel("\(snapshot.points.count)会場", systemImage: "mappin.and.ellipse")
                    if hasMappedVisits {
                        Text("\(mappedVisitCount)回")
                    }
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
        .task(id: venueResolutionKey) {
            await resolveScheduleVenues()
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
                        mapDestination = FavorecoMapDestination(
                            name: point.name,
                            address: "",
                            latitude: point.latitude,
                            longitude: point.longitude
                        )
                    } label: {
                        TheaterTravelMapMarker(
                            count: point.visitCount,
                            accentColor: accentColor,
                            isSelected: selectedPointID == point.id
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        point.visitCount > 0
                            ? "\(point.name)、参加\(point.visitCount)回"
                            : "\(point.name)、公演会場"
                    )
                    .accessibilityHint("タップすると外部地図を選べます")
                }
            }
        }
        .favorecoEmbeddedMapInteraction()
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
                            if isResolvingVenues {
                                ProgressView()
                                Text("公演情報の会場をMapに反映中")
                                    .font(FavorecoTypography.captionStrong)
                            } else {
                                FavorecoIcon(systemName: "map", size: 22)
                                Text("会場の位置を登録するとMapに表示されます")
                                    .font(FavorecoTypography.captionStrong)
                                if snapshot.totalVisitCount > 0 || !schedules.isEmpty {
                                    Text("公演情報の会場・住所を確認するか、参加記録の場所をApple Mapsから選んでください。")
                                        .font(FavorecoTypography.caption)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .foregroundStyle(.secondary)
                        .padding(24)
                    }
            }
        }
        .id(snapshot.points.map(\.id).joined(separator: "|"))
        .favorecoMapDestinationDialog(destination: $mapDestination)
    }

    private var venueResolutionKey: String {
        schedules
            .map { "\($0.id)|\($0.venueName)|\($0.address)" }
            .joined(separator: "||")
    }

    @MainActor
    private func resolveScheduleVenues() async {
        isResolvingVenues = !schedules.isEmpty
        var venues: [TheaterTravelMapVenue] = []
        var missingCount = 0

        for schedule in schedules {
            guard !Task.isCancelled else { return }
            let name = schedule.venueName.trimmingCharacters(in: .whitespacesAndNewlines)
            let address = schedule.address.trimmingCharacters(in: .whitespacesAndNewlines)
            let query = [name, address].filter { !$0.isEmpty }.joined(separator: " ")
            guard !query.isEmpty else {
                missingCount += 1
                continue
            }

            do {
                if let candidate = try await PlaceSearchService.search(query: query).first {
                    venues.append(
                        TheaterTravelMapVenue(
                            id: schedule.id,
                            name: name.isEmpty ? candidate.name : name,
                            latitude: candidate.latitude,
                            longitude: candidate.longitude
                        )
                    )
                } else {
                    missingCount += 1
                }
            } catch {
                missingCount += 1
            }
        }

        guard !Task.isCancelled else { return }
        resolvedVenues = venues
        missingVenueCoordinateCount = missingCount
        isResolvingVenues = false
    }

    private static func region(for points: [TheaterTravelMapPoint]) -> MKCoordinateRegion {
        guard !points.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 18, longitudeDelta: 18)
            )
        }

        if let point = points.first, points.count == 1 {
            return FavorecoMapViewport.singlePointRegion(
                center: CLLocationCoordinate2D(
                    latitude: point.latitude,
                    longitude: point.longitude
                )
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
                if count > 0 {
                    Text("\(count)")
                        .font(FavorecoTypography.jpSans(13, weight: .bold, relativeTo: .caption))
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                } else {
                    FavorecoIcon(systemName: "mappin", size: 15)
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                }
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
