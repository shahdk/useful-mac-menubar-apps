import Foundation

// Lightweight, dependency-free unit tests for UsageParser.
//
// Compiled with `swiftc Sources/UsageParser.swift Tests/UsageParserTests.swift`
// (Foundation only — no AppKit), run by ../test.sh and in CI. Uses a tiny
// hand-rolled assertion harness so there's nothing to install: any failure
// prints a message and the process exits non-zero.

@main
struct UsageParserTests {
    static var failures = 0
    static var checks = 0

    static func check(_ condition: Bool, _ message: String) {
        checks += 1
        if !condition {
            failures += 1
            FileHandle.standardError.write(Data("  ✘ \(message)\n".utf8))
        }
    }

    static func eq<T: Equatable>(_ actual: T, _ expected: T, _ label: String) {
        check(actual == expected, "\(label): expected \(expected), got \(actual)")
    }

    // MARK: - parseLine

    static func testParseLine() {
        let (pct, reset) = UsageParser.parseLine(
            "Current session: 37% used · resets Jul 29 at 12:59pm (America/Indianapolis)")
        eq(pct, 37, "parseLine session percent")
        eq(reset, "Jul 29 at 12:59pm (America/Indianapolis)", "parseLine reset text")

        // Case-insensitive "Resets" and 100%.
        let (pct2, reset2) = UsageParser.parseLine("Current week (all models): 100% used · Resets Aug 4")
        eq(pct2, 100, "parseLine 100%")
        eq(reset2, "Aug 4", "parseLine case-insensitive resets")

        // No percentage present → nil percent, but reset still parsed if present.
        let (pct3, reset3) = UsageParser.parseLine("Current session: unknown · resets soon")
        check(pct3 == nil, "parseLine missing percent is nil")
        eq(reset3, "soon", "parseLine reset without percent")

        // No "resets" keyword → nil reset.
        let (pct4, reset4) = UsageParser.parseLine("Current session: 5% used")
        eq(pct4, 5, "parseLine percent without reset")
        check(reset4 == nil, "parseLine missing reset is nil")
    }

    // MARK: - parse(output:)

    static func testParseFullOutput() {
        let output = """
        Using your Claude subscription.

        Current session: 42% used · resets Jul 29 at 3:00pm (UTC)
        Current week (all models): 8% used · resets Aug 4 at 12:00am (UTC)
        """
        let r = UsageParser.parse(output: output)
        eq(r.sessionPercent, 42, "parse session percent")
        eq(r.sessionReset, "Jul 29 at 3:00pm (UTC)", "parse session reset")
        eq(r.weekPercent, 8, "parse week percent")
        eq(r.weekReset, "Aug 4 at 12:00am (UTC)", "parse week reset")
        check(r.error == nil, "parse valid output has no error")
    }

    static func testCommandNotFound() {
        let r = UsageParser.parse(output: "zsh: command not found: claude")
        check(r.sessionPercent == nil, "not-found has no percent")
        check(r.error?.contains("not found") == true, "not-found error surfaced")
    }

    static func testApiKeyMode() {
        let r = UsageParser.parse(output: "Using an API key for authentication.\nNo session limits apply.")
        check(r.sessionPercent == nil, "api-key mode has no percent")
        check(r.error?.contains("API-key") == true, "api-key error surfaced")
    }

    static func testStaleSubscriptionCli() {
        // Subscription banner but no "Current session:" line → out-of-date hint.
        let r = UsageParser.parse(output: "Using your Claude subscription.\nSomething else entirely.")
        check(r.sessionPercent == nil, "stale cli has no percent")
        check(r.error?.contains("out of date") == true, "stale-cli error surfaced")
    }

    static func testUnrecognizedOutput() {
        let r = UsageParser.parse(output: "totally unrelated banner text with no useful lines")
        check(r.sessionPercent == nil, "unrecognized has no percent")
        check(r.error?.contains("Couldn't find a session usage line") == true,
              "unrecognized error surfaced")
    }

    // MARK: - Runner

    static func main() {
        testParseLine()
        testParseFullOutput()
        testCommandNotFound()
        testApiKeyMode()
        testStaleSubscriptionCli()
        testUnrecognizedOutput()

        if failures == 0 {
            print("✓ All \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\n\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
