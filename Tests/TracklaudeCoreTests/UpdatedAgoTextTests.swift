import Foundation
import Testing
import TracklaudeCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func render(_ secondsAgo: TimeInterval?) -> String {
    UpdatedAgoText.render(fetchedAt: secondsAgo.map { now.addingTimeInterval(-$0) }, now: now)
}

@Test("the footer counts seconds since the Snapshot was fetched")
func seconds() {
    #expect(render(0) == "Updated 0 s ago")
    #expect(render(12) == "Updated 12 s ago")
    #expect(render(59.9) == "Updated 59 s ago")
}

@Test("from a minute on the footer counts minutes, then hours")
func minutesAndHours() {
    #expect(render(60) == "Updated 1 min ago")
    #expect(render(59 * 60 + 59) == "Updated 59 min ago")
    #expect(render(3600) == "Updated 1 h ago")
    #expect(render(26 * 3600) == "Updated 26 h ago")
}

@Test("before the first Snapshot the footer says so instead of a fake age")
func noSnapshotYet() {
    #expect(render(nil) == "Not updated yet")
}

@Test("a Snapshot stamped in the future (clock skew) reads as 0 s, never negative")
func clockSkew() {
    #expect(render(-3) == "Updated 0 s ago")
}
