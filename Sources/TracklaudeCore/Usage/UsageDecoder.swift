import Foundation

public enum UsageDecodeError: Error, Equatable, Sendable {
    /// The body is not the usage JSON shape (e.g. an HTML error page).
    case notUsageJSON
}

/// Turns the usage endpoint's body into a Snapshot.
///
/// Lenient by design: every Window is optional and unknown keys are ignored, because the
/// response has already changed shape once (legacy per-model fields → `limits[]`) and the
/// app must keep showing what it can rather than blanking out on the next change.
public enum UsageDecoder {
    public static func decode(_ body: Data, fetchedAt: Date) throws -> Snapshot {
        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: body)
        } catch {
            throw UsageDecodeError.notUsageJSON
        }
        return Snapshot(
            fiveHour: wire.fiveHour?.window,
            sevenDay: wire.sevenDay?.window,
            perModel: perModelWindows(from: wire),
            fetchedAt: fetchedAt
        )
    }

    /// `limits[]` is the current source; the legacy `seven_day_opus` / `seven_day_sonnet`
    /// fields only fill in a model that `limits[]` does not already name.
    private static func perModelWindows(from wire: Wire) -> [ModelWindow] {
        let fromLimits = (wire.limits ?? []).compactMap { limit -> ModelWindow? in
            guard limit.kind == "weekly_scoped",
                  let model = limit.scope?.model?.displayName, !model.isEmpty,
                  let percent = limit.percent
            else { return nil }
            return ModelWindow(
                model: model,
                window: Window(utilization: percent, resetsAt: limit.resetsAt.flatMap(ISO8601.parse))
            )
        }
        let named = Set(fromLimits.map(\.model))
        let legacy: [(String, WireWindow?)] = [("Opus", wire.sevenDayOpus), ("Sonnet", wire.sevenDaySonnet)]
        let fromLegacy = legacy.compactMap { model, field -> ModelWindow? in
            // Why: Anthropic sends `{utilization: 0, resets_at: null}` for a model the
            // account has no Window for, so that exact pair means "absent", not "0%".
            guard !named.contains(model), let window = field?.window,
                  !(window.utilization == 0 && window.resetsAt == nil)
            else { return nil }
            return ModelWindow(model: model, window: window)
        }
        return (fromLimits + fromLegacy).sorted { $0.model < $1.model }
    }

    // Shape documented in research/usage4claude-study.md §5 (verified 2026-09-16).
    private struct Wire: Decodable {
        let fiveHour: WireWindow?
        let sevenDay: WireWindow?
        let sevenDayOpus: WireWindow?
        let sevenDaySonnet: WireWindow?
        let limits: [WireLimit]?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
            case sevenDayOpus = "seven_day_opus"
            case sevenDaySonnet = "seven_day_sonnet"
            case limits
        }
    }

    private struct WireLimit: Decodable {
        let kind: String?
        let percent: Double?
        let resetsAt: String?
        let scope: WireScope?

        enum CodingKeys: String, CodingKey {
            case kind, percent, scope
            case resetsAt = "resets_at"
        }
    }

    private struct WireScope: Decodable {
        let model: WireModel?
    }

    private struct WireModel: Decodable {
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    private struct WireWindow: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }

        var window: Window? {
            guard let utilization else { return nil }
            return Window(utilization: utilization, resetsAt: resetsAt.flatMap(ISO8601.parse))
        }
    }
}

/// `resets_at` arrives as ISO-8601 with fractional seconds; accept it without them too.
/// Truncated to the whole second: sub-second Reset precision means nothing to a `2h14m`
/// readout, and the fraction jitters between responses (observed 2026-09-16: `.83`, `.08`,
/// `.51` for the same Reset), so it must never be part of a Window's identity.
enum ISO8601 {
    static func parse(_ text: String) -> Date? {
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let plain = Date.ISO8601FormatStyle()
        guard let date = (try? style.parse(text)) ?? (try? plain.parse(text)) else { return nil }
        return Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
    }
}
