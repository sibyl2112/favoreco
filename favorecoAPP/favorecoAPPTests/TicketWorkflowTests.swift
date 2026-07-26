import XCTest
@testable import favoreco

@MainActor
final class TicketWorkflowTests: XCTestCase {
    func testHomeTicketDeadlineUrgencyDistinguishesNormalTomorrowTodayAndOverdue() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(2026, 7, 24, hour: 12)

        XCTAssertEqual(
            HomeTicketDeadlineUrgency.resolve(
                dueDate: date(2026, 7, 31, hour: 10),
                showsDueDate: true,
                isOverdue: false,
                now: now,
                calendar: calendar
            ),
            .normal
        )
        XCTAssertEqual(
            HomeTicketDeadlineUrgency.resolve(
                dueDate: date(2026, 7, 25, hour: 10),
                showsDueDate: true,
                isOverdue: false,
                now: now,
                calendar: calendar
            ),
            .tomorrow
        )
        XCTAssertEqual(
            HomeTicketDeadlineUrgency.resolve(
                dueDate: date(2026, 7, 24, hour: 18),
                showsDueDate: true,
                isOverdue: false,
                now: now,
                calendar: calendar
            ),
            .today
        )
        XCTAssertEqual(
            HomeTicketDeadlineUrgency.resolve(
                dueDate: date(2026, 7, 24, hour: 10),
                showsDueDate: true,
                isOverdue: false,
                now: now,
                calendar: calendar
            ),
            .overdue
        )
        XCTAssertEqual(
            HomeTicketDeadlineUrgency.resolve(
                dueDate: .distantPast,
                showsDueDate: false,
                isOverdue: false,
                now: now,
                calendar: calendar
            ),
            .undated
        )
    }

    func testUndatedTicketPlanDoesNotEnterComingUp() {
        let plan = Plan(planKindKey: Plan.undatedTicketPlanKindKey)

        XCTAssertFalse(plan.hasConfirmedSchedule)
    }

    func testUndatedTicketRemainsManagedAndDoesNotDuplicateInHomeInterests() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let event = ExperienceEvent(
            title: "星屑の航路",
            stateKey: "interested",
            category: category
        )
        let plan = Plan(
            title: event.title,
            planKindKey: Plan.undatedTicketPlanKindKey,
            category: category,
            event: event
        )
        let attempt = TicketAttempt(
            statusKey: "beforeApply",
            applyDeadlineAt: date(2026, 7, 31),
            plan: plan
        )
        plan.ticketAttempts = [attempt]

        let snapshot = HomeSnapshot.make(
            categories: [category],
            events: [event],
            visits: [],
            inboxItems: [],
            plans: [plan],
            personLinks: [],
            now: date(2026, 7, 1)
        )

        XCTAssertTrue(snapshot.upcomingItems.isEmpty)
        XCTAssertTrue(snapshot.interestedEvents.isEmpty)
        XCTAssertEqual(CategoryTicketProgressItem.activeItems(in: [plan], categoryID: category.id).count, 1)
    }

    func testHomePickupLimitsEachLifecycleToNewestTenItems() {
        let now = date(2026, 7, 24, hour: 12)
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let interestedEvents = (0..<12).map { index in
            ExperienceEvent(
                title: "気になる\(index)",
                stateKey: "interested",
                updatedAt: Calendar.current.date(byAdding: .minute, value: -index, to: now)!,
                category: category
            )
        }
        let plans = (0..<12).map { index in
            let start = Calendar.current.date(byAdding: .day, value: index + 1, to: now)!
            return Plan(
                title: "予定\(index)",
                startsAt: start,
                endsAt: start,
                category: category
            )
        }
        let visits = (0..<12).reversed().map { index in
            let visitedAt = Calendar.current.date(byAdding: .day, value: -(index + 1), to: now)!
            let event = ExperienceEvent(title: "記録\(index)", category: category)
            return Visit(visitedAt: visitedAt, endedAt: visitedAt, event: event)
        }

        let snapshot = HomeSnapshot.make(
            categories: [category],
            events: interestedEvents,
            visits: visits,
            inboxItems: [],
            plans: plans,
            personLinks: [],
            now: now
        )

        XCTAssertEqual(snapshot.interestedEvents.count, 10)
        XCTAssertEqual(snapshot.upcomingItems.count, 10)
        XCTAssertEqual(snapshot.pickupRecordedVisits.count, 10)
        XCTAssertEqual(snapshot.interestedEvents.first?.title, "気になる0")
        XCTAssertEqual(snapshot.upcomingItems.first?.startsAt, plans[0].startsAt)
        XCTAssertEqual(snapshot.pickupRecordedVisits.first?.title, "記録0")
    }

    func testHomeComingUpPrefersOpeningTimeAndFallsBackToPerformanceTime() {
        let category = RecordCategory(name: "観劇", templateKey: "theater")
        let openingTime = date(2026, 7, 24, hour: 17)
        let performanceTime = date(2026, 7, 24, hour: 18)
        let plan = Plan(
            startsAt: performanceTime,
            opensAt: openingTime,
            category: category
        )

        XCTAssertEqual(
            HomePlanSnapshot(plan: plan).comingUpTimeText,
            "開場 \(FavorecoDateText.time(openingTime))"
        )

        plan.opensAt = .distantPast

        XCTAssertEqual(
            HomePlanSnapshot(plan: plan).comingUpTimeText,
            "開演 \(FavorecoDateText.time(performanceTime))"
        )
    }

    func testHomeComingUpDoesNotUsePerformanceCopyForOtherGenres() {
        let category = RecordCategory(name: "ミュージアム", templateKey: "museum")
        let plan = Plan(
            startsAt: date(2026, 7, 24, hour: 10),
            opensAt: .distantPast,
            category: category
        )

        XCTAssertEqual(HomePlanSnapshot(plan: plan).comingUpTimeText, "")
    }

    func testLotteryProgressUsesApplicationResultPaymentAndAcquisition() {
        let plan = Plan()
        let attempt = TicketAttempt(
            statusKey: "waitingPayment",
            entryRouteKey: "fanClub",
            applyDeadlineAt: date(2026, 7, 1),
            resultAnnounceAt: date(2026, 7, 3),
            paymentDeadlineAt: date(2026, 7, 5),
            plan: plan
        )

        let stages = TicketProgressTimeline.stages(for: attempt, plan: plan)

        XCTAssertEqual(stages.map(\.title), ["申込", "当落", "入金", "取得"])
        XCTAssertEqual(TicketProgressTimeline.currentIndex(for: attempt, stages: stages), 2)
    }

    func testChangingPastStageDatesDoesNotRollBackCurrentProgress() {
        let plan = Plan()
        let attempt = TicketAttempt(
            statusKey: "waitingPayment",
            entryRouteKey: "fanClub",
            applyDeadlineAt: date(2026, 7, 1),
            resultAnnounceAt: date(2026, 7, 3),
            paymentDeadlineAt: date(2026, 7, 5),
            plan: plan
        )

        let initialStages = TicketProgressTimeline.stages(for: attempt, plan: plan)
        XCTAssertEqual(TicketProgressTimeline.currentIndex(for: attempt, stages: initialStages), 2)

        attempt.applyDeadlineAt = date(2026, 8, 10)
        attempt.resultAnnounceAt = date(2026, 8, 12)

        let editedStages = TicketProgressTimeline.stages(for: attempt, plan: plan)
        XCTAssertEqual(attempt.statusKey, "waitingPayment")
        XCTAssertEqual(TicketProgressTimeline.currentIndex(for: attempt, stages: editedStages), 2)
    }

    func testIssuedProgressCompletesAcquisitionStage() {
        let plan = Plan()
        let attempt = TicketAttempt(
            statusKey: "issued",
            entryRouteKey: "fanClub",
            applyDeadlineAt: date(2026, 7, 1),
            resultAnnounceAt: date(2026, 7, 3),
            paidAt: date(2026, 7, 5),
            issuedAt: date(2026, 7, 6),
            plan: plan
        )

        let stages = TicketProgressTimeline.stages(for: attempt, plan: plan)

        XCTAssertEqual(stages.map(\.title), ["申込", "当落", "入金", "取得"])
        XCTAssertEqual(TicketProgressTimeline.currentIndex(for: attempt, stages: stages), stages.count)
    }

    func testTicketIsUnacquiredUntilAnIssuedAttemptExists() {
        XCTAssertFalse(TicketAcquisitionState.hasAcquiredTicket(in: []))
        XCTAssertFalse(
            TicketAcquisitionState.hasAcquiredTicket(
                in: [
                    TicketAttempt(statusKey: "lost"),
                    TicketAttempt(statusKey: "waitingPayment"),
                ]
            )
        )
        XCTAssertTrue(
            TicketAcquisitionState.hasAcquiredTicket(
                in: [
                    TicketAttempt(statusKey: "lost"),
                    TicketAttempt(statusKey: "issued"),
                ]
            )
        )
    }

    func testDirectPurchaseProgressOmitsLotteryAndPaymentWhenUnused() {
        let plan = Plan()
        let attempt = TicketAttempt(
            statusKey: "onSaleSoon",
            entryRouteKey: "general",
            saleStartAt: date(2026, 7, 1),
            plan: plan
        )

        let stages = TicketProgressTimeline.stages(for: attempt, plan: plan)

        XCTAssertEqual(stages.map(\.title), ["発売", "取得"])
        XCTAssertEqual(stages.first?.date, date(2026, 7, 1))
    }

    func testApplicationStartNotificationUsesSaleCopyForDirectPurchase() {
        let attempt = TicketAttempt(
            statusKey: "onSaleSoon",
            entryRouteKey: "general",
            saleStartAt: date(2026, 7, 1)
        )

        let copy = TicketNotificationScheduler.applicationStartNotificationCopy(
            attempt: attempt,
            planTitle: "月影のアトリエ"
        )

        XCTAssertEqual(copy.title, "発売開始")
        XCTAssertEqual(copy.body, "月影のアトリエ のチケット発売が始まります。")
    }

    func testApplicationStartNotificationKeepsApplicationCopyForLottery() {
        let attempt = TicketAttempt(
            statusKey: "beforeApply",
            entryRouteKey: "fanClub",
            saleStartAt: date(2026, 7, 1)
        )

        let copy = TicketNotificationScheduler.applicationStartNotificationCopy(
            attempt: attempt,
            planTitle: "星屑の航路"
        )

        XCTAssertEqual(copy.title, "申込開始")
        XCTAssertEqual(copy.body, "星屑の航路 の申込が始まります。")
    }

    func testHomeNextActionFollowsCurrentTicketStatus() {
        let now = date(2026, 7, 1)
        let attempt = TicketAttempt(
            statusKey: "beforeApply",
            entryRouteKey: "fanClub",
            saleStartAt: date(2026, 7, 2),
            applyDeadlineAt: date(2026, 7, 3),
            resultAnnounceAt: date(2026, 7, 4),
            paymentDeadlineAt: date(2026, 7, 5),
            issueStartAt: date(2026, 7, 6)
        )

        XCTAssertEqual(TicketNextActionDefinition.nextAction(for: attempt, now: now)?.title, "申込・発売開始")

        attempt.statusKey = "waitingResult"
        XCTAssertEqual(TicketNextActionDefinition.nextAction(for: attempt, now: now)?.title, "当落発表")

        attempt.statusKey = "waitingPayment"
        XCTAssertEqual(TicketNextActionDefinition.nextAction(for: attempt, now: now)?.title, "入金締切")

        attempt.statusKey = "waitingIssue"
        XCTAssertEqual(TicketNextActionDefinition.nextAction(for: attempt, now: now)?.title, "チケット受取開始")
    }

    func testAcquisitionPromptsOnlyWhenAttendanceDateIsUndated() {
        let undatedPlan = Plan(planKindKey: Plan.undatedTicketPlanKindKey)
        let scheduledPlan = Plan(planKindKey: "performance")

        XCTAssertTrue(
            TicketAttendanceScheduleRequirement.shouldPrompt(
                afterTransitionTo: "issued",
                plan: undatedPlan
            )
        )
        XCTAssertFalse(
            TicketAttendanceScheduleRequirement.shouldPrompt(
                afterTransitionTo: "issued",
                plan: scheduledPlan
            )
        )
        XCTAssertFalse(
            TicketAttendanceScheduleRequirement.shouldPrompt(
                afterTransitionTo: "waitingIssue",
                plan: undatedPlan
            )
        )
    }

    func testAdmissionPreparationStartsTwoDaysBeforeTicketedPlan() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = date(2026, 7, 23, hour: 18)
        let plan = Plan(
            startsAt: start,
            endsAt: start.addingTimeInterval(7_200)
        )
        plan.ticketAttempts = [
            TicketAttempt(statusKey: "issued", plan: plan)
        ]

        XCTAssertFalse(
            plan.needsAdmissionPreparationConfirmation(
                now: date(2026, 7, 20, hour: 12),
                calendar: calendar
            )
        )
        XCTAssertTrue(
            plan.needsAdmissionPreparationConfirmation(
                now: date(2026, 7, 21, hour: 0),
                calendar: calendar
            )
        )
    }

    func testAdmissionPreparationSnoozeAndConfirmationArePreserved() {
        let confirmedAt = date(2026, 7, 21, hour: 12)
        let snoozedUntil = date(2026, 7, 22, hour: 9)
        let fields = PlanPreparationFields(
            admissionPreparationConfirmedAt: confirmedAt,
            admissionPreparationSnoozedUntil: snoozedUntil
        )

        let restored = PlanPreparationFields(rawValue: fields.encodedRawValue)

        XCTAssertEqual(restored.admissionPreparationConfirmedAt, confirmedAt)
        XCTAssertEqual(restored.admissionPreparationSnoozedUntil, snoozedUntil)
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }
}
