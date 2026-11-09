import Observation
import SwiftUI

/// Which script run the output view shows.
@Observable
final class ScriptSession {
    var run: ScriptRun?
}

struct ScriptOutputView: View {
    let session: ScriptSession

    var body: some View {
        if let run = session.run {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if run.isRunning {
                        ProgressView().controlSize(.small)
                        Text("Running \(run.script.metadata.title)… (esc to stop)").foregroundStyle(.secondary)
                    } else if run.succeeded {
                        Label("Finished", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Label(run.launchError == nil ? "Exited with code \(run.exitCode ?? -1)" : "Could not run",
                              systemImage: "xmark.octagon.fill")
                            .foregroundStyle(.red)
                    }
                    Spacer()
                }
                .font(.system(size: 12))

                ScrollViewReader { proxy in
                    ScrollView {
                        Text(run.output.isEmpty ? " " : run.output)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Color.clear.frame(height: 1).id("end")
                    }
                    .onChange(of: run.output.count) {
                        proxy.scrollTo("end", anchor: .bottom)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
