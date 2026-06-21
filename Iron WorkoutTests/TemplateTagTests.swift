//
//  TemplateTagTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("TemplateTag")
struct TemplateTagTests {

    @Test("Normalize trims and collapses whitespace")
    func normalize() {
        #expect(TemplateTag.normalize("  Hypertrophy  ") == "Hypertrophy")
        #expect(TemplateTag.normalize("Push   Pull") == "Push Pull")
        #expect(TemplateTag.normalize("\tDeload\n") == "Deload")
        #expect(TemplateTag.normalize("   ") == "")
    }

    @Test("Adding appends a normalized tag")
    func addsTag() {
        #expect(TemplateTag.adding("Powerlifting", to: []) == ["Powerlifting"])
        #expect(TemplateTag.adding("  Deload ", to: ["Powerlifting"]) == ["Powerlifting", "Deload"])
    }

    @Test("Adding ignores blanks")
    func ignoresBlank() {
        #expect(TemplateTag.adding("   ", to: ["A"]) == ["A"])
        #expect(TemplateTag.adding("", to: []) == [])
    }

    @Test("Adding de-duplicates case-insensitively, keeping the existing casing")
    func dedupesCaseInsensitively() {
        #expect(TemplateTag.adding("hypertrophy", to: ["Hypertrophy"]) == ["Hypertrophy"])
        #expect(TemplateTag.adding("DELOAD", to: ["Deload"]) == ["Deload"])
    }
}
