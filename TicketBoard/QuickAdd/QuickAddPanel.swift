import AppKit
import SwiftUI

/// Floating panel that takes keyboard input over any app without activating Ticket Board.
final class QuickAddPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 110),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc closes.
    override func cancelOperation(_ sender: Any?) { close() }

    /// Clicking elsewhere dismisses, like Spotlight.
    override func resignKey() {
        super.resignKey()
        close()
    }
}

@MainActor
final class QuickAddPanelController {
    private var panel: QuickAddPanel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? close() : show()
    }

    func show() {
        let panel = panel ?? QuickAddPanel()
        self.panel = panel
        // Fresh view each time so the field starts empty.
        let root = QuickAddView(onClose: { [weak self] in self?.close() })
            .modelContainer(AppModel.shared.container)
        let hosting = NSHostingView(rootView: root)
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - frame.height * 0.22))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.close()
    }
}
