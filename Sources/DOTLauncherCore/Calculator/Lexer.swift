enum CalcToken: Equatable {
    case number(Double)
    case identifier(String)
    case op(Character)
    case leftParen
    case rightParen
}

enum CalcLexer {
    /// Splits input into tokens, or returns nil on anything unexpected.
    /// Both "." and "," are accepted as the decimal point.
    static func tokenize(_ input: String) -> [CalcToken]? {
        var tokens: [CalcToken] = []
        let characters = Array(input)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if character.isWhitespace {
                index += 1
            } else if character.isNumber || isDecimalPoint(character) {
                var literal = ""
                var sawPoint = false
                while index < characters.count, characters[index].isNumber || isDecimalPoint(characters[index]) {
                    if isDecimalPoint(characters[index]) {
                        guard !sawPoint else { return nil }
                        sawPoint = true
                        literal.append(".")
                    } else {
                        literal.append(characters[index])
                    }
                    index += 1
                }
                guard let value = Double(literal) else { return nil }
                tokens.append(.number(value))
            } else if character.isLetter || character == "π" {
                var name = ""
                while index < characters.count, characters[index].isLetter || characters[index] == "π" {
                    name.append(characters[index])
                    index += 1
                }
                tokens.append(.identifier(name.lowercased()))
            } else if let op = operators[character] {
                tokens.append(.op(op))
                index += 1
            } else if character == "(" {
                tokens.append(.leftParen)
                index += 1
            } else if character == ")" {
                tokens.append(.rightParen)
                index += 1
            } else {
                return nil
            }
        }
        return tokens
    }

    private static func isDecimalPoint(_ character: Character) -> Bool {
        character == "." || character == ","
    }

    /// Typographic variants map to their ASCII operator.
    private static let operators: [Character: Character] = [
        "+": "+", "-": "-", "−": "-",
        "*": "*", "×": "*", "·": "*",
        "/": "/", "÷": "/",
        "^": "^", "%": "%",
    ]
}
