import Testing
@testable import DOTLauncherCore

struct ScriptMetadataTests {
    @Test func `reads a Raycast-style header`() throws {
        let source = """
        #!/bin/bash

        # Required parameters:
        # @raycast.schemaVersion 1
        # @raycast.title Deploy Site
        # @raycast.mode compact

        # Optional parameters:
        # @raycast.packageName Web
        # @raycast.icon 🚀
        # @raycast.description Push to production
        # @raycast.needsConfirmation true
        # @raycast.currentDirectoryPath ~/Projects/site

        echo done
        """
        let metadata = try #require(ScriptMetadata.parse(source))
        #expect(metadata.title == "Deploy Site")
        #expect(metadata.mode == .compact)
        #expect(metadata.packageName == "Web")
        #expect(metadata.icon == "🚀")
        #expect(metadata.description == "Push to production")
        #expect(metadata.needsConfirmation)
        #expect(metadata.currentDirectoryPath == "~/Projects/site")
    }

    @Test func `reads DOT-style keys and slash comments`() throws {
        let source = """
        #!/usr/bin/env node
        // @dot.title Hello
        // @dot.mode silent
        console.log("hi")
        """
        let metadata = try #require(ScriptMetadata.parse(source))
        #expect(metadata.title == "Hello")
        #expect(metadata.mode == .silent)
    }

    @Test func `DOT keys win over Raycast keys`() throws {
        let source = "# @raycast.title Old\n# @dot.title New\n"
        #expect(try #require(ScriptMetadata.parse(source)).title == "New")
    }

    @Test func `parses arguments`() throws {
        let source = """
        # @raycast.title Search
        # @raycast.argument1 { "type": "text", "placeholder": "Query" }
        # @raycast.argument2 { "type": "password", "placeholder": "Token", "optional": true }
        # @raycast.argument3 { "type": "dropdown", "placeholder": "Site", "data": [{"title": "Google", "value": "g"}, {"title": "Bing", "value": "b"}] }
        """
        let arguments = try #require(ScriptMetadata.parse(source)).arguments
        #expect(arguments.count == 3)
        #expect(arguments[0].kind == .text)
        #expect(arguments[0].placeholder == "Query")
        #expect(arguments[0].optional == false)
        #expect(arguments[1].kind == .password)
        #expect(arguments[1].optional)
        #expect(arguments[2].kind == .dropdown([
            ScriptDropdownItem(title: "Google", value: "g"),
            ScriptDropdownItem(title: "Bing", value: "b"),
        ]))
    }

    @Test func `no title means not a script command`() {
        #expect(ScriptMetadata.parse("#!/bin/bash\n# @raycast.mode compact\necho hi") == nil)
        #expect(ScriptMetadata.parse("") == nil)
    }

    @Test func `ignores unknown keys and bad argument JSON`() throws {
        let source = """
        # @raycast.title Robust
        # @raycast.author Somebody
        # @raycast.refreshTime 1h
        # @raycast.argument1 { not json
        # @raycast.argument2 { "type": "text", "placeholder": "Kept" }
        """
        let metadata = try #require(ScriptMetadata.parse(source))
        #expect(metadata.arguments.map(\.placeholder) == ["Kept"])
    }

    @Test func `defaults mode to fullOutput`() throws {
        #expect(try #require(ScriptMetadata.parse("# @raycast.title X")).mode == .fullOutput)
    }

    @Test func `only reads comment lines`() {
        #expect(ScriptMetadata.parse("echo \"@raycast.title Sneaky\"") == nil)
    }

    @Test func `strips ANSI colors`() {
        #expect(ANSI.strip("\u{1B}[31mred\u{1B}[0m ok") == "red ok")
        #expect(ANSI.strip("\u{1B}[1;32mbold green\u{1B}[0m") == "bold green")
        #expect(ANSI.strip("plain") == "plain")
    }

    @Test func `first typing field`() {
        func argument(_ kind: ScriptArgument.Kind) -> ScriptArgument {
            ScriptArgument(kind: kind, placeholder: "", optional: false, percentEncoded: false)
        }
        let dropdown = argument(.dropdown([ScriptDropdownItem(title: "Red", value: "red")]))
        #expect(ScriptArgument.firstTypingIndex(in: [dropdown, argument(.text)]) == 1)
        #expect(ScriptArgument.firstTypingIndex(in: [argument(.password)]) == 0)
        #expect(ScriptArgument.firstTypingIndex(in: [dropdown]) == nil)
        #expect(ScriptArgument.firstTypingIndex(in: []) == nil)
    }
}
