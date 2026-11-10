import Foundation
import Testing
@testable import DOTLauncherCore

private let main = URL(filePath: "/tmp/main")

private func script(_ path: String, title: String = "Hello", mode: String = "compact",
                    confirm: Bool = false, argument: Bool = false, executable: Bool = true) -> ScriptCommand {
    var header = "# @dot.title \(title)\n# @dot.mode \(mode)\n"
    if confirm { header += "# @dot.needsConfirmation true\n" }
    if argument { header += #"# @dot.argument1 { "type": "text", "placeholder": "Name" }"# + "\n" }
    let url = URL(filePath: path)
    return ScriptCommand(id: url.path, url: url, metadata: ScriptMetadata.parse(header)!, isExecutable: executable)
}

struct ScriptShortcutTests {
    @Test func `keys are relative in the main folder and absolute elsewhere`() {
        #expect(ScriptShortcut.key(for: script("/tmp/main/tools/deploy.sh"), mainFolder: main) == "tools/deploy.sh")
        #expect(ScriptShortcut.key(for: script("/Users/x/bin/a.sh"), mainFolder: main) == "/Users/x/bin/a.sh")
        #expect(ScriptShortcut.key(for: script("/tmp/mainly/a.sh"), mainFolder: main) == "/tmp/mainly/a.sh")
    }

    @Test func `same-named files in different folders get different keys`() {
        let top = script("/tmp/main/hello.sh"), nested = script("/tmp/main/sub/hello.sh")
        let topKey = ScriptShortcut.key(for: top, mainFolder: main)
        let nestedKey = ScriptShortcut.key(for: nested, mainFolder: main)
        #expect(topKey != nestedKey)
        #expect(ScriptShortcut.script(forKey: topKey, in: [top, nested], mainFolder: main) == top)
        #expect(ScriptShortcut.script(forKey: nestedKey, in: [top, nested], mainFolder: main) == nested)
        #expect(ScriptShortcut.script(forKey: "gone.sh", in: [top, nested], mainFolder: main) == nil)
    }

    @Test func `confirmation scripts ask before running`() {
        let deploy = script("/tmp/main/deploy.sh", confirm: true)
        #expect(ScriptShortcut.step(for: deploy, isConfirmed: false) == .confirm)
        #expect(ScriptShortcut.step(for: deploy, isConfirmed: true) == .runInBackground)
    }

    @Test func `steps follow the launcher order`() {
        var asked = false
        func confirmed() -> Bool { asked = true; return false }
        #expect(ScriptShortcut.step(for: script("/tmp/main/a.sh", executable: false), isConfirmed: confirmed()) == .notExecutable)
        #expect(ScriptShortcut.step(for: script("/tmp/main/a.sh", confirm: true, argument: true), isConfirmed: confirmed()) == .fillArguments)
        #expect(!asked)
        #expect(ScriptShortcut.step(for: script("/tmp/main/a.sh", mode: "fullOutput"), isConfirmed: confirmed()) == .runInPanel)
        #expect(!asked)
        for mode in ["compact", "silent", "inline"] {
            #expect(ScriptShortcut.step(for: script("/tmp/main/a.sh", mode: mode), isConfirmed: confirmed()) == .runInBackground)
        }
        #expect(!asked)
    }

    @Test func `duplicate titles get their folder as detail`() {
        let rows = ScriptShortcut.rows(scripts: [
            script("/tmp/main/sub/hello.sh"), script("/tmp/main/zeta.sh", title: "Zeta"), script("/tmp/main/hello.sh"),
            script("/tmp/main/apple.sh", title: "apple"),
        ], mainFolder: main, saved: [:])
        #expect(rows.map(\.title) == ["apple", "Hello", "Hello", "Zeta"])
        #expect(rows.filter { $0.title == "Hello" }.map(\.detail) == ["main", "main/sub"])
        #expect(rows.first { $0.title == "Zeta" }?.detail == nil)
        #expect(rows.allSatisfy { !$0.isMissing })
        #expect(rows.first { $0.title == "Zeta" }?.id == .script("zeta.sh"))
    }

    @Test func `rows keep shortcuts of missing scripts`() {
        let rows = ScriptShortcut.rows(scripts: [script("/tmp/main/hello.sh")], mainFolder: main,
                                       saved: ["script.gone.sh": "ctrl+opt+2", "script.none.sh": "", "launcher": "opt+space"])
        #expect(rows.count == 2)
        #expect(rows.last == ScriptShortcut.Row(id: .script("gone.sh"), title: "gone.sh", detail: "Not found on this Mac", isMissing: true))
    }

    @Test func `duplicate titles in same-named folders stay distinct`() {
        let rows = ScriptShortcut.rows(scripts: [
            script("/tmp/main/work/deploy.sh", title: "Deploy"), script("/Users/x/work/deploy.sh", title: "Deploy"),
        ], mainFolder: main, saved: [:])
        #expect(rows.map(\.detail) == ["/Users/x/work", "main/work"])
        #expect(rows.map(\.id) == [.script("/Users/x/work/deploy.sh"), .script("work/deploy.sh")])
    }

    @Test func `fingerprint changes only with keys and titles`() {
        let before = ScriptShortcut.fingerprint(of: [script("/tmp/main/a.sh", title: "A")], mainFolder: main)
        #expect(before == ["a.sh": "A"])
        #expect(ScriptShortcut.fingerprint(of: [script("/tmp/main/a.sh", title: "A", mode: "fullOutput")], mainFolder: main) == before)
        #expect(ScriptShortcut.fingerprint(of: [script("/tmp/main/a.sh", title: "B")], mainFolder: main) != before)
        #expect(ScriptShortcut.fingerprint(of: [script("/tmp/main/b.sh", title: "A")], mainFolder: main) != before)
    }

    @Test func `shortcuts are retried while one could not be registered`() {
        let same = ["a.sh": "A"]
        #expect(!ScriptShortcut.shouldReapply(previous: same, current: same, anyUnavailable: false))
        #expect(ScriptShortcut.shouldReapply(previous: same, current: same, anyUnavailable: true))
        #expect(ScriptShortcut.shouldReapply(previous: same, current: ["a.sh": "B"], anyUnavailable: false))
    }

    @Test func `only script-relevant paths trigger a reload`() {
        let folders = ["/tmp/main", "/x/extra"]
        for path in ["/tmp/main", "/tmp/main/a.sh", "/tmp/main/a/b/c/d.sh", "/x/extra/tool.sh", "/tmp/main/"] {
            #expect(ScriptFolderEvents.isRelevant(path, folders: folders), "\(path)")
        }
        for path in ["/tmp/main/a/b/c/d/e.sh", "/tmp/main/.git/index", "/tmp/main/sub/.hidden.sh", "/tmp/mainly/a.sh", "/tmp/Notes/n.md", "/tmp"] {
            #expect(!ScriptFolderEvents.isRelevant(path, folders: folders), "\(path)")
        }
    }

    @Test func `a missing folder is watched through its parent`() {
        let existing: Set<String> = ["/tmp", "/x/extra"]
        #expect(ScriptFolderEvents.watchPaths(for: ["/tmp/main", "/x/extra"], exists: existing.contains) == ["/tmp", "/x/extra"])
        #expect(ScriptFolderEvents.watchPaths(for: ["/nowhere/main"], exists: existing.contains).isEmpty)
    }
}

