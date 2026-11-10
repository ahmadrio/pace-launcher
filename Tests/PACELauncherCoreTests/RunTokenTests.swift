import Testing
@testable import PACELauncherCore

struct RunTokenTests {
    @Test func `an older run cannot end a newer one`() {
        var token = RunToken()
        let first = token.begin()
        let second = token.begin()
        #expect(!token.isCurrent(first))
        #expect(token.isCurrent(second))
    }
}
