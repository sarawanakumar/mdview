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
        menu.addItem(item("About MDView", #selector(NSApplication.orderFrontStandardAboutPanel(_:))))
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
        menu.addItem(item("Close", #selector(NSWindow.performClose(_:)), "w"))
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        menu.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
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
