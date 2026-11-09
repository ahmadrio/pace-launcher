import SwiftUI

struct TranslateView: View {
    let controller: TranslateController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "character.book.closed")
                    .foregroundStyle(.secondary)
                Text(controller.direction?.label ?? "Type to translate between Indonesian and English")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if controller.status == .translating {
                    ProgressView().controlSize(.small)
                }
            }

            if case .failed(let message) = controller.status {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
            }

            ScrollView {
                Text(controller.output)
                    .font(.system(size: 18))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(controller.status == .translating ? 0.5 : 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
