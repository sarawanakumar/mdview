import AppKit

/// The menu bar, built in code (ADR 0002: no storyboards or XIBs).
///
/// Items target the responder chain (nil target), so AppKit enables each
/// one only when something can handle it, such as Copy when there's a
/// selection.
@MainActor
enum MainMenu {
    /// Kept alive here: menus hold their delegates weakly.
    private static let recentDocuments = RecentDocumentsMenu()

    static func make() -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(submenuItem(appMenu()))
        mainMenu.addItem(submenuItem(fileMenu()))
        mainMenu.addItem(submenuItem(editMenu()))
        mainMenu.addItem(submenuItem(viewMenu()))

        let window = windowMenu()
        mainMenu.addItem(submenuItem(window))
        NSApp.windowsMenu = window

        let help = NSMenu(title: "Help")
        mainMenu.addItem(submenuItem(help))
        NSApp.helpMenu = help

        return mainMenu
    }

    // MARK: Menus

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "MDView")
        menu.addItem(item("About MDView", #selector(AppDelegate.showAbout(_:))))
        menu.addItem(.separator())

        let services = NSMenu(title: "Services")
        menu.addItem(submenuItem(services))
        NSApp.servicesMenu = services
        menu.addItem(.separator())

        menu.addItem(item("Hide MDView", #selector(NSApplication.hide(_:)), "h"))
        menu.addItem(item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]))
        menu.addItem(item("Show All", #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Quit MDView", #selector(NSApplication.terminate(_:)), "q"))
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(item("Open…", #selector(NSDocumentController.openDocument(_:)), "o"))

        let recent = NSMenu(title: "Open Recent")
        recent.delegate = recentDocuments
        menu.addItem(submenuItem(recent))

        menu.addItem(.separator())
        // Spec 6.9; handled by the document window.
        menu.addItem(item("Reveal in Finder", #selector(DocumentWindowController.revealInFinder(_:)), "r", [.command, .shift]))
        // Spec 6.10–6.12; the title becomes "Open in <app>" once chosen.
        menu.addItem(item("Open in Editor…", #selector(DocumentWindowController.openInEditor(_:)), "e", [.command, .shift]))
        menu.addItem(item("Change Editor…", #selector(DocumentWindowController.changeEditor(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))
        // Spec 11.6; NSDocument handles it, dimmed when nothing has changed.
        menu.addItem(item("Save", #selector(NSDocument.save(_:)), "s"))
        // Spec 6.8; NSDocument handles both (it's in the responder chain).
        menu.addItem(.separator())
        menu.addItem(item("Page Setup…", #selector(NSDocument.runPageLayout(_:)), "p", [.command, .shift]))
        menu.addItem(item("Print…", #selector(NSDocument.printDocument(_:)), "p"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        // Undo, Redo, Cut and Paste only do something in edit mode (spec 11.4);
        // AppKit dims them in the preview.
        menu.addItem(item("Undo", Selector(("undo:")), "z"))
        menu.addItem(item("Redo", Selector(("redo:")), "z", [.command, .shift]))
        menu.addItem(.separator())
        menu.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        menu.addItem(.separator())

        // Spec 6.6. Handled by the document window (in the responder chain).
        let find = NSMenu(title: "Find")
        find.addItem(item("Find…", #selector(DocumentWindowController.showFindBar(_:)), "f"))
        find.addItem(item("Find Next", #selector(DocumentWindowController.findNextMatch(_:)), "g"))
        find.addItem(item("Find Previous", #selector(DocumentWindowController.findPreviousMatch(_:)), "g", [.command, .shift]))
        find.addItem(item("Use Selection for Find", #selector(DocumentWindowController.useSelectionForFind(_:)), "e"))
        menu.addItem(submenuItem(find))
        return menu
    }

    /// Spec 6.7, per window; handled by the document window.
    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        // Spec 11.1, ADR 0008; checked while editing. ⌘E is taken by Find.
        menu.addItem(item("Edit Mode", #selector(DocumentWindowController.toggleEditMode(_:)), "/"))
        menu.addItem(.separator())
        menu.addItem(item("Actual Size", #selector(DocumentWindowController.actualSize(_:)), "0"))
        menu.addItem(item("Zoom In", #selector(DocumentWindowController.zoomIn(_:)), "="))
        // ⌘+ too (Shift-= on most keyboards), without a second visible item.
        let zoomInPlus = item("Zoom In", #selector(DocumentWindowController.zoomIn(_:)), "+")
        zoomInPlus.isHidden = true
        zoomInPlus.allowsKeyEquivalentWhenHidden = true
        menu.addItem(zoomInPlus)
        menu.addItem(item("Zoom Out", #selector(DocumentWindowController.zoomOut(_:)), "-"))
        return menu
    }

    private static func windowMenu() -> NSMenu {
        // macOS adds the window list and the tab commands (Merge All
        // Windows and so on) to the menu set as NSApp.windowsMenu.
        let menu = NSMenu(title: "Window")
        menu.addItem(item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(item("Zoom", #selector(NSWindow.performZoom(_:))))
        menu.addItem(.separator())
        menu.addItem(item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))))
        return menu
    }

    // MARK: Helpers

    private static func item(
        _ title: String,
        _ action: Selector,
        _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = .command
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = modifiers }
        return item
    }

    private static func submenuItem(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }
}
