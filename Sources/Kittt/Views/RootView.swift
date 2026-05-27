import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(PlayerModel.self) private var player
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var savedFullFrame: NSRect?
    @State private var savedMinSize: NSSize?
    @State private var savedMaxSize: NSSize?

    private static let miniContentSize = NSSize(width: 320, height: 290)

    var body: some View {
        ZStack {
            if player.miniPlayerMode {
                MiniPlayerView()
            } else {
                fullUI
            }
        }
        .onChange(of: player.miniPlayerMode, initial: false) { _, isMini in
            DispatchQueue.main.async {
                applyMode(isMini: isMini)
            }
        }
    }

    @ViewBuilder
    private var fullUI: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            VStack(spacing: 0) {
                NowPlayingPanel()
                Divider()
                PlaylistView(sidebarHidden: columnVisibility == .detailOnly)
                    .frame(maxHeight: .infinity)
                Divider()
                TransportBar()
            }
        }
        .navigationTitle("Kittt - A simple music player")
        .textVariant(smallCaps: true)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                    }
                } label: {
                    Image(systemName: "sidebar.leading")
                }
                .help("Toggle Sidebar")

                Text("KITTT — A SIMPLE MUSIC PLAYER")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .onAppear { AutoToggleSuppressor.shared.installWhenReady() }
        .onChange(of: player.rootFolderName) { _, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                columnVisibility = player.playlists.isEmpty ? .detailOnly : .all
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                Task { @MainActor in
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        player.loadFolder(url)
                    }
                }
            }
            return true
        }
    }

    private func applyMode(isMini: Bool) {
        let candidate = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first { $0.isVisible && !$0.isMiniaturized }
        guard let window = candidate else { return }

        ResizeClampStore.shared.uninstall()

        if isMini {
            savedFullFrame = window.frame
            savedMinSize = window.minSize
            savedMaxSize = window.maxSize

            window.styleMask = [.titled, .closable, .miniaturizable]
            window.collectionBehavior = [.fullScreenNone]
            window.standardWindowButton(.zoomButton)?.isEnabled = false
            window.minSize = NSSize(width: 0, height: 0)
            window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

            let topY = window.frame.maxY
            let leftX = window.frame.origin.x
            window.setContentSize(Self.miniContentSize)
            var f = window.frame
            f.origin.x = leftX
            f.origin.y = topY - f.height
            window.setFrame(f, display: true, animate: false)

            let lockedFrameSize = window.frame.size
            window.minSize = lockedFrameSize
            window.maxSize = lockedFrameSize

            ResizeClampStore.shared.install(window: window, lockedSize: lockedFrameSize)
        } else {
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.collectionBehavior = [.fullScreenPrimary]
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.minSize = savedMinSize ?? NSSize(width: 0, height: 0)
            window.maxSize = savedMaxSize ?? NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            if let frame = savedFullFrame {
                window.setFrame(frame, display: true, animate: false)
            }
        }
    }

}

private final class AutoToggleSuppressor {
    static let shared = AutoToggleSuppressor()
    private weak var window: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private init() {}

    func installWhenReady(retries: Int = 10) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            guard let w = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) else {
                if retries > 0 { installWhenReady(retries: retries - 1) }
                return
            }
            attach(to: w)
        }
    }

    private func attach(to window: NSWindow) {
        if self.window === window, !observers.isEmpty { purge(); return }
        for obs in observers { NotificationCenter.default.removeObserver(obs) }
        observers.removeAll()
        self.window = window

        purge()

        let nc = NotificationCenter.default
        if let toolbar = window.toolbar {
            observers.append(nc.addObserver(forName: NSToolbar.willAddItemNotification, object: toolbar, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { self?.purge() }
            })
            observers.append(nc.addObserver(forName: NSToolbar.didRemoveItemNotification, object: toolbar, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { self?.purge() }
            })
        }
        observers.append(nc.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.purge() }
        })
    }

    private func purge() {
        guard let window else { return }

        if let toolbar = window.toolbar {
            let indices = toolbar.items.indices.filter {
                let id = toolbar.items[$0].itemIdentifier.rawValue.lowercased()
                return id.contains("togglesidebar") || id.contains("splitviewseparator")
            }
            for i in indices.reversed() {
                toolbar.removeItem(at: i)
            }
        }

        for (index, vc) in window.titlebarAccessoryViewControllers.enumerated().reversed()
            where vc.layoutAttribute == .leading {
            window.removeTitlebarAccessoryViewController(at: index)
        }
    }
}

private final class ResizeClampStore {
    static let shared = ResizeClampStore()
    private var observer: NSObjectProtocol?
    private init() {}

    func install(window: NSWindow, lockedSize: NSSize) {
        uninstall()
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            guard let w = window else { return }
            if w.frame.size != lockedSize {
                var f = w.frame
                let topY = f.maxY
                f.size = lockedSize
                f.origin.y = topY - f.height
                w.setFrame(f, display: false)
            }
        }
    }

    func uninstall() {
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
            observer = nil
        }
    }
}
