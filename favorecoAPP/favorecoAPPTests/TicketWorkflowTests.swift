import XCTest
@testable import favoreco

@MainActor
final class TicketWorkflowTests: XCTestCase {
    func testTicketGuideSuggestionsFindRegisteredGuideByShortNameAndAlias() {
        XCTAssertEqual(
            TicketGuideDefinition.suggestions(matching: "ぴあ").first?.key,
            "pia"
        )
        XCTAssertTrue(
            TicketGuideDefinition.suggestions(matching: "ローチケ")
                .contains(where: { $0.key == "lawson" })
        )
        XCTAssertEqual(
            TicketGuideDefinition.suggestions(matching: "パスマーケット").first?.key,
            "passmarket"
        )
    }

    func testTicketGuideSuggestionsExcludeBlankShortAndCustomEntries() {
        XCTAssertTrue(TicketGuideDefinition.suggestions(matching: "").isEmpty)
        XCTAssertTrue(TicketGuideDefinition.suggestions(matching: "e").isEmpty)
        XCTAssertFalse(
            TicketGuideDefinition.suggestions(matching: "その他")
                .contains(where: { $0.key == TicketGuideDefinition.customKey })
        )
    }

    func testPostAcquisitionDetailsPromptOnlyOffersForMissingPurchaseDetails() {
        let attempt = TicketAttempt(statusKey: "waitingPayment")

        XCTAssertTrue(
            TicketPostAcquisitionDetailsPrompt.shouldOffer(
                for: attempt,
                afterTransitionTo: "waitingIssue"
            )
        )
        XCTAssertTrue(
            TicketPostAcquisitionDetailsPrompt.shouldOffer(
                for: attempt,
                afterTransitionTo: "issued"
            )
        )
        XCTAssertFalse(
            TicketPostAcquisitionDetailsPrompt.shouldOffer(
                for: attempt,
                afterTransitionTo: "waitingResult"
            )
        )

        attempt.price = Decimal(12_000)
        attempt.seatText = "1階 10列 12番"
        XCTAssertFalse(
            TicketPostAcquisitionDetailsPrompt.shouldOffer(
                for: attempt,
                afterTransitionTo: "issued"
            )
        )
    }

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

