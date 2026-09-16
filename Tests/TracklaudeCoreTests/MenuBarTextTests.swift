import Testing
import TracklaudeCore

@Test("menu bar shows an em dash when there is no 5-hour Window")
func noFiveHourWindowRendersDash() {
    #expect(MenuBarText.render(fiveHour: nil) == "—")
}
