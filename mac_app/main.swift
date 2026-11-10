import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var webView: WKWebView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Window Configuration
        let rect = NSRect(x: 0, y: 0, width: 1320, height: 880)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "APEX OS"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 1.0)
        window.minSize = NSSize(width: 900, height: 620)
        window.delegate = self

        // WebKit Configuration
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        window.contentView!.addSubview(webView)

        setupMainMenu()
        loadContent()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func loadContent() {
        // First check if live local server is running on 5174
        if let devURL = URL(string: "http://localhost:5174/") {
            var request = URLRequest(url: devURL, timeoutInterval: 1.2)
            request.httpMethod = "HEAD"
            let session = URLSession(configuration: .ephemeral)
            let task = session.dataTask(with: request) { [weak self] (_, response, error) in
                DispatchQueue.main.async {
                    if error == nil, let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                        self?.webView.load(URLRequest(url: devURL))
                    } else {
                        self?.loadEmbeddedDist()
                    }
                }
            }
            task.resume()
        } else {
            loadEmbeddedDist()
        }
    }

    func loadEmbeddedDist() {
        if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "dist") {
            let distDir = indexURL.deletingLastPathComponent()
            webView.loadFileURL(indexURL, allowingReadAccessTo: distDir)
        } else {
            // Fallback to direct path in Resources
            let resourcePath = Bundle.main.resourceURL?.appendingPathComponent("dist/index.html")
            if let resourcePath = resourcePath, FileManager.default.fileExists(atPath: resourcePath.path) {
                let distDir = resourcePath.deletingLastPathComponent()
                webView.loadFileURL(resourcePath, allowingReadAccessTo: distDir)
            }
        }
    }

    func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let appName = "APEX OS"
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Reload Interface", action: #selector(reloadWebView), keyEquivalent: "r")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu for standard copy/paste shortcuts
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
    }

    @objc func reloadWebView() {
        loadContent()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApplication.shared.terminate(self)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
