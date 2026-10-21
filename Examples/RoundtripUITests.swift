// Integration sample, excluded from Swift Package tests. See VALIDATION.txt for execution scope.
// Use the synthetic ValidationHost or copy into an iOS UI-test target and link StateRoundtripKit.
#if os(iOS)
import XCTest
import StateRoundtripKit

final class RoundtripUITests: XCTestCase {
    @MainActor func testSyntheticCardSurvivesRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let fixtureID = FixtureID().rawValue
        // The DEBUG-only host app must implement these arguments. XCTest does not do it for you.
        // Use a new isolated store per fixtureID, PRESERVE that same store on subsequent launch,
        // disable sync/network, and expose a readiness flag only after isolation is established.
        app.launchArguments = ["--roundtrip-fixture", fixtureID]
        var stages = [StageResult(.prepare, .passed)]
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolated-ready"].waitForExistence(timeout: 10))
        stages.append(StageResult(.launch, .passed))
        let input = app.textFields["card.question"] // Change to textViews if the app uses TextEditor.
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        // Empty text fields may expose their placeholder as value to accessibility.
        XCTAssertNotEqual(input.placeholderValue, "Synthetic question", "Use a distinct placeholder")
        input.tap(); input.typeText("Synthetic question")
        let inputPredicate = NSPredicate(format: "value == %@", "Synthetic question")
        let inputExpectation = XCTNSPredicateExpectation(predicate: inputPredicate, object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [inputExpectation], timeout: 5), .completed)
        stages.append(StageResult(.input, .passed))
        // Editing must invalidate any previous acknowledgment before this Save operation.
        XCTAssertFalse(app.staticTexts["card.saved"].exists, "Stale save acknowledgment before Save")
        app.buttons["card.save"].tap()
        // Must be a new save-specific completion state, not a stale badge from launch.
        XCTAssertTrue(app.staticTexts["card.saved"].waitForExistence(timeout: 5))
        stages.append(StageResult(.save, .passed))
        app.terminate(); stages.append(StageResult(.terminate, .passed))
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolated-ready"].waitForExistence(timeout: 10))
        stages.append(StageResult(.relaunch, .passed))
        let restored = app.textFields["card.question"]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "value == %@", "Synthetic question")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: restored)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        let value = try XCTUnwrap(restored.value as? String)
        stages.append(StageResult(.readBack, .passed))
        // This verifies one selected field only. Full-store checks require a DEBUG export adapter
        // supplying ALL fixture records/IDs/fields. Do not call this a whole-database assertion.
        let expected = try Snapshot(records: [Record(id: fixtureID, fields: ["question": "Synthetic question"])])
        let actual = try Snapshot(records: [Record(id: fixtureID, fields: ["question": value])])
        let result = SnapshotComparator.compare(expected: expected, actual: actual)
        stages.append(StageResult(.compare, result.matches ? .passed : .failed))
        XCTAssertTrue(result.matches, result.summary)
        XCTAssertTrue(ScenarioReport(stages: stages).passed)
        // No deletion: clean only this fixture's store via your explicit DEBUG-only test helper.
    }
}
#endif
