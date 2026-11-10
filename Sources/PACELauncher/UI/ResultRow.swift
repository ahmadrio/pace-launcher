import SwiftUI

struct ResultRow: View {
    @Environment(ThemeController.self) private var theme
    let result: LauncherResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: 14))
                    .lineLimit(1)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 12)
            Text(result.accessory)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(
            isSelected ? AnyShapeStyle(theme.accentColor.opacity(0.3)) : AnyShapeStyle(.clear),
            in: .rect(cornerRadius: 10)
        )
    }

    @ViewBuilder private var icon: some View {
        switch result.icon {
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
        case .text(let glyph):
            Text(glyph)
                .font(.system(size: 20))
                .frame(width: 28, height: 28)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: .rect(cornerRadius: 7))
        }
    }
}
