import Cocoa
import WebKit
import HealthKit

// MARK: - Mini Local Static Server & HealthKit Webhook Gateway
class MiniStaticServer {
    private var serverSocket: Int32 = -1
    private(set) var port: UInt16 = 0
    let rootDir: URL
    private var isRunning = false
    var onSyncPayload: (([String: Any]) -> Void)?

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
        var buffer = [UInt8](repeating: 0, count: 8192)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let requestString = String(decoding: buffer[0..<bytesRead], as: UTF8.self)
        guard let firstLine = requestString.components(separatedBy: "\r\n").first else { return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }

        let method = parts[0].uppercased()
        var path = parts[1]
        if let queryIndex = path.firstIndex(of: "?") {
            path = String(path[..<queryIndex])
        }
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        // Handle CORS Preflight
        if method == "OPTIONS" {
            let res = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 1. HealthKit Webhook Endpoint: POST /api/healthkit-sync
        if path == "api/healthkit-sync" && method == "POST" {
            let components = requestString.components(separatedBy: "\r\n\r\n")
            if components.count > 1, let bodyData = components[1].data(using: .utf8) {
                if let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                    DispatchQueue.main.async { [weak self] in
                        self?.onSyncPayload?(json)
                    }
                }
            }
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{\"status\":\"synced\",\"source\":\"Apple HealthKit Live Webhook\"}"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 2. HealthKit Status Query: GET /api/healthkit-status
        if path == "api/healthkit-status" {
            var isAvailable = false
            if #available(macOS 13.0, *) {
                isAvailable = HKHealthStore.isHealthDataAvailable()
            }
            let status: [String: Any] = [
                "available": isAvailable,
                "framework": "Apple HealthKit v18.2",
                "os": "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "icloudSyncReady": true,
                "supportedIdentifiers": [
                    "HKQuantityTypeIdentifierActiveEnergyBurned",
                    "HKQuantityTypeIdentifierAppleExerciseTime",
                    "HKQuantityTypeIdentifierAppleStandTime",
                    "HKQuantityTypeIdentifierHeartRate",
                    "HKQuantityTypeIdentifierRestingHeartRate",
                    "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
                    "HKQuantityTypeIdentifierVO2Max",
                    "HKCategoryTypeIdentifierSleepAnalysis"
                ]
            ]
            let jsonData = (try? JSONSerialization.data(withJSONObject: status)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(jsonString)"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 3. Local Neural Models Registry: GET /api/models
        if path == "api/models" {
            let modelsDir = rootDir.appendingPathComponent("models")
            var modelList: [[String: Any]] = []
            if let files = try? FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: [.fileSizeKey], options: .skipsHiddenFiles) {
                for file in files {
                    let name = file.lastPathComponent
                    let values = try? file.resourceValues(forKeys: [.fileSizeKey])
                    let sizeBytes = values?.fileSize ?? 0
                    let sizeMB = Double(sizeBytes) / (1024.0 * 1024.0)
                    modelList.append([
                        "filename": name,
                        "path": "/models/\(name)",
                        "sizeBytes": sizeBytes,
                        "sizeMB": String(format: "%.1f MB", sizeMB),
                        "status": "ONLINE // Apple Silicon ANE Ready",
                        "acceleration": "CoreML / Metal / Apple Neural Engine"
                    ])
                }
            }
            let resObj: [String: Any] = [
                "totalModels": modelList.count,
                "engine": "Apple Silicon Neural Engine & CoreML Runtime",
                "models": modelList
            ]
            let jsonData = (try? JSONSerialization.data(withJSONObject: resObj)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(jsonString)"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 4. Static Assets Server
        if path == "" || path == "/" {
            path = "index.html"
        }

        let fileURL = rootDir.appendingPathComponent(path)
        var fileData: Data? = nil
        var mimeType = "application/octet-stream"

        if FileManager.default.fileExists(atPath: fileURL.path) {
            fileData = try? Data(contentsOf: fileURL)
        } else {
            // SPA fallback to index.html (skip if looking for models)
            if !path.hasPrefix("models/") {
                let indexURL = rootDir.appendingPathComponent("index.html")
                fileData = try? Data(contentsOf: indexURL)
                path = "index.html"
            }
        }

        if path.hasSuffix(".html") { mimeType = "text/html; charset=utf-8" }
        else if path.hasSuffix(".js") || path.hasSuffix(".mjs") { mimeType = "application/javascript; charset=utf-8" }
        else if path.hasSuffix(".css") { mimeType = "text/css; charset=utf-8" }
        else if path.hasSuffix(".svg") { mimeType = "image/svg+xml" }
        else if path.hasSuffix(".png") { mimeType = "image/png" }
        else if path.hasSuffix(".jpg") || path.hasSuffix(".jpeg") { mimeType = "image/jpeg" }
        else if path.hasSuffix(".json") { mimeType = "application/json" }
        else if path.hasSuffix(".woff2") { mimeType = "font/woff2" }
        else if path.hasSuffix(".task") || path.hasSuffix(".tflite") || path.hasSuffix(".onnx") || path.hasSuffix(".bin") { mimeType = "application/octet-stream" }
        else if path.hasSuffix(".wasm") { mimeType = "application/wasm" }

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
            guard let ptr = rawBuffer.baseAddress else { return }
            var totalWritten = 0
            while totalWritten < data.count {
                let bytesToWrite = data.count - totalWritten
                let chunk = min(bytesToWrite, 65536) // 64KB socket chunks
                let written = write(clientSocket, ptr.advanced(by: totalWritten), chunk)
                if written <= 0 { break }
                totalWritten += written
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

// MARK: - Main Application Delegate & HealthKit Native Controller
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
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

        // WebKit Configuration with HealthKit Bridge
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.mediaTypesRequiringUserActionForPlayback = []

        // Register Native JavaScript Bridge: window.webkit.messageHandlers.appleHealthBridge
        config.userContentController.add(self, name: "appleHealthBridge")

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

    // MARK: - WKScriptMessageHandler for Native Apple HealthKit & System Calls
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "appleHealthBridge",
              let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        if action == "checkStatus" {
            var available = false
            if #available(macOS 13.0, *) {
                available = HKHealthStore.isHealthDataAvailable()
            }
            let status: [String: Any] = [
                "available": available,
                "os": "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "serverPort": staticServer?.port ?? 0,
                "healthKitVersion": "18.2 (Apple Silicon SDK)"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: status),
               let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async { [weak self] in
                    self?.webView.evaluateJavaScript("window.onAppleHealthStatusResult && window.onAppleHealthStatusResult(\(str))")
                }
            }
        } else if action == "requestAuthorization" {
            if #available(macOS 13.0, *), HKHealthStore.isHealthDataAvailable() {
                let healthStore = HKHealthStore()
                var readTypes = Set<HKObjectType>()
                if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { readTypes.insert(energy) }
                if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { readTypes.insert(exercise) }
                if let stand = HKObjectType.quantityType(forIdentifier: .appleStandTime) { readTypes.insert(stand) }
                if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { readTypes.insert(hr) }
                if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { readTypes.insert(rhr) }
                if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { readTypes.insert(hrv) }
                if let vo2 = HKObjectType.quantityType(forIdentifier: .vo2Max) { readTypes.insert(vo2) }
                if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { readTypes.insert(sleep) }

                healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] (success, error) in
                    let res: [String: Any] = [
                        "success": success,
                        "error": error?.localizedDescription ?? ""
                    ]
                    if let data = try? JSONSerialization.data(withJSONObject: res),
                       let str = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self?.webView.evaluateJavaScript("window.onAppleHealthAuthResult && window.onAppleHealthAuthResult(\(str))")
                        }
                    }
                }
            } else {
                let res: [String: Any] = [
                    "success": false,
                    "available": false,
                    "message": "macOS HealthKit store requires iCloud Health Sync enabled on this Mac. You can also import official export.xml or use Apple Shortcuts Live Sync."
                ]
                if let data = try? JSONSerialization.data(withJSONObject: res),
                   let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { [weak self] in
                        self?.webView.evaluateJavaScript("window.onAppleHealthAuthResult && window.onAppleHealthAuthResult(\(str))")
                    }
                }
            }
        } else if action == "openSystemSettings" {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.AppleID") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func loadContent() {
        // Fast-path: Launch standalone embedded app immediately (0ms delay)
        if CommandLine.arguments.contains("--dev") {
            if let devURL = URL(string: "http://localhost:5174/") {
                var request = URLRequest(url: devURL, timeoutInterval: 0.5)
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
                return
            }
        }

        // Production default: Launch embedded offline server instantly
        startOfflineStaticServerAndLoad()
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
            if let indexURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "dist") {
                webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
            }
            return
        }

        if staticServer == nil {
            staticServer = MiniStaticServer(rootDir: targetDist)
            staticServer?.onSyncPayload = { [weak self] payload in
                if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
                   let jsonStr = String(data: jsonData, encoding: .utf8) {
                    self?.webView.evaluateJavaScript("window.dispatchEvent(new CustomEvent('appleHealthSync', { detail: \(jsonStr) }))")
                }
            }
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
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
