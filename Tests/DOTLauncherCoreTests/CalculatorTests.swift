import Foundation
import Testing
@testable import DOTLauncherCore

struct CalculatorTests {
    @Test(arguments: [
        ("2+3*4", 14.0),
        ("(2+3)*4", 20),
        ("2^3^2", 512),
        ("-2^2", -4),
        ("10/4", 2.5),
        ("50%", 0.5),
        ("3 × 4 ÷ 2", 6),
        ("2 − 1", 1),
        ("1,5+1", 2.5),
        ("1.5+1", 2.5),
        ("-(2+3)", -5),
        ("2*-3", -6),
        ("abs(-3)+1", 4),
        ("2*pi", 2 * Double.pi),
    ])
    func `evaluates arithmetic`(input: String, expected: Double) throws {
        let value = try #require(Calculator.evaluate(input))
        #expect(abs(value - expected) < 1e-9)
    }

    @Test func `supports functions and constants`() throws {
        let value = try #require(Calculator.evaluate("sqrt(16)+pi"))
        #expect(abs(value - (4 + Double.pi)) < 1e-9)
    }

    @Test(arguments: [
        "1/0",      // infinity
        "2^2000",   // overflow
        "42",       // a bare number is not a calculation
        "-5",
        "e",        // a lone constant would hijack app searches like "e…"
        "pi",
        "abc",
        "2+",
        "((1)",
        "(1))",
        "",
        "sqrt",
        "1.2.3+1",
        "2 3",
    ])
    func `rejects input that is not a finite calculation`(input: String) {
        #expect(Calculator.evaluate(input) == nil)
    }

    @Test(arguments: [
        (0.1 + 0.2, ".", "0.3"),
        (2.5, ",", "2,5"),
        (14, ".", "14"),
        (-0.0, ".", "0"),
        (1.0 / 3.0, ".", "0.3333333333"),
        (-1234.5, ".", "-1234.5"),
        (1e20, ".", "1e+20"),
    ])
    func `formats results`(value: Double, separator: String, expected: String) {
        #expect(Calculator.format(value, decimalSeparator: separator) == expected)
    }
}
