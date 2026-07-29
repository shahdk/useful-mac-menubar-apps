import Foundation

// Parsing of `claude -p "/usage"` output. Kept deliberately free of AppKit and
// process code so it can be compiled and unit-tested with Foundation alone
// (see ../Tests/UsageParserTests.swift and ../test.sh).

// MARK: - /usage result

struct UsageResult {
    var sessionPercent: Int?
    var sessionReset: String?
    var weekPercent: Int?
    var weekReset: String?
    var error: String?   // non-nil when we couldn't read usage
}

enum UsageParser {
    /// Parse the full stdout/stderr of `claude -p "/usage"` into a UsageResult.
    static func parse(output out: String) -> UsageResult {
        let lower = out.lowercased()
        if lower.contains("command not found") || (lower.contains("not found") && out.count < 200) {
            return UsageResult(error: "Claude CLI not found. Install it and log in (see menu).")
        }

        var result = UsageResult()
        for rawLine in out.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.lowercased().hasPrefix("current session:") {
                (result.sessionPercent, result.sessionReset) = parseLine(line)
            } else if line.lowercased().hasPrefix("current week") {
                (result.weekPercent, result.weekReset) = parseLine(line)
            }
        }

        if result.sessionPercent == nil {
            if lower.contains("api key") {
                result.error = "No subscription session usage (API-key mode)."
            } else if lower.contains("subscription") {
                // Older Claude CLIs print the "using your subscription" banner but
                // omit the "Current session:" line — usually a stale version.
                result.error = "Couldn't read session usage — your Claude CLI may be out of date. Update it (see Setup / Help)."
            } else {
                result.error = "Couldn't find a session usage line in `/usage` output."
            }
        }
        return result
    }

    /// Parse a single line such as
    /// "Current session: 37% used · resets Jul 29 at 12:59pm (America/Indianapolis)"
    /// into its percentage and the free-text reset description after "resets".
    static func parseLine(_ line: String) -> (Int?, String?) {
        var percent: Int?
        if let pctRange = line.range(of: #"(\d+)%"#, options: .regularExpression) {
            let digits = line[pctRange].dropLast() // remove %
            percent = Int(digits)
        }
        var reset: String?
        if let r = line.range(of: "resets", options: .caseInsensitive) {
            reset = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        return (percent, reset)
    }
}
