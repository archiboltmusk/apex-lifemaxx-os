import Cocoa
import WebKit

// MARK: - Mini Local Static Server for 100% Offline Standalone Support
class MiniStaticServer {
    private var serverSocket: Int32 = -1
    private(set) var port: UInt16 = 0
    let rootDir: URL
    private var isRunning = false

    init(rootDir: URL) {
        self.rootDir = rootDir
    }

    func start() -> Bool {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { return false }

        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(0).bigEndian // 0 = assign free ephemeral port
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        var bindAddr = addr
        let bindRes = withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindRes == 0 else {
            close(serverSocket)
            serverSocket = -1
            return false
        }

        guard listen(serverSocket, 32) == 0 else {
            close(serverSocket)
            serverSocket = -1
            return false
        }

        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        getsockname(serverSocket, withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 }
        }, &len)

        port = UInt16(bigEndian: addr.sin_port)
        isRunning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.acceptLoop()
        }
        return true
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientLen)
                }
            }
            guard clientSocket >= 0 else { continue }
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }

    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let requestString = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
        guard let firstLine = requestString.components(separatedBy: "\r\n").first else { return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }

        var path = parts[1]
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }
        if path == "/" || path.isEmpty {
            path = "/index.html"
        }
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        let fileURL = rootDir.appendingPathComponent(path)
        var fileData: Data? = nil
        var mimeType = "application/octet-stream"

        if FileManager.default.fileExists(atPath: fileURL.path) {
            fileData = try? Data(contentsOf: fileURL)
        } else {
            // SPA fallback to index.html
            let indexURL = rootDir.appendingPathComponent("index.html")
            fileData = try? Data(contentsOf: indexURL)
            path = "index.html"
        }

        if path.hasSuffix(".html") { mimeType = "text/html; charset=utf-8" }
        else if path.hasSuffix(".js") || path.hasSuffix(".mjs") { mimeType = "application/javascript; charset=utf-8" }
        else if path.hasSuffix(".css") { mimeType = "text/css; charset=utf-8" }
        else if path.hasSuffix(".svg") { mimeType = "image/svg+xml" }
        else if path.hasSuffix(".png") { mimeType = "image/png" }
        else if path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") { mimeType = "image/jpeg" }
        else if path.hasSuffix(".json") { mimeType = "application/json" }
        else if path.hasSuffix(".woff2") { mimeType = "font/woff2" }

        guard let data = fileData else {
            let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            _ = notFound.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        let header = "HTTP/1.1 200 OK\r\nContent-Type: \(mimeType)\r\nContent-Length: \(data.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        _ = header.utf8CString.withUnsafeBufferPointer {
            write(clientSocket, $0.baseAddress, $0.count - 1)
        }
        data.withUnsafeBytes { rawBuffer in
            if let ptr = rawBuffer.baseAddress {
                _ = write(clientSocket, ptr, data.count)
            }
        }
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    deinit {
        stop()
    }
}

// MARK: - Main Application Delegate
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKUIDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var staticServer: MiniStaticServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        window.minSize = NSSize(width: 960, height: 640)
        window.delegate = self

        // WebKit Configuration
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: window.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.uiDelegate = self
        webView.navigationDelegate = self
        window.contentView!.addSubview(webView)

        setupMainMenu()
        loadContent()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - WKUIDelegate Camera & Microphone Media Permission Auto-grant
    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    func loadContent() {
        // 1. Check if Vite dev/preview server is live on port 5174
        if let devURL = URL(string: "http://localhost:5174/") {
            var request = URLRequest(url: devURL, timeoutInterval: 1.0)
            request.httpMethod = "HEAD"
            let session = URLSession(configuration: .ephemeral)
            let task = session.dataTask(with: request) { [weak self] (_, response, error) in
                DispatchQueue.main.async {
                    if error == nil, let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                        self?.webView.load(URLRequest(url: devURL))
                    } else {
                        self?.startOfflineStaticServerAndLoad()
                    }
                }
            }
            task.resume()
        } else {
            startOfflineStaticServerAndLoad()
        }
    }

    func startOfflineStaticServerAndLoad() {
        // Locate embedded dist bundle directory
        var distDir: URL? = Bundle.main.url(forResource: "dist", withExtension: nil)
        if distDir == nil {
            let direct = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/dist")
            if FileManager.default.fileExists(atPath: direct.path) {
                distDir = direct
            }
        }

        guard let targetDist = distDir else {
            // Direct fallback to fileURL
            if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "dist") {
                webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
            }
            return
        }

        if staticServer == nil {
            staticServer = MiniStaticServer(rootDir: targetDist)
            _ = staticServer?.start()
        }

        if let server = staticServer, server.port > 0 {
            if let localURL = URL(string: "http://127.0.0.1:\(server.port)/index.html") {
                webView.load(URLRequest(url: localURL))
                return
            }
        }

        // Secondary fallback
        let indexURL = targetDist.appendingPathComponent("index.html")
        webView.loadFileURL(indexURL, allowingReadAccessTo: targetDist)
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

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

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
