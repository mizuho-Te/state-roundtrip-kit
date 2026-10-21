import Foundation

/// Strings are compared exactly: callers choose their own canonical date/number representation.
public struct Record: Codable, Equatable {
    public let id: String
    public let fields: [String: String]
    public init(id: String, fields: [String: String]) { self.id = id; self.fields = fields }
}

public enum SnapshotError: Error, Equatable { case emptyID, duplicateID }
public struct Snapshot: Equatable {
    public let records: [Record]
    public init(records: [Record]) throws {
        guard records.allSatisfy({ !$0.id.isEmpty }) else { throw SnapshotError.emptyID }
        guard Set(records.map(\.id)).count == records.count else { throw SnapshotError.duplicateID }
        self.records = records
    }
}

/// Contains no original IDs, field names or values, so default diagnostics are safe to print.
public struct Difference: Equatable {
    public enum Kind: String { case count, missingRecord, unexpectedRecord, missingField, unexpectedField, changedValue }
    public let kind: Kind
    public let recordOrdinal: Int?
    public let fieldOrdinal: Int?
}
public struct Comparison: Equatable {
    public let expectedCount: Int
    public let actualCount: Int
    public let differences: [Difference]
    public var matches: Bool { differences.isEmpty }
    public var summary: String {
        "expected=\(expectedCount), actual=\(actualCount), differences=\(differences.count), matches=\(matches)"
    }
}

public enum SnapshotComparator {
    /// Ignores record order, but never ignores IDs, extra records, extra fields or empty strings.
    /// Diagnostic ordinals are positions in the sorted union, not IDs. Values are never logged.
    public static func compare(expected: Snapshot, actual: Snapshot) -> Comparison {
        let lhs = Dictionary(uniqueKeysWithValues: expected.records.map { ($0.id, $0.fields) })
        let rhs = Dictionary(uniqueKeysWithValues: actual.records.map { ($0.id, $0.fields) })
        var diffs: [Difference] = []
        if lhs.count != rhs.count { diffs.append(Difference(kind: .count, recordOrdinal: nil, fieldOrdinal: nil)) }
        for (index, id) in Set(lhs.keys).union(rhs.keys).sorted().enumerated() {
            guard let old = lhs[id] else {
                diffs.append(Difference(kind: .unexpectedRecord, recordOrdinal: index, fieldOrdinal: nil)); continue
            }
            guard let new = rhs[id] else {
                diffs.append(Difference(kind: .missingRecord, recordOrdinal: index, fieldOrdinal: nil)); continue
            }
            for (fieldIndex, field) in Set(old.keys).union(new.keys).sorted().enumerated() {
                let kind: Difference.Kind?
                if old[field] == nil { kind = .unexpectedField }
                else if new[field] == nil { kind = .missingField }
                else if old[field] != new[field] { kind = .changedValue }
                else { kind = nil }
                if let kind { diffs.append(Difference(kind: kind, recordOrdinal: index, fieldOrdinal: fieldIndex)) }
            }
        }
        return Comparison(expectedCount: lhs.count, actualCount: rhs.count, differences: diffs)
    }
}
