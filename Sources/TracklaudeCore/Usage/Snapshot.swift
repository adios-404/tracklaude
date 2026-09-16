import Foundation

/// One rate-limit bucket (see CONTEXT.md): how much is used and when it Resets.
public struct Window: Equatable, Sendable {
    /// 0–100.
    public let utilization: Double
    /// `nil` when Anthropic reports the Window without a Reset.
    public let resetsAt: Date?

    public init(utilization: Double, resetsAt: Date?) {
        self.utilization = utilization
        self.resetsAt = resetsAt
    }
}

/// A per-model 7-day Window, named by the model's display name (e.g. "Opus").
public struct ModelWindow: Equatable, Sendable {
    public let model: String
    public let window: Window

    public init(model: String, window: Window) {
        self.model = model
        self.window = window
    }
}

/// One successful fetch of every Window at a point in time (see CONTEXT.md).
public struct Snapshot: Equatable, Sendable {
    public let fiveHour: Window?
    public let sevenDay: Window?
    /// Only the per-model Windows Anthropic actually reported, sorted by model name.
    public let perModel: [ModelWindow]
    public let fetchedAt: Date

    public init(fiveHour: Window?, sevenDay: Window?, perModel: [ModelWindow] = [], fetchedAt: Date) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.perModel = perModel
        self.fetchedAt = fetchedAt
    }
}
