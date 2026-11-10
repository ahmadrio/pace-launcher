import AppKit
import DOTLauncherCore

/// Every item and every flavor on a pasteboard, so its contents can be put
/// back after DOT borrows it for a paste (text, rich text, files, images…).
struct PasteboardSnapshot {
    private struct Item {
        let flavors: [(type: NSPasteboard.PasteboardType, data: Data)]
        /// The TIFF was left out (a PNG is there) and is offered on request again.
        let lazyTIFF: Bool
    }

    private let items: [Item]

    /// Reading a lazily offered TIFF would build it here, in the middle of
    /// a paste, so a TIFF next to a PNG is not copied.
    static func capture(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            let plan = ClipboardFilter.snapshotTypes(item.types.map(\.rawValue))
            let flavors = plan.copy.map { NSPasteboard.PasteboardType($0) }.compactMap { type in
                item.data(forType: type).map { (type: type, data: $0) }
            }
            return Item(flavors: flavors, lazyTIFF: plan.lazyTIFF)
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { saved in
            let item = NSPasteboardItem()
            for flavor in saved.flavors {
                item.setData(flavor.data, forType: flavor.type)
            }
            if saved.lazyTIFF, let png = saved.flavors.first(where: { $0.type == .png })?.data {
                LazyTIFFProvider.attach(to: item, png: png)
            }
            return item
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }
}
