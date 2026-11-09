import Testing
@testable import DOTLauncherCore

struct ChatLanguageRouteTests {
    let supported: Set<String> = ["en", "fr"]

    @Test func `supported language goes directly to the model`() {
        #expect(ChatLanguageRoute.route(detected: "en", supported: supported) == .direct)
    }

    @Test func `unsupported language is bridged through translation`() {
        #expect(ChatLanguageRoute.route(detected: "id", supported: supported) == .bridge(language: "id"))
    }

    @Test func `undetermined language goes directly`() {
        #expect(ChatLanguageRoute.route(detected: nil, supported: supported) == .direct)
    }
}