    func testOngoingPlanRemainsInComingUpUntilItsEndTime() {
        let now = date(2026, 8, 6, hour: 23, minute: 48)
        let ongoingPlan = Plan(
            startsAt: date(2026, 8, 6, hour: 23, minute: 20),
            endsAt: date(2026, 8, 7, hour: 1, minute: 20)
        )
        let finishedPlan = Plan(
            startsAt: date(2026, 8, 6, hour: 20),
            endsAt: date(2026, 8, 6, hour: 22)
        )
        let undatedPlan = Plan(planKindKey: Plan.undatedTicketPlanKindKey)

        XCTAssertTrue(ongoingPlan.isUpcomingOrOngoing(at: now))
        XCTAssertFalse(finishedPlan.isUpcomingOrOngoing(at: now))
        XCTAssertFalse(undatedPlan.isUpcomingOrOngoing(at: now))
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

    func testUndatedOverviewFilterMatchesOnlyActiveTicketsWithoutSchedule() {
        let undatedPlan = Plan(planKindKey: Plan.undatedTicketPlanKindKey)
        let datedPlan = Plan(startsAt: date(2026, 8, 12), endsAt: date(2026, 8, 12))

        XCTAssertTrue(
            TicketOverviewFilter.undated.includes(
                TicketAttempt(statusKey: "beforeApply", plan: undatedPlan)
            )
        )
        XCTAssertFalse(
            TicketOverviewFilter.undated.includes(
                TicketAttempt(statusKey: "beforeApply", plan: datedPlan)
            )
        )
        XCTAssertFalse(
            TicketOverviewFilter.undated.includes(
                TicketAttempt(statusKey: "lost", plan: undatedPlan)
            )
        )
        XCTAssertFalse(
            TicketOverviewFilter.undated.includes(
                TicketAttempt(statusKey: "attended", plan: undatedPlan)
            )
        )
    }

    func testNeedsActionFilterIncludesHomeStatusFallbacks() {
        XCTAssertTrue(
            TicketOverviewFilter.needsAction.includes(
                TicketAttempt(statusKey: "won")
            )
        )
        XCTAssertTrue(
            TicketOverviewFilter.needsAction.includes(
                TicketAttempt(statusKey: "waitingIssue")
            )
        )
    }

    func testWonWithoutPaymentDeadlineReportsInputIssue() {
        let attempt = TicketAttempt(
            statusKey: "won",
            paymentDeadlineAt: .distantPast
        )

        XCTAssertEqual(
            TicketInputIssueDefinition.issue(for: attempt)?.title,
            "支払締切を設定"
        )
    }

    func testHomeTicketScheduleCollapsedAndExpandedCounts() {
        XCTAssertEqual(HomeAttentionDisplay.visibleCount(total: 0, isExpanded: false), 0)
        XCTAssertEqual(HomeAttentionDisplay.visibleCount(total: 1, isExpanded: false), 1)
        XCTAssertEqual(HomeAttentionDisplay.visibleCount(total: 4, isExpanded: false), 3)
        XCTAssertEqual(HomeAttentionDisplay.visibleCount(total: 4, isExpanded: true), 4)
        XCTAssertEqual(HomeAttentionDisplay.hiddenCount(total: 4), 1)
        XCTAssertEqual(HomeAttentionDisplay.hiddenCount(total: 12), 9)
    }

    func testTicketManagementVisualStagesUseTheAiryPalette() {
        XCTAssertEqual(
            TicketProgressColorPalette.visualStage(forDeadlineLabel: "抽選申込"),
            .application
        )
        XCTAssertEqual(
            TicketProgressColorPalette.visualStage(forDeadlineLabel: "チケ発売"),
            .sale
        )
        XCTAssertEqual(
            TicketProgressColorPalette.visualStage(forDeadlineLabel: "抽選当落"),
            .result
        )
        XCTAssertEqual(
            TicketProgressColorPalette.visualStage(forDeadlineLabel: "チケ支払"),
            .payment
        )
        XCTAssertEqual(
            TicketProgressColorPalette.visualStage(forDeadlineLabel: "チケ受取"),
            .acquired
        )
        XCTAssertEqual(
            TicketProgressColorPalette.visualStage(forDeadlineLabel: "参加日"),
            .acquired
        )
        XCTAssertNil(TicketProgressColorPalette.visualStage(forDeadlineLabel: "チケット"))

        XCTAssertEqual(TicketProgressVisualStage.application.surfaceHex, "#D5F3F8")
        XCTAssertEqual(TicketProgressVisualStage.sale.surfaceHex, "#DDEFFC")
        XCTAssertEqual(TicketProgressVisualStage.result.surfaceHex, "#F8D8E2")
        XCTAssertEqual(TicketProgressVisualStage.payment.surfaceHex, "#F8E9BB")
        XCTAssertEqual(TicketProgressVisualStage.acquired.surfaceHex, "#D7F1E7")
        XCTAssertEqual(TicketProgressVisualStage.result.accentHex, "#B34769")
    }

    func testCombinedEntryActionUsesSavedLotteryOrSaleFlow() {
        let lotteryAttempt = TicketAttempt(
            statusKey: "beforeApply",
            entryRouteKey: "card"
        )
        let saleAttempt = TicketAttempt(
            statusKey: "onSaleSoon",
            entryRouteKey: "general"
        )

        XCTAssertEqual(
            TicketProgressPresentation.deadlineLabel(
                forActionTitle: "申込・発売開始",
                attempt: lotteryAttempt
            ),
            "抽選申込"
        )
        XCTAssertEqual(
            TicketProgressPresentation.deadlineLabel(
                forActionTitle: "申込・発売開始",
                attempt: saleAttempt
            ),
            "チケ発売"
        )
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

        XCTAssertEqual(stages.map(\.title), ["申込", "当落", "支払", "受取"])
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

        XCTAssertEqual(stages.map(\.title), ["申込", "当落", "支払", "受取"])
        XCTAssertEqual(TicketProgressTimeline.currentIndex(for: attempt, stages: stages), stages.count)
    }

    func testIssuedTicketSchedulesNoCompletedMilestoneNotifications() {
        XCTAssertTrue(
            TicketNotificationScheduler.scheduledMilestoneKeys(for: "issued").isEmpty
        )
        XCTAssertEqual(
            TicketNotificationScheduler.scheduledMilestoneKeys(for: "waitingPayment"),
            ["paymentDeadline", "ticketIssue"]
        )
        XCTAssertEqual(
            TicketNotificationScheduler.scheduledMilestoneKeys(for: "waitingResult"),
            ["lotteryResult", "paymentDeadline", "ticketIssue"]
        )
    }

    func testScheduleCorrectionMovesIncompleteProgressBackButPreservesAcquiredStatus() {
        let plan = Plan()
        let attempt = TicketAttempt(
            statusKey: "waitingPayment",
            entryRouteKey: "fanClub",
            applyDeadlineAt: date(2026, 7, 31),
            resultAnnounceAt: date(2026, 8, 5),
            plan: plan
        )
        let now = date(2026, 7, 29)

        XCTAssertEqual(
            TicketProgressTimeline.reconciledStatusAfterScheduleEdit(
                currentStatusKey: "waitingPayment",
                attempt: attempt,
                now: now
            ),
            "beforeApply"
        )
        XCTAssertEqual(
            TicketProgressTimeline.reconciledStatusAfterScheduleEdit(
                currentStatusKey: "issued",
                attempt: attempt,
                now: now
            ),
            "issued"
        )
    }

    func testProgressDatesUseOnlyEditableScheduleDates() {
        let plan = Plan()
        let attempt = TicketAttempt(
            statusKey: "issued",
            entryRouteKey: "fanClub",
            applyDeadlineAt: date(2026, 7, 30),
            resultAnnounceAt: date(2026, 8, 13),
            paidAt: date(2026, 7, 27),
            issuedAt: date(2026, 7, 27),
            plan: plan
        )

        var stages = TicketProgressTimeline.stages(for: attempt, plan: plan)
        XCTAssertNil(stages.first(where: { $0.kind == .payment })?.date)
        XCTAssertNil(stages.first(where: { $0.kind == .acquired })?.date)

        attempt.paymentDeadlineAt = date(2026, 8, 15)
        attempt.issueStartAt = date(2026, 8, 20)
        stages = TicketProgressTimeline.stages(for: attempt, plan: plan)
        XCTAssertEqual(stages.first(where: { $0.kind == .payment })?.date, date(2026, 8, 15))
        XCTAssertEqual(stages.first(where: { $0.kind == .acquired })?.date, date(2026, 8, 20))

        attempt.paymentDeadlineAt = .distantPast
        attempt.issueStartAt = .distantPast
        stages = TicketProgressTimeline.stages(for: attempt, plan: plan)
        XCTAssertNil(stages.first(where: { $0.kind == .payment })?.date)
        XCTAssertNil(stages.first(where: { $0.kind == .acquired })?.date)
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

        XCTAssertEqual(stages.map(\.title), ["発売", "受取"])
        XCTAssertEqual(stages.first?.date, date(2026, 7, 1))
    }

    func testPaymentAndReceiptAreSeparateExplicitTransitions() {
        let resultAttempt = TicketAttempt(statusKey: "waitingResult")
        let legacyWonAttempt = TicketAttempt(statusKey: "won")
        let paymentAttempt = TicketAttempt(statusKey: "waitingPayment")
        let receiptAttempt = TicketAttempt(statusKey: "waitingIssue")

        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: resultAttempt).first?.targetStatusKey,
            "waitingPayment"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: resultAttempt).first?.title,
            "当選にする"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: legacyWonAttempt).first?.targetStatusKey,
            "waitingIssue"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: legacyWonAttempt).first?.title,
            "支払い済みにする"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: paymentAttempt).first?.targetStatusKey,
            "waitingIssue"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: paymentAttempt).first?.title,
            "支払い済みにする"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: receiptAttempt).first?.targetStatusKey,
            "issued"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.transitions(for: receiptAttempt).first?.title,
            "チケットを受け取った"
        )
    }

    func testCurrentStageLabelsExplainWhatTheUserIsWaitingFor() {
        XCTAssertEqual(
            TicketProgressPresentation.currentStageLabel(
                for: TicketAttempt(statusKey: "beforeApply", entryRouteKey: "card")
            ),
            "抽選申込"
        )
        XCTAssertEqual(
            TicketProgressPresentation.currentStageLabel(
                for: TicketAttempt(statusKey: "waitingResult", entryRouteKey: "card")
            ),
            "当落待ち"
        )
        XCTAssertEqual(
            TicketProgressPresentation.currentStageLabel(
                for: TicketAttempt(statusKey: "won", entryRouteKey: "card")
            ),
            "支払い待ち"
        )
        XCTAssertEqual(
            TicketProgressPresentation.currentStageLabel(
                for: TicketAttempt(statusKey: "waitingPayment", entryRouteKey: "card")
            ),
            "支払い待ち"
        )
        XCTAssertEqual(
            TicketProgressPresentation.currentStageLabel(
                for: TicketAttempt(statusKey: "waitingIssue", entryRouteKey: "card")
            ),
            "受取待ち"
        )
    }

    func testPreviousProgressStageRecoversFromMistakenResultAndReceipt() {
        let lotteryPlan = Plan()
        let lostAttempt = TicketAttempt(
            statusKey: "lost",
            entryRouteKey: "fanClub",
            plan: lotteryPlan
        )
        let issuedAttempt = TicketAttempt(
            statusKey: "issued",
            entryRouteKey: "fanClub",
            paymentDeadlineAt: date(2026, 8, 15),
            plan: lotteryPlan
        )

        XCTAssertEqual(
            TicketStatusTransitionDefinition.previousStatusKey(for: lostAttempt),
            "waitingResult"
        )
        XCTAssertEqual(
            TicketStatusTransitionDefinition.previousStatusKey(for: issuedAttempt),
            "waitingIssue"
        )
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

        XCTAssertEqual(copy.title, "🔔 一般販売通知")
        XCTAssertEqual(copy.body, "月影のアトリエ の一般販売が始まります。")
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

        XCTAssertEqual(copy.title, "🔔 抽選申込通知")
        XCTAssertEqual(copy.body, "星屑の航路 の抽選申込が始まります。")
    }

    func testTicketNotificationCopyExplainsLotteryDeadlineAndResult() {
        let deadline = TicketNotificationScheduler.applicationDeadlineNotificationCopy(
            planTitle: "月影のアトリエ"
        )
        let result = TicketNotificationScheduler.lotteryResultNotificationCopy(
            planTitle: "月影のアトリエ"
        )

        XCTAssertEqual(deadline.title, "🔔 抽選申込通知")
        XCTAssertEqual(deadline.body, "月影のアトリエ の抽選申込締切が近づいています。")
        XCTAssertEqual(result.title, "🔔 当落発表通知")
        XCTAssertEqual(result.body, "月影のアトリエ の当落発表日です。")
    }

    func testSaleNotificationUsesSelectedSaleMethod() {
        XCTAssertEqual(
            TicketNotificationScheduler.saleNotificationMethod(for: "presale"),
            "先行販売"
        )
        XCTAssertEqual(
            TicketNotificationScheduler.saleNotificationMethod(for: "sameDay"),
            "当日券販売"
        )
        XCTAssertEqual(
            TicketNotificationScheduler.saleNotificationMethod(for: "resale"),
            "リセール販売"
        )
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
        XCTAssertEqual(TicketNextActionDefinition.nextAction(for: attempt, now: now)?.title, "支払締切")

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

    func testApplicationCollectionNamesOneScheduleByEventDateAndVenue() {
        let event = ExperienceEvent(title: "あの夏")
        let plan = Plan(
            title: "あの夏",
            planKindKey: "performance",
            startsAt: date(2026, 7, 31),
            venueNameSnapshot: "東京劇場",
            event: event
        )

        XCTAssertEqual(
            TicketApplicationCollectionNaming.scheduleName(for: plan),
            "あの夏｜7/31 東京劇場"
        )
    }

    func testLegacyReceptionHeadingBecomesScheduleOrTourHeading() {
        let event = ExperienceEvent(title: "あの夏")
        let tokyo = Plan(
            title: "あの夏",
            planKindKey: "performance",
            startsAt: date(2026, 7, 31),
            venueNameSnapshot: "東京劇場",
            event: event
        )
        let osaka = Plan(
            title: "あの夏",
            planKindKey: "performance",
            startsAt: date(2026, 8, 7),
            venueNameSnapshot: "大阪劇場",
            event: event
        )
        let first = TicketAttempt(
            entryRouteKey: "official",
            ticketSite: "イープラス",
            plan: tokyo
        )
        let second = TicketAttempt(
            entryRouteKey: "official",
            ticketSite: "楽天チケット",
            plan: osaka
        )
        let legacyName = TicketApplicationCollectionNaming.legacyReceptionName(for: first)

        XCTAssertEqual(
            TicketApplicationCollectionNaming.displayName(
                storedName: legacyName,
                attempts: [first]
            ),
            "あの夏｜7/31 東京劇場"
        )
        XCTAssertEqual(
            TicketApplicationCollectionNaming.displayName(
                storedName: legacyName,
                attempts: [first, second]
            ),
            "あの夏｜ツアー申込"
        )
    }

    func testCustomApplicationCollectionNameIsPreserved() {
        let event = ExperienceEvent(title: "あの夏")
        let plan = Plan(
            title: "あの夏",
            planKindKey: "performance",
            startsAt: date(2026, 7, 31),
            event: event
        )
        let attempt = TicketAttempt(plan: plan)

        XCTAssertEqual(
            TicketApplicationCollectionNaming.displayName(
                storedName: "友人分とまとめる",
                attempts: [attempt]
            ),
            "友人分とまとめる"
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }
}
