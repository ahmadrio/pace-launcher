import Foundation

public enum Calculator {
    /// Evaluates `input` as arithmetic. Returns nil when it is not a
    /// calculation (a bare number, text, a syntax error) or the result is
    /// not finite.
    public static func evaluate(_ input: String) -> Double? {
        guard let tokens = CalcLexer.tokenize(input), !tokens.isEmpty,
              let expression = CalcParser.parse(tokens), expression.isCalculation
        else { return nil }

        let value = evaluate(expression)
        return value.isFinite ? value : nil
    }

    /// Up to 10 decimals with trailing zeros trimmed; scientific notation
    /// for very large or very small magnitudes.
    public static func format(_ value: Double, decimalSeparator: String) -> String {
        guard value != 0 else { return "0" }

        let text: String
        if abs(value) >= 1e15 || abs(value) < 1e-10 {
            text = String(format: "%g", value)
        } else {
            var fixed = String(format: "%.10f", value)
            while fixed.hasSuffix("0") { fixed.removeLast() }
            if fixed.hasSuffix(".") { fixed.removeLast() }
            text = fixed == "-0" ? "0" : fixed
        }
        return text.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    private static func evaluate(_ expression: CalcExpression) -> Double {
        switch expression {
        case .number(let value), .constant(let value):
            return value
        case .negate(let inner):
            return -evaluate(inner)
        case .percent(let inner):
            return evaluate(inner) / 100
        case .binary(let op, let lhs, let rhs):
            let a = evaluate(lhs)
            let b = evaluate(rhs)
            switch op {
            case "+": return a + b
            case "-": return a - b
            case "*": return a * b
            case "/": return a / b
            case "^": return pow(a, b)
            default: return .nan
            }
        case .call(let name, let argument):
            let x = evaluate(argument)
            switch name {
            case "sqrt": return x.squareRoot()
            case "sin": return sin(x)
            case "cos": return cos(x)
            case "tan": return tan(x)
            case "ln": return log(x)
            case "log": return log10(x)
            case "abs": return abs(x)
            case "round": return x.rounded()
            case "floor": return x.rounded(.down)
            case "ceil": return x.rounded(.up)
            default: return .nan
            }
        }
    }
}
