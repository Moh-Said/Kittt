import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct KitttApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appDelegate.player)
        }
        .windowToolbarStyle(UnifiedCompactWindowToolbarStyle(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") {
                    appDelegate.openFolderViaPanel()
                }
                .keyboardShortcut("o", modifiers: .command)
                Button("Open File…") {
                    appDelegate.openFileViaPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandGroup(after: .toolbar) {
                Button("Play / Pause") {
                    appDelegate.player.togglePlay()
                }
                .keyboardShortcut(.space, modifiers: [])
                Button("Next Track") {
                    appDelegate.player.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Previous Track") {
                    appDelegate.player.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let player = PlayerModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        RemoteCommands.install(player: player)
        applyAppIcon()
    }

    private func applyAppIcon() {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = image
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        if isDirectory(url) {
            player.loadFolder(url)
        } else if Playlist.supportedExtensions.contains(url.pathExtension.lowercased()) {
            player.loadSingleFile(url)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func openFolderViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        if panel.runModal() == .OK, let url = panel.url {
            player.loadFolder(url)
        }
    }

    func openFileViaPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]
        panel.prompt = "Play"
        if panel.runModal() == .OK, let url = panel.url {
            player.loadSingleFile(url)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}
