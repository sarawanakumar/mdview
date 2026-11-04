import AppKit

/// Fills File → Open Recent from AppKit's recent-documents list each time
/// the menu opens (spec 1.7).
///
/// AppKit only manages this menu by itself when it comes from a XIB; in a
/// menu built in code that needs a private API, so we fill it ourselves.
/// The sandbox still lets the app open files on its recent list.
@MainActor
final class RecentDocumentsMenu: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let controller = NSDocumentController.shared

        for url in controller.recentDocumentURLs {
            let item = NSMenuItem(
                title: FileManager.default.displayName(atPath: url.path),
                action: #selector(openRecent(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = url
            item.toolTip = url.path
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 16, height: 16)
            item.image = icon
            menu.addItem(item)
        }

        if !controller.recentDocumentURLs.isEmpty {
            menu.addItem(.separator())
        }
        let clear = NSMenuItem(
            title: "Clear Menu",
            action: #selector(NSDocumentController.clearRecentDocuments(_:)),
            keyEquivalent: ""
        )
        clear.target = controller
        menu.addItem(clear)
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSApp.presentError(error) }
        }
    }
}
