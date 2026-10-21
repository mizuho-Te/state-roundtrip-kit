import Foundation
import XCTest
@testable import StateRoundtripKit

final class StateRoundtripKitTests: XCTestCase {
    func snapshot(_ records: Record...) throws -> Snapshot { try Snapshot(records: records) }
    func testReorderedRecordsMatch() throws {
        let a = Record(id: "a", fields: ["amount": "100"])
        let b = Record(id: "b", fields: ["question": "Synthetic?"])
        XCTAssertTrue(SnapshotComparator.compare(expected: try snapshot(a, b), actual: try snapshot(b, a)).matches)
    }
    func testChangedValueFails() throws {
        let result = SnapshotComparator.compare(expected: try snapshot(Record(id: "a", fields: ["amount": "100"])), actual: try snapshot(Record(id: "a", fields: ["amount": "101"])))
        XCTAssertEqual(result.differences.map(\.kind), [.changedValue])
    }
    func testSameCountDifferentIDsFails() throws {
        let result = SnapshotComparator.compare(expected: try snapshot(Record(id: "a", fields: [:])), actual: try snapshot(Record(id: "b", fields: [:])))
        XCTAssertEqual(result.differences.map(\.kind), [.missingRecord, .unexpectedRecord])
    }
    func testEmptyIsNotMissingField() throws {
        let result = SnapshotComparator.compare(expected: try snapshot(Record(id: "a", fields: ["memo": ""])), actual: try snapshot(Record(id: "a", fields: [:])))
        XCTAssertEqual(result.differences.map(\.kind), [.missingField])
    }
    func testExtraFieldFails() throws {
        let result = SnapshotComparator.compare(expected: try snapshot(Record(id: "a", fields: [:])), actual: try snapshot(Record(id: "a", fields: ["extra": "x"])))
        XCTAssertEqual(result.differences.map(\.kind), [.unexpectedField])
    }
    func testCountsAndExtraRecords() throws {
        let result = SnapshotComparator.compare(expected: try snapshot(), actual: try snapshot(Record(id: "x", fields: [:])))
        XCTAssertFalse(result.matches)
        XCTAssertEqual(result.expectedCount, 0)
        XCTAssertEqual(result.actualCount, 1)
        XCTAssertEqual(result.differences.map(\.kind), [.count, .unexpectedRecord])
    }
    func testDuplicateIDRejected() {
        XCTAssertThrowsError(try snapshot(Record(id: "x", fields: [:]), Record(id: "x", fields: [:]))) {
            XCTAssertEqual($0 as? SnapshotError, .duplicateID)
        }
    }
    func testEmptyIDRejected() {
        XCTAssertThrowsError(try snapshot(Record(id: "", fields: [:])))
    }
    func testDiagnosticsContainNoSourceStrings() throws {
        let result = SnapshotComparator.compare(expected: try snapshot(Record(id: "secret-id", fields: ["secret-key": "secret-value"])), actual: try snapshot())
        let output = String(describing: result) + result.summary
        for secret in ["secret-id", "secret-key", "secret-value"] { XCTAssertFalse(output.contains(secret)) }
    }
    func testCompleteStagesOnlyPass() {
        let all = Stage.allCases.map { StageResult($0, .passed) }
        XCTAssertTrue(ScenarioReport(stages: all).passed)
        XCTAssertFalse(ScenarioReport(stages: []).passed)
        XCTAssertFalse(ScenarioReport(stages: Array(all.dropLast())).passed)
        XCTAssertFalse(ScenarioReport(stages: all + [all[0]]).passed)
        XCTAssertFalse(ScenarioReport(stages: Array(all.reversed())).passed)
        XCTAssertFalse(ScenarioReport(stages: Stage.allCases.map { StageResult($0, $0 == .save ? .skipped : .passed) }).passed)
        XCTAssertFalse(ScenarioReport(stages: Stage.allCases.map { StageResult($0, $0 == .save ? .failed : .passed) }).passed)
    }
    func testUniqueFixturesAndExplicitCleanup() throws {
        let a = try FixtureDirectory(); let b = try FixtureDirectory()
        XCTAssertNotEqual(a.id, b.id)
        try Data("synthetic".utf8).write(to: a.url.appendingPathComponent("ledger.json"))
        try a.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: a.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.url.path))
        try b.cleanup()
    }
    func testMissingOwnershipRefusesCleanup() throws {
        let fixture = try FixtureDirectory()
        let marker = fixture.url.appendingPathComponent(".test-owned")
        let data = try Data(contentsOf: marker)
        try FileManager.default.removeItem(at: marker)
        XCTAssertThrowsError(try fixture.cleanup())
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.url.path))
        try data.write(to: marker)
        try fixture.cleanup()
    }
    func testSymlinkReplacementRefusesCleanup() throws {
        let fixture = try FixtureDirectory(); let target = try FixtureDirectory()
        let original = fixture.url.appendingPathExtension("backup")
        try FileManager.default.moveItem(at: fixture.url, to: original)
        try FileManager.default.createSymbolicLink(at: fixture.url, withDestinationURL: target.url)
        XCTAssertThrowsError(try fixture.cleanup())
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.url.path))
        try FileManager.default.removeItem(at: fixture.url)
        try FileManager.default.moveItem(at: original, to: fixture.url)
        try fixture.cleanup(); try target.cleanup()
    }
    func testSyntheticLedgerAndCardRoundtrip() throws {
        let fixture = try FixtureDirectory(); defer { try? fixture.cleanup() }
        let records = [Record(id: fixture.id.rawValue + "-ledger", fields: ["amountMinorUnits": "1234", "memo": "SYNTHETIC ONLY"]), Record(id: fixture.id.rawValue + "-card", fields: ["question": "2 + 2?", "answer": "4", "approved": "false"])]
        let file = fixture.url.appendingPathComponent("fixture.json")
        try JSONEncoder().encode(records).write(to: file, options: .atomic)
        let decoded = try JSONDecoder().decode([Record].self, from: Data(contentsOf: file))
        XCTAssertTrue(SnapshotComparator.compare(expected: try Snapshot(records: records), actual: try Snapshot(records: decoded)).matches)
    }
}
