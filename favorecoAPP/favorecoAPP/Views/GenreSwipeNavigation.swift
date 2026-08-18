import MapKit
import SwiftUI
import UIKit

struct GenreSwipeContainer<Content: View>: View {
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let onMove: (Int) -> Void
    @ViewBuilder let content: Content

    @State private var dragOffset: CGFloat = 0
    @State private var isMoveLocked = false

    var body: some View {
        content
            .contentShape(Rectangle())
            .offset(x: dragOffset)
            .background {
                GeometryReader { geometry in
                    DirectionalHorizontalPanInstaller(
                        onBegan: {},
                        onChanged: { translation in
                            guard !isMoveLocked else { return }
                            let direction = translation < 0 ? 1 : -1
                            let hasDestination = direction > 0 ? canMoveForward : canMoveBackward
                            dragOffset = hasDestination ? translation : translation * 0.18
                        },
                        onEnded: { translation, velocity in
                            finishGesture(translation: translation, velocity: velocity)
                        },
                        onCancelled: {
                            settleBack()
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
    }

    private func finishGesture(translation: CGFloat, velocity: CGFloat) {
        guard !isMoveLocked else {
            settleBack()
            return
        }

        let projectedTranslation = translation + velocity * 0.16
        let direction = translation < 0 ? 1 : -1
        let hasDestination = direction > 0 ? canMoveForward : canMoveBackward
        let shouldMove = abs(translation) >= 72 || abs(projectedTranslation) >= 140

        if shouldMove && hasDestination {
            isMoveLocked = true
            dragOffset = 0
            onMove(direction)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                isMoveLocked = false
            }
        } else {
            settleBack()
        }
    }

    private func settleBack() {
        withAnimation(.timingCurve(0.18, 0.78, 0.24, 1, duration: 0.18)) {
            dragOffset = 0
        }
    }

}

struct GenreSwipeExclusionZone: View {
    var body: some View {
        GenreSwipeExclusionMarker()
            .allowsHitTesting(false)
    }
}

enum GenreSwipeGestureCoordination {
    static let activationDistance: CGFloat = 24

    static func hasReachedActivationDistance(_ translation: CGPoint) -> Bool {
        hypot(translation.x, translation.y) >= activationDistance
    }

    static func allowsSimultaneousRecognition(
        with otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer
    }
}

private struct GenreSwipeExclusionMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        GenreSwipeExclusionMarkerView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

@MainActor
private final class GenreSwipeExclusionMarkerView: UIView {}

private struct DirectionalHorizontalPanInstaller: UIViewRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat, CGFloat) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = HierarchyAwareMarkerView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.onHierarchyChange = { [weak coordinator = context.coordinator] markerView in
            coordinator?.installIfNeeded(from: markerView)
        }
        context.coordinator.markerView = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.update(
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
        context.coordinator.markerView = uiView
        DispatchQueue.main.async {
            context.coordinator.installIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        (uiView as? HierarchyAwareMarkerView)?.onHierarchyChange = nil
        coordinator.uninstall()
    }

    @MainActor
    final class HierarchyAwareMarkerView: UIView {
        var onHierarchyChange: ((UIView) -> Void)?

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            onHierarchyChange?(self)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onHierarchyChange?(self)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var markerView: UIView?
        private weak var installedView: UIView?
        private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
            let recognizer = IntentionalGenrePanGestureRecognizer(
                target: self,
                action: #selector(handlePan(_:))
            )
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = true
            recognizer.delaysTouchesBegan = false
            recognizer.maximumNumberOfTouches = 1
            return recognizer
        }()

        private var onBegan: () -> Void
        private var onChanged: (CGFloat) -> Void
        private var onEnded: (CGFloat, CGFloat) -> Void
        private var onCancelled: () -> Void

        init(
            onBegan: @escaping () -> Void,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onBegan = onBegan
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        func update(
            onBegan: @escaping () -> Void,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.onBegan = onBegan
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        func installIfNeeded(from markerView: UIView) {
            var ancestor = markerView.superview
            while let view = ancestor, !(view is UIScrollView) {
                ancestor = view.superview
            }
            guard let scrollView = ancestor else { return }
            guard installedView !== scrollView else { return }
            uninstall()
            scrollView.addGestureRecognizer(panGestureRecognizer)
            installedView = scrollView
        }

        func uninstall() {
            installedView?.removeGestureRecognizer(panGestureRecognizer)
            installedView = nil
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer,
                  let installedView,
                  let markerView else { return false }

            let location = pan.location(in: installedView)
            let activeFrame = markerView.convert(markerView.bounds, to: installedView)
            guard activeFrame.contains(location) else { return false }
            guard !containsExclusionZone(at: location, in: installedView) else { return false }

            if let touchedView = installedView.hitTest(location, with: nil) {
                if isInsideNestedHorizontalScrollView(touchedView, outerScrollView: installedView)
                    || isInsideMapView(touchedView, outerScrollView: installedView) {
                    return false
                }
            }

            let velocity = pan.velocity(in: installedView)
            guard abs(velocity.x) > abs(velocity.y) * 1.2 else { return false }

            if let window = installedView.window {
                let windowLocation = pan.location(in: window)
                guard windowLocation.x >= 24, windowLocation.x <= window.bounds.width - 24 else { return false }
            }
            return true
        }

        private func containsExclusionZone(at location: CGPoint, in rootView: UIView) -> Bool {
            var pendingViews = rootView.subviews
            while let view = pendingViews.popLast() {
                if let marker = view as? GenreSwipeExclusionMarkerView {
                    let frame = marker.convert(marker.bounds, to: rootView)
                    if frame.contains(location) {
                        return true
                    }
                }
                pendingViews.append(contentsOf: view.subviews)
            }
            return false
        }

        private func isInsideNestedHorizontalScrollView(
            _ touchedView: UIView,
            outerScrollView: UIView
        ) -> Bool {
            var candidate: UIView? = touchedView
            while let view = candidate, view !== outerScrollView {
                if let scrollView = view as? UIScrollView,
                   scrollView.contentSize.width > scrollView.bounds.width + 1 {
                    return true
                }
                candidate = view.superview
            }
            return false
        }

        private func isInsideMapView(
            _ touchedView: UIView,
            outerScrollView: UIView
        ) -> Bool {
            var candidate: UIView? = touchedView
            while let view = candidate, view !== outerScrollView {
                if view is MKMapView { return true }
                candidate = view.superview
            }
            return false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            GenreSwipeGestureCoordination.allowsSimultaneousRecognition(
                with: otherGestureRecognizer
            )
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: installedView).x
            let velocity = recognizer.velocity(in: installedView).x
            switch recognizer.state {
            case .began:
                onBegan()
            case .changed:
                onChanged(translation)
            case .ended:
                onEnded(translation, velocity)
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }
    }
}

@MainActor
private final class IntentionalGenrePanGestureRecognizer: UIPanGestureRecognizer {
    private var initialLocation: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        initialLocation = touches.first?.location(in: view)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible,
           let initialLocation,
           let currentLocation = touches.first?.location(in: view) {
            let translation = CGPoint(
                x: currentLocation.x - initialLocation.x,
                y: currentLocation.y - initialLocation.y
            )
            guard GenreSwipeGestureCoordination.hasReachedActivationDistance(translation) else {
                return
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        initialLocation = nil
        super.reset()
    }
}
