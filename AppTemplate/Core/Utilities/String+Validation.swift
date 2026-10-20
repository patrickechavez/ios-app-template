//
//  String+Validation.swift
//  AppTemplate
//

import Foundation

extension String {

    /// The string with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A lenient email check for forms — enough to catch obvious typos, not a
    /// substitute for server-side validation.
    var isValidEmail: Bool {
        guard !isEmpty, !contains(" "), count <= 254 else { return false }

        let parts = split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let domain = parts[1]
        return domain.contains(".")
            && !domain.hasPrefix(".")
            && !domain.hasSuffix(".")
            && !domain.contains("..")
    }
}

enum InputValidation {

    /// Returns a message only when `text` is non-empty and malformed, so the
    /// field stays quiet until the user has typed something to judge.
    static func email(_ text: String) -> String? {
        guard !text.isEmpty, !text.trimmed.isValidEmail else { return nil }
        return String(
            localized: "Enter a valid email address.",
            comment: "Validation message shown for a malformed email address"
        )
    }
}
