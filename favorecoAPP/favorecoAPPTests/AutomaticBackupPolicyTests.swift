import XCTest
@testable import favoreco

final class AutomaticBackupPolicyTests: XCTestCase {
    func testAutomaticBackupSkipsWhenDisabled() {
        let request = makeRequest(isEnabled: false, canUseSyncFeatures: true)

        XCTAssertEqual(AutomaticBackupPolicy.skipStatus(for: request), .skippedDisabled)
    }

    func testAutomaticBackupSkipsWithoutEntitlement() {
        let request = makeRequest(isEnabled: true, canUseSyncFeatures: false)

        XCTAssertEqual(AutomaticBackupPolicy.skipStatus(for: request), .skippedDisabled)
    }

    func testAutomaticBackupSkipsBeforeIntervalElapses() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let request = makeRequest(
            now: now,
            lastCreatedAt: now.addingTimeInterval(-(AutomaticBackupService.interval - 1))
        )

        XCTAssertEqual(AutomaticBackupPolicy.skipStatus(for: request), .skippedNotDue)
    }

    func testAutomaticBackupRunsAtIntervalBoundary() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let request = makeRequest(
            now: now,
            lastCreatedAt: now.addingTimeInterval(-AutomaticBackupService.interval)
        )

        XCTAssertNil(AutomaticBackupPolicy.skipStatus(for: request))
    }

    func testManualBackupIgnoresAutomaticEligibility() {
        let request = AutomaticBackupRequest(
            mode: .manual,
            now: Date(timeIntervalSince1970: 2_000_000),
            isEnabled: false,
            canUseSyncFeatures: false,
            usesICloudDrive: false,
            lastCreatedAt: Date()
        )

        XCTAssertNil(AutomaticBackupPolicy.skipStatus(for: request))
    }

    func testRetentionCountRespondsToPhotoVolume() {
        XCTAssertEqual(AutomaticBackupService.retentionCount(forPhotoBytes: 499_999_999), 5)
        XCTAssertEqual(AutomaticBackupService.retentionCount(forPhotoBytes: 500_000_000), 3)
        XCTAssertEqual(AutomaticBackupService.retentionCount(forPhotoBytes: 1_000_000_000), 2)
    }

    private func makeRequest(
        now: Date = Date(timeIntervalSince1970: 2_000_000),
        isEnabled: Bool = true,
        canUseSyncFeatures: Bool = true,
        lastCreatedAt: Date? = nil
    ) -> AutomaticBackupRequest {
        AutomaticBackupRequest(
            mode: .automatic,
            now: now,
            isEnabled: isEnabled,
            canUseSyncFeatures: canUseSyncFeatures,
            usesICloudDrive: false,
            lastCreatedAt: lastCreatedAt
        )
    }
}
