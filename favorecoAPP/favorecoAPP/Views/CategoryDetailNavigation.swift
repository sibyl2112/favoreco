//
//  CategoryDetailNavigation.swift
//  favorecoAPP
//
//  Shared category detail destinations and panel navigation.
//

import SwiftUI
import SwiftData

struct CategoryEventDestination: View {
    @Query private var events: [ExperienceEvent]

    init(eventID: UUID) {
        _events = Query(filter: #Predicate<ExperienceEvent> { $0.id == eventID })
    }

    var body: some View {
        if let event = events.first {
            EventDetailView(event: event)
        } else {
            FavorecoContentUnavailableView("対象が見つかりません", systemImage: "trash")
        }
    }
}
enum CategoryDetailPanelSelection: Identifiable, Equatable {
    case plan(UUID)
    case visit(UUID)

    var id: String {
        switch self {
        case .plan(let id): return "plan-\(id.uuidString)"
        case .visit(let id): return "visit-\(id.uuidString)"
        }
    }
}

struct CategoryDetailSwipeExclusionPreferenceKey: PreferenceKey {
    static var defaultValue: [CGRect] = []

    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

struct CategoryDetailPanelOverlay: View {
    let selection: CategoryDetailPanelSelection
    let onClose: () -> Void
    let onOpenEvent: (UUID) -> Void
    let onOpenVisit: (UUID) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false
    @State private var swipeExclusionFrames: [CGRect] = []

    var body: some View {
        GeometryReader { proxy in
            let swipeProgress = min(max(dragOffset / 300, 0), 1)

            ZStack {
                Color.black.opacity(0.62 * (1 - Double(swipeProgress) * 0.45))
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                Group {
                    switch selection {
                    case .plan(let planID):
                        CategoryPlanDestination(
                            planID: planID,
                            onBack: onClose,
                            onOpenEvent: onOpenEvent
                        )
                    case .visit(let visitID):
                        CategoryVisitDestination(
                            visitID: visitID,
                            onBack: onClose,
                            onOpenEvent: onOpenEvent,
                            onOpenVisit: onOpenVisit
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: max(dragOffset, 0))
                .rotationEffect(
                    .degrees(Double(swipeProgress) * 12),
                    anchor: .bottomLeading
                )
                .opacity(1 - Double(swipeProgress) * 0.4)
                .simultaneousGesture(
                    dismissGesture(containerWidth: proxy.size.width),
                    including: .all
                )
            }
        }
        .ignoresSafeArea()
        .zIndex(100)
        .accessibilityElement(children: .contain)
        .onPreferenceChange(CategoryDetailSwipeExclusionPreferenceKey.self) { frames in
            swipeExclusionFrames = frames.filter { !$0.isEmpty && !$0.isNull }
        }
    }

    private func dismissGesture(containerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .global)
            .onChanged { value in
                guard !isDismissing else { return }
                guard value.startLocation.x <= containerWidth * 0.72 else { return }
                guard !startsInsideSwipeExclusion(value.startLocation) else { return }

                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard horizontal > 0, horizontal > vertical * 1.35 else { return }
                dragOffset = horizontal
            }
            .onEnded { value in
                guard !isDismissing else { return }
                guard value.startLocation.x <= containerWidth * 0.72 else { return }
                guard !startsInsideSwipeExclusion(value.startLocation) else {
                    dragOffset = 0
                    return
                }

                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                let predictedHorizontal = value.predictedEndTranslation.width
                let isHorizontalSwipe = horizontal > 0 && horizontal > vertical * 1.35

                if isHorizontalSwipe,
                   (horizontal > 80 || predictedHorizontal > 420) {
                    isDismissing = true
                    withAnimation(.easeOut(duration: 0.28)) {
                        dragOffset = max(containerWidth, 1) * 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            onClose()
                        }
                    }
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func startsInsideSwipeExclusion(_ location: CGPoint) -> Bool {
        swipeExclusionFrames.contains { $0.contains(location) }
    }
}

struct CategoryVisitDestination: View {
    @Query private var visits: [Visit]
    let onBack: (() -> Void)?
    let onOpenEvent: ((UUID) -> Void)?
    let onOpenVisit: ((UUID) -> Void)?

    init(
        visitID: UUID,
        onBack: (() -> Void)? = nil,
        onOpenEvent: ((UUID) -> Void)? = nil,
        onOpenVisit: ((UUID) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onOpenEvent = onOpenEvent
        self.onOpenVisit = onOpenVisit
        _visits = Query(filter: #Predicate<Visit> { $0.id == visitID })
    }

    var body: some View {
        if let visit = visits.first {
            ExperienceDetailView(
                visit: visit,
                onBack: onBack,
                onOpenEvent: onOpenEvent,
                onOpenVisit: onOpenVisit
            )
        } else {
            FavorecoContentUnavailableView("記録が見つかりません", systemImage: "trash")
        }
    }
}

private struct CategoryPlanDestination: View {
    @Query private var plans: [Plan]
    let onBack: (() -> Void)?
    let onOpenEvent: ((UUID) -> Void)?

    init(
        planID: UUID,
        onBack: (() -> Void)? = nil,
        onOpenEvent: ((UUID) -> Void)? = nil
    ) {
        self.onBack = onBack
        self.onOpenEvent = onOpenEvent
        _plans = Query(filter: #Predicate<Plan> { $0.id == planID })
    }

    var body: some View {
        if let plan = plans.first {
            PlanDetailView(
                plan: plan,
                onBack: onBack,
                onOpenEvent: onOpenEvent
            )
        } else {
            FavorecoContentUnavailableView("予定が見つかりません", systemImage: "trash")
        }
    }
}
