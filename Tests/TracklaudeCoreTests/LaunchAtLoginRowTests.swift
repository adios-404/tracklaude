import Testing
import TracklaudeCore

// Spec › Popover: a Launch at Login toggle that reflects what macOS reports (ticket 08).

@Test("registered with macOS reads as on, with nothing to explain")
func enabledIsOn() {
    #expect(LaunchAtLoginRow.render(status: .enabled) == LaunchAtLoginRow(isOn: true, note: nil, offersSystemSettings: false))
}

@Test("not registered reads as off, with nothing to explain")
func notRegisteredIsOff() {
    #expect(LaunchAtLoginRow.render(status: .notRegistered) == LaunchAtLoginRow(isOn: false, note: nil, offersSystemSettings: false))
}

@Test("awaiting the user's approval reads as on — they asked — and says where to approve it")
func requiresApprovalIsOnWithNote() {
    #expect(LaunchAtLoginRow.render(status: .requiresApproval) == LaunchAtLoginRow(
        isOn: true, note: "Waiting for approval in System Settings › Login Items.", offersSystemSettings: true
    ))
}

@Test("not found reads as plain off — macOS reports it for a main app never registered, and register() works from there (verified 2026-09-17)")
func notFoundIsOff() {
    #expect(LaunchAtLoginRow.render(status: .notFound) == LaunchAtLoginRow(isOn: false, note: nil, offersSystemSettings: false))
}

@Test("a failed register or unregister keeps the real status and shows the reason")
func failureShowsReason() {
    #expect(LaunchAtLoginRow.render(status: .notRegistered, failure: "Operation not permitted") == LaunchAtLoginRow(
        isOn: false, note: "Couldn't change Launch at Login: Operation not permitted", offersSystemSettings: false
    ))
}
