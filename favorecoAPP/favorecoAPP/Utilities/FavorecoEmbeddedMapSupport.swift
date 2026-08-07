import MapKit
import SwiftUI
import UIKit

struct FavorecoMapDestination {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    var appleMapsURL: URL? {
        PlaceSearchService.appleMapsURL(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude
        )
    }

    var googleMapsURL: URL? {
        PlaceSearchService.googleMapsURL(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude
        )
    }
}

extension View {
    func favorecoEmbeddedMapInteraction() -> some View {
        background(FavorecoMapGestureConfigurator())
    }

    func favorecoMapDestinationDialog(
        destination: Binding<FavorecoMapDestination?>
    ) -> some View {
        modifier(FavorecoMapDestinationDialogModifier(destination: destination))
    }
}

private struct FavorecoMapDestinationDialogModifier: ViewModifier {
    @Binding var destination: FavorecoMapDestination?
    @Environment(\.openURL) private var openURL

    private var isPresented: Binding<Bool> {
        Binding(
            get: { destination != nil },
            set: { if !$0 { destination = nil } }
        )
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "地図で開く",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            if let url = destination?.appleMapsURL {
                Button("Appleマップで開く") { openURL(url) }
            }
            if let url = destination?.googleMapsURL {
                Button("Googleマップで開く") { openURL(url) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            if let destination {
                Text(destination.name.isEmpty ? destination.address : destination.name)
            }
        }
    }
}

private struct FavorecoMapGestureConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> FavorecoMapGestureFinderView {
        FavorecoMapGestureFinderView()
    }

    func updateUIView(_ uiView: FavorecoMapGestureFinderView, context: Context) {
        uiView.scheduleConfiguration()
    }
}

private final class FavorecoMapGestureFinderView: UIView {
    private weak var configuredMapView: MKMapView?
    private var isConfigurationScheduled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        scheduleConfiguration()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        scheduleConfiguration()
    }

    func scheduleConfiguration() {
        guard configuredMapView == nil, !isConfigurationScheduled else { return }
        isConfigurationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isConfigurationScheduled = false
            self.configureNearestMapView()
        }
    }

    private func configureNearestMapView() {
        var ancestor = superview
        while let candidate = ancestor {
            if let mapView = candidate as? MKMapView
                ?? candidate.firstDescendant(of: MKMapView.self, excluding: self) {
                mapView.isScrollEnabled = true
                mapView.isZoomEnabled = true
                if let scrollView = mapView.firstDescendant(
                    of: UIScrollView.self,
                    excluding: self
                ) {
                    scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
                    scrollView.panGestureRecognizer.maximumNumberOfTouches = 2
                }
                configuredMapView = mapView
                return
            }
            ancestor = candidate.superview
        }
    }
}

private extension UIView {
    func firstDescendant<T: UIView>(of type: T.Type, excluding excludedView: UIView) -> T? {
        for subview in subviews where subview !== excludedView {
            if let match = subview as? T {
                return match
            }
            if let match = subview.firstDescendant(of: type, excluding: excludedView) {
                return match
            }
        }
        return nil
    }
}
