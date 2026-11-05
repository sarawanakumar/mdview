import AppKit

/// What the find bar needs from the preview (spec 6.6).
@MainActor
protocol FindTarget: AnyObject {
    /// Selects and scrolls to the next (or previous) match after the
    /// current selection, wrapping around. True if anything matched.
    func find(_ text: String, backwards: Bool) async -> Bool
    /// How many times `text` appears in the page, ignoring case.
    func countMatches(of text: String) async -> Int
    /// Starts the next search from the top of the page.
    func clearSelection() async
    /// The text currently selected in the page, if any.
    func selectedText() async -> String?
}

/// A slim find bar in the style of the system's: search field, previous /
/// next, match count, Done. WebKit has no find bar of its own, so this is
/// ours, driving `WKWebView.find` (architecture.md).
@MainActor
final class FindBar: NSObject, NSSearchFieldDelegate {
    let view: NSStackView
    private let field = NSSearchField()
    private let status = NSTextField(labelWithString: "")
    private let navigation = NSSegmentedControl()
    weak var target: FindTarget?
    /// Called when the bar should close (Done or Esc).
    var onClose: (() -> Void)?

    /// What was last searched for, so Find Next works with the bar closed.
    private(set) var searchText = ""

    override init() {
        view = NSStackView()
        super.init()

        field.placeholderString = "Find"
        field.sendsSearchStringImmediately = true
        field.delegate = self
        field.setAccessibilityLabel("Find in page")
        field.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        navigation.segmentCount = 2
        navigation.setImage(NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous match"), forSegment: 0)
        navigation.setImage(NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next match"), forSegment: 1)
        navigation.trackingMode = .momentary
        navigation.controlSize = .small
        navigation.target = self
        navigation.action = #selector(navigate(_:))

        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let done = NSButton(title: "Done", target: self, action: #selector(close))
        done.controlSize = .small
        done.bezelStyle = .push

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setViews([field, navigation, status, spacer, done], in: .leading)
        view.orientation = .horizontal
        view.spacing = 8
        view.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setAccessibilityRole(.group)
        view.setAccessibilityLabel("Find")
    }

    /// Puts the cursor in the search field, with its text selected.
    func focus(in window: NSWindow?) {
        window?.makeFirstResponder(field)
        field.selectText(nil)
    }

    /// Searches for `text` from the top, e.g. for Use Selection for Find.
    func search(for text: String) {
        field.stringValue = text
        searchText = text
        Task { await searchFromTop() }
    }

    func findNext() { Task { await step(backwards: false) } }
    func findPrevious() { Task { await step(backwards: true) } }

    // MARK: Searching

    private func searchFromTop() async {
        guard let target else { return }
        let text = searchText
        guard !text.isEmpty else {
            status.stringValue = ""
            await target.clearSelection()
            return
        }
        await target.clearSelection()
        let found = await target.find(text, backwards: false)
        guard text == searchText else { return }  // typed on since
        await updateStatus(found: found, text: text)
    }

    private func step(backwards: Bool) async {
        guard let target, !searchText.isEmpty else { return }
        let text = searchText
        let found = await target.find(text, backwards: backwards)
        await updateStatus(found: found, text: text)
    }

    private func updateStatus(found: Bool, text: String) async {
        guard found, let target else {
            status.stringValue = "Not found"
            NSAccessibility.post(element: status, notification: .announcementRequested, userInfo: [.announcement: "Not found"])
            return
        }
        let count = await target.countMatches(of: text)
        status.stringValue = count == 1 ? "1 match" : "\(count) matches"
    }

    // MARK: Actions and field events

    @objc private func navigate(_ sender: NSSegmentedControl) {
        sender.selectedSegment == 0 ? findPrevious() : findNext()
    }

    @objc private func close() {
        onClose?()
    }

    func controlTextDidChange(_ notification: Notification) {
        searchText = field.stringValue
        Task { await searchFromTop() }
    }

    /// Return: next match; Shift-Return: previous; Esc: close.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            NSApp.currentEvent?.modifierFlags.contains(.shift) == true ? findPrevious() : findNext()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            close()
            return true
        default:
            return false
        }
    }
}
