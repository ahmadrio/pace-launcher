import Foundation

indirect enum CalcExpression {
    case number(Double)
    case constant(Double)
    case negate(CalcExpression)
    case binary(Character, CalcExpression, CalcExpression)
    case percent(CalcExpression)
    case call(String, CalcExpression)

    /// False for a bare (possibly negated) number or constant, which the
    /// launcher should not treat as a calculation: "e" is more likely the
    /// start of an app name than Euler's number.
    var isCalculation: Bool {
        switch self {
        case .number, .constant: false
        case .negate(let inner): inner.isCalculation
        case .binary, .percent, .call: true
        }
    }
}

/// Pratt parser. Precedence, loosest first: + -, * /, unary minus, ^ (right
/// associative), postfix %. So -2^2 is -(2^2) and 2^3^2 is 2^(3^2).
struct CalcParser {
    static let constants: [String: Double] = ["pi": .pi, "π": .pi, "e": M_E]
    static let functions: Set<String> = ["sqrt", "sin", "cos", "tan", "ln", "log", "abs", "round", "floor", "ceil"]

    private let tokens: [CalcToken]
    private var position = 0

    private init(tokens: [CalcToken]) {
        self.tokens = tokens
    }

    static func parse(_ tokens: [CalcToken]) -> CalcExpression? {
        var parser = CalcParser(tokens: tokens)
        guard let expression = parser.expression(minBindingPower: 0), parser.position == tokens.count else {
            return nil
        }
        return expression
    }

    private static let prefixBindingPower = 25
    private static let postfixBindingPower = 40

    /// (left, right) binding powers. Right < left makes ^ right associative.
    private static func infixBindingPower(_ op: Character) -> (Int, Int)? {
        switch op {
        case "+", "-": (10, 11)
        case "*", "/": (20, 21)
        case "^": (31, 30)
        default: nil
        }
    }

    private mutating func expression(minBindingPower: Int) -> CalcExpression? {
        guard var lhs = prefix() else { return nil }

        while let token = peek() {
            guard case .op(let op) = token else { break }

            if op == "%" {
                guard Self.postfixBindingPower >= minBindingPower else { break }
                position += 1
                lhs = .percent(lhs)
                continue
            }

            guard let (left, right) = Self.infixBindingPower(op), left >= minBindingPower else { break }
            position += 1
            guard let rhs = expression(minBindingPower: right) else { return nil }
            lhs = .binary(op, lhs, rhs)
        }
        return lhs
    }

    private mutating func prefix() -> CalcExpression? {
        guard let token = next() else { return nil }
        switch token {
        case .number(let value):
            return .number(value)
        case .op("-"):
            return expression(minBindingPower: Self.prefixBindingPower).map(CalcExpression.negate)
        case .op("+"):
            return expression(minBindingPower: Self.prefixBindingPower)
        case .leftParen:
            guard let inner = expression(minBindingPower: 0), next() == .rightParen else { return nil }
            return inner
        case .identifier(let name):
            if let value = Self.constants[name] { return .constant(value) }
            guard Self.functions.contains(name), next() == .leftParen,
                  let argument = expression(minBindingPower: 0), next() == .rightParen
            else { return nil }
            return .call(name, argument)
        default:
            return nil
        }
    }

    private func peek() -> CalcToken? {
        position < tokens.count ? tokens[position] : nil
    }

    private mutating func next() -> CalcToken? {
        defer { position += 1 }
        return peek()
    }
}
