import XCTest
import StateRoundtripKit

final class HostSafetyUITests: XCTestCase {
    @MainActor func testInputPredicateRejectsPartialValue() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--roundtrip-fixture", FixtureID().rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolated-ready"].waitForExistence(timeout: 10))
        let input = app.textFields["card.question"]
        input.tap()
        input.typeText("Partial")
        let predicate = NSPredicate(format: "value == %@", "Partial complete")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .timedOut)
        XCTAssertFalse(app.staticTexts["card.saved"].exists)
        app.terminate()
    }

    @MainActor func testEditingClearsPreviousSaveAcknowledgment() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--roundtrip-fixture", FixtureID().rawValue]
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolated-ready"].waitForExistence(timeout: 10))
        let input = app.textFields["card.question"]
        let saved = app.staticTexts["card.saved"]
        input.tap()
        input.typeText("First synthetic")
        XCTAssertFalse(saved.exists)
        app.buttons["card.save"].tap()
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        let firstGeneration = try XCTUnwrap(saved.value as? String)
        input.tap()
        input.typeText(" updated")
        XCTAssertFalse(saved.exists, "Editing must clear the previous save acknowledgment")
        app.buttons["card.save"].tap()
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        let secondGeneration = try XCTUnwrap(saved.value as? String)
        XCTAssertNotEqual(firstGeneration, secondGeneration)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolated-ready"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["card.question"].value as? String, "First synthetic updated")
        XCTAssertFalse(app.staticTexts["card.saved"].exists)
        app.terminate()
    }

    @MainActor func testMalformedFixtureIsRejected() {
        let app = XCUIApplication()
        app.launchArguments = ["--roundtrip-fixture", "../not-a-fixture"]
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolation-error"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["roundtrip.isolated-ready"].exists)
        XCTAssertFalse(app.textFields["card.question"].exists)
        app.terminate()
    }

    @MainActor func testUnsavedEditDoesNotSurviveRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        let id = FixtureID().rawValue
        app.launchArguments = ["--roundtrip-fixture", id]
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolated-ready"].waitForExistence(timeout: 10))
        let input = app.textFields["card.question"]
        input.tap()
        input.typeText("Unsaved synthetic question")
        XCTAssertFalse(app.staticTexts["card.saved"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["roundtrip.isolated-ready"].waitForExistence(timeout: 10))
        let restored = try XCTUnwrap(app.textFields["card.question"].value as? String)
        // UITextField returns its placeholder as the accessibility value when empty.
        XCTAssertEqual(restored, "Enter synthetic question")
        let expectedSaved = try Snapshot(records: [Record(id: id, fields: ["question": "Unsaved synthetic question"])])
        let actual = try Snapshot(records: [Record(id: id, fields: ["question": restored])])
        XCTAssertFalse(SnapshotComparator.compare(expected: expectedSaved, actual: actual).matches)
        XCTAssertFalse(app.staticTexts["card.saved"].exists)
        app.terminate()
    }
}
