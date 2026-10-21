import Foundation

public enum Stage: String, CaseIterable, Codable {
    case prepare, launch, input, save, terminate, relaunch, readBack, compare
}
public enum StageStatus: String, Codable { case passed, failed, skipped }
public struct StageResult: Codable, Equatable {
    public let stage: Stage
    public let status: StageStatus
    /// Use fixed diagnostic codes, never text entered by users or raw error descriptions.
    public let diagnosticCode: String?
    public init(_ stage: Stage, _ status: StageStatus, diagnosticCode: String? = nil) {
        self.stage = stage; self.status = status; self.diagnosticCode = diagnosticCode
    }
}
public struct ScenarioReport {
    public let stages: [StageResult]
    public init(stages: [StageResult]) { self.stages = stages }
    /// Missing, duplicate, out-of-order, failed and skipped stages cannot yield success.
    public var passed: Bool {
        stages.map(\.stage) == Stage.allCases && stages.allSatisfy { $0.status == .passed }
    }
}
public struct FixtureID: Hashable, Codable {
    public let rawValue: String
    public init() { rawValue = "state-roundtrip-" + UUID().uuidString.lowercased() }
}

public enum FixtureDirectoryError: Error { case ownershipLost, unsafePath }
/// Owns only a newly-created, uniquely-named temporary directory. Never accepts an app data path.
/// Caller must prevent concurrent filesystem changes while using/cleaning up this directory.
public final class FixtureDirectory {
    public let id: FixtureID
    public let url: URL
    private let parent: URL
    private let marker: String
    private let manager = FileManager.default
    public init() throws {
        id = FixtureID()
        parent = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL
        url = parent.appendingPathComponent(id.rawValue, isDirectory: true)
        marker = UUID().uuidString
        try manager.createDirectory(at: url, withIntermediateDirectories: false)
        do { try Data(marker.utf8).write(to: url.appendingPathComponent(".test-owned"), options: .atomic) }
        catch { try? manager.removeItem(at: url); throw error }
    }
    /// Explicit opt-in; no automatic cleanup, app reset, recursive parent deletion or network access.
    public func cleanup() throws {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path == url.path,
              resolved.deletingLastPathComponent().path == parent.path,
              resolved.lastPathComponent == id.rawValue else { throw FixtureDirectoryError.unsafePath }
        let ownership = url.appendingPathComponent(".test-owned")
        guard ownership.resolvingSymlinksInPath().path == ownership.path,
              (try? Data(contentsOf: ownership)) == Data(marker.utf8) else {
            throw FixtureDirectoryError.ownershipLost
        }
        try manager.removeItem(at: url)
    }
}
