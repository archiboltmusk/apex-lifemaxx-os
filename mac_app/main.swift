import Cocoa
import WebKit
import HealthKit
import AVFoundation
import Metal

// MARK: - Mini Local Static Server, Bonjour Discovery & Continuity Webhook Gateway
class MiniStaticServer: NSObject, NetServiceDelegate {
    private var serverSocket: Int32 = -1
    private(set) var port: UInt16 = 0
    let rootDir: URL
    let pairingToken: String
    private var isRunning = false
    private var netService: NetService?
    var onSyncPayload: (([String: Any]) -> Void)?

    init(rootDir: URL) {
        self.rootDir = rootDir
        self.pairingToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        super.init()
    }

    func start() -> Bool {
        if startSocket(preferredPort: 60159) {
            publishBonjour(port: port)
            return true
        }
        if startSocket(preferredPort: 0) {
            publishBonjour(port: port)
            return true
        }
        return false
    }

    private func startSocket(preferredPort: UInt16) -> Bool {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { return false }

        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = preferredPort.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian // Reachable from both 127.0.0.1 and iPhone on LAN Wi-Fi

        var bindAddr = addr
        let bindRes = withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
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

    private func publishBonjour(port: UInt16) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let name = Host.current().localizedName ?? "APEX Mac"
            let service = NetService(domain: "local.", type: "_apexos._tcp.", name: name, port: Int32(port))
            let txt = NetService.data(fromTXTRecord: ["token": Data(self.pairingToken.utf8)])
            service.setTXTRecord(txt)
            service.delegate = self
            service.publish()
            self.netService = service
        }
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

    private func readFullHTTPRequest(_ clientSocket: Int32) -> (String, Data)? {
        var accumulated = Data()
        var chunk = [UInt8](repeating: 0, count: 8192)
        var headerEndIndex: Data.Index? = nil
        var expectedBodyLength: Int = 0
        let separator = Data("\r\n\r\n".utf8)

        while true {
            let n = read(clientSocket, &chunk, chunk.count)
            if n <= 0 { break }
            accumulated.append(contentsOf: chunk[0..<n])

            if headerEndIndex == nil, let range = accumulated.range(of: separator) {
                headerEndIndex = range.upperBound
                let headerText = String(data: accumulated[..<range.lowerBound], encoding: .utf8) ?? ""
                for line in headerText.components(separatedBy: "\r\n") {
                    if line.lowercased().hasPrefix("content-length:") {
                        let val = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                        expectedBodyLength = Int(val) ?? 0
                    }
                }
            }

            if let endIdx = headerEndIndex {
                let currentBodyLen = accumulated.count - endIdx
                if currentBodyLen >= expectedBodyLength {
                    break
                }
            }
            if accumulated.count > 2_000_000 { break }
        }

        guard let endIdx = headerEndIndex else {
            return (String(decoding: accumulated, as: UTF8.self), Data())
        }
        let headerStr = String(data: accumulated[..<endIdx], encoding: .utf8) ?? ""
        let bodyData = accumulated[endIdx...]
        return (headerStr, Data(bodyData))
    }

    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }
        guard let (headerString, bodyData) = readFullHTTPRequest(clientSocket) else { return }

        guard let firstLine = headerString.components(separatedBy: "\r\n").first else { return }
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

        let headerLines = headerString.components(separatedBy: "\r\n")
        var originHeader: String? = nil
        var syncTokenHeader: String? = nil
        for line in headerLines {
            let lower = line.lowercased()
            if lower.hasPrefix("origin:") {
                originHeader = line.dropFirst("origin:".count).trimmingCharacters(in: .whitespaces)
            } else if lower.hasPrefix("x-apex-sync-token:") {
                syncTokenHeader = line.dropFirst("x-apex-sync-token:".count).trimmingCharacters(in: .whitespaces)
            }
        }
        let allowedOrigin: String = {
            if let orig = originHeader,
               orig.hasPrefix("http://127.0.0.1") || orig.hasPrefix("http://localhost") {
                return orig
            }
            return "http://127.0.0.1:\(port)"
        }()

        // Handle CORS Preflight
        if method == "OPTIONS" {
            let res = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, X-APEX-Sync-Token\r\nConnection: close\r\n\r\n"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 1. Unified HealthKit & Mobile Continuity Webhook: POST /api/healthkit-sync | /api/mobile-sync
        if (path == "api/healthkit-sync" || path == "api/mobile-sync") && method == "POST" {
            if syncTokenHeader != pairingToken {
                let unauth = "HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n{\"error\":\"invalid_pairing_token\"}"
                _ = unauth.utf8CString.withUnsafeBufferPointer {
                    write(clientSocket, $0.baseAddress, $0.count - 1)
                }
                return
            }
            if !bodyData.isEmpty,
               bodyData.count <= 262_144,
               let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                DispatchQueue.main.async { [weak self] in
                    self?.onSyncPayload?(json)
                }
            }
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n{\"status\":\"synced\",\"source\":\"Apple Continuity Bridge\"}"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 1a. Encrypted Snapshot Continuity Endpoint: GET / POST /api/backup-sync
        if path == "api/backup-sync" {
            if syncTokenHeader != pairingToken {
                let unauth = "HTTP/1.1 401 Unauthorized\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n{\"error\":\"invalid_pairing_token\"}"
                _ = unauth.utf8CString.withUnsafeBufferPointer {
                    write(clientSocket, $0.baseAddress, $0.count - 1)
                }
                return
            }

            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let backupDir = appSupport.appendingPathComponent("APEX OS", isDirectory: true)
            let backupURL = backupDir.appendingPathComponent("latest_backup.apexbackup.json")

            if method == "POST" {
                guard !bodyData.isEmpty,
                      bodyData.count <= 2_000_000,
                      let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                    let bad = "HTTP/1.1 400 Bad Request\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n{\"error\":\"invalid_backup_json\"}"
                    _ = bad.utf8CString.withUnsafeBufferPointer {
                        write(clientSocket, $0.baseAddress, $0.count - 1)
                    }
                    return
                }
                try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
                try? bodyData.write(to: backupURL, options: .atomic)
                DispatchQueue.main.async { [weak self] in
                    self?.onSyncPayload?([
                        "backupSnapshot": json,
                        "backupSizeBytes": bodyData.count,
                        "backupReceivedAt": ISO8601DateFormatter().string(from: Date())
                    ])
                }
                let okRes = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n{\"status\":\"stored\",\"bytes\":\(bodyData.count)}"
                _ = okRes.utf8CString.withUnsafeBufferPointer {
                    write(clientSocket, $0.baseAddress, $0.count - 1)
                }
                return
            }

            if method == "GET" {
                if let saved = try? Data(contentsOf: backupURL),
                   let savedStr = String(data: saved, encoding: .utf8) {
                    let okRes = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(savedStr)"
                    _ = okRes.utf8CString.withUnsafeBufferPointer {
                        write(clientSocket, $0.baseAddress, $0.count - 1)
                    }
                } else {
                    let miss = "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n{\"error\":\"no_backup_stored\"}"
                    _ = miss.utf8CString.withUnsafeBufferPointer {
                        write(clientSocket, $0.baseAddress, $0.count - 1)
                    }
                }
                return
            }
        }

        // 1b. Pairing Discovery Info: GET /api/pairing-info
        if path == "api/pairing-info" {
            let tele = AppDelegate.gatherDeviceTelemetry()
            let pairing: [String: Any] = [
                "host": tele["computerName"] ?? "APEX Mac",
                "localIP": tele["localIP"] ?? "127.0.0.1",
                "port": port,
                "syncToken": pairingToken,
                "bonjourService": "_apexos._tcp",
                "status": "ready"
            ]
            let jsonData = (try? JSONSerialization.data(withJSONObject: pairing)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(jsonString)"
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
                "framework": "Apple HealthKit",
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
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(jsonString)"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 2a. Physical iOS IPA Download & Package Status: GET /api/ios-package & GET /APEX-OS.ipa
        func locateIPAURL() -> URL? {
            let candidates = [
                self.rootDir.appendingPathComponent("APEX-OS.ipa"),
                self.rootDir.deletingLastPathComponent().appendingPathComponent("APEX-OS.ipa"),
                self.rootDir.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("APEX-OS.ipa"),
                URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("APEX-OS.ipa")
            ]
            return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
        }

        if path == "api/ios-package" {
            var resObj: [String: Any] = [
                "available": false,
                "filename": "APEX-OS.ipa",
                "downloadPath": "/APEX-OS.ipa",
                "xcodeprojPath": "ios_app/APEX_iOS.xcodeproj",
                "buildCommand": "bash scripts/build_ios.sh"
            ]
            if let ipaURL = locateIPAURL(),
               let attrs = try? FileManager.default.attributesOfItem(atPath: ipaURL.path),
               let sizeBytes = attrs[.size] as? NSNumber {
                let mb = Double(sizeBytes.int64Value) / (1024.0 * 1024.0)
                resObj["available"] = true
                resObj["sizeBytes"] = sizeBytes.int64Value
                resObj["sizeMB"] = String(format: "%.1f MB", mb)
                resObj["path"] = ipaURL.path
            }
            let jsonData = (try? JSONSerialization.data(withJSONObject: resObj)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(jsonString)"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        if path == "api/reveal-ipa" && method == "POST" {
            guard let ipaURL = locateIPAURL() else {
                let res = "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n{\"error\":\"missing\"}"
                _ = res.utf8CString.withUnsafeBufferPointer { write(clientSocket, $0.baseAddress, $0.count - 1) }
                return
            }
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            let exportURL = downloadsDir?.appendingPathComponent("APEX-OS.ipa") ?? ipaURL
            if exportURL != ipaURL {
                try? FileManager.default.removeItem(at: exportURL)
                try? FileManager.default.copyItem(at: ipaURL, to: exportURL)
            }
            let targetURL = FileManager.default.fileExists(atPath: exportURL.path) ? exportURL : ipaURL
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            }
            let okJSON = "{\"revealed\":true,\"path\":\"\(targetURL.path)\"}"
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(okJSON)"
            _ = res.utf8CString.withUnsafeBufferPointer { write(clientSocket, $0.baseAddress, $0.count - 1) }
            return
        }

        if path == "APEX-OS.ipa" || path == "downloads/APEX-OS.ipa" {
            guard let ipaURL = locateIPAURL(), let ipaData = try? Data(contentsOf: ipaURL) else {
                let msg = "{\"error\":\"APEX-OS.ipa not built yet. Run: bash scripts/build_ios.sh\"}"
                let res = "HTTP/1.1 404 Not Found\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(msg)"
                _ = res.utf8CString.withUnsafeBufferPointer {
                    write(clientSocket, $0.baseAddress, $0.count - 1)
                }
                return
            }
            let header = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Disposition: attachment; filename=\"APEX-OS.ipa\"\r\nContent-Length: \(ipaData.count)\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n"
            _ = header.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            ipaData.withUnsafeBytes { rawBuf in
                guard let base = rawBuf.baseAddress else { return }
                var offset = 0
                while offset < ipaData.count {
                    let chunk = min(ipaData.count - offset, 65536)
                    let written = write(clientSocket, base.advanced(by: offset), chunk)
                    if written <= 0 { break }
                    offset += written
                }
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
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(jsonString)"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 4. Real Host Hardware & Device Telemetry: GET /api/device-telemetry
        if path == "api/device-telemetry" {
            let telemetry = AppDelegate.gatherDeviceTelemetry()
            let jsonData = (try? JSONSerialization.data(withJSONObject: telemetry)) ?? Data()
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            let res = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: \(allowedOrigin)\r\nConnection: close\r\n\r\n\(jsonString)"
            _ = res.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        // 5. Static Assets Server (Strictly sandboxed within rootDir)
        if path == "" || path == "/" {
            path = "index.html"
        }

        let canonicalRoot = rootDir.standardizedFileURL.path
        let resolvedURL = rootDir.appendingPathComponent(path).standardizedFileURL
        guard resolvedURL.path == canonicalRoot || resolvedURL.path.hasPrefix(canonicalRoot + "/") else {
            let forbidden = "HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            _ = forbidden.utf8CString.withUnsafeBufferPointer {
                write(clientSocket, $0.baseAddress, $0.count - 1)
            }
            return
        }

        let fileURL = resolvedURL
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
        netService?.stop()
        netService = nil
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

        // Inject Real Mac Hardware & User Telemetry into Window
        let telemetry = AppDelegate.gatherDeviceTelemetry()
        if let teleData = try? JSONSerialization.data(withJSONObject: telemetry),
           let teleJson = String(data: teleData, encoding: .utf8) {
            let script = WKUserScript(
                source: "window.__macDeviceTelemetry = \(teleJson);",
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
            config.userContentController.addUserScript(script)
        }

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

    // MARK: - Real Hardware & System Telemetry
    static func gatherDeviceTelemetry() -> [String: Any] {
        let fullName = NSFullUserName()
        let shortName = NSUserName()
        let memBytes = ProcessInfo.processInfo.physicalMemory
        let memGB = Int(round(Double(memBytes) / (1024.0 * 1024.0 * 1024.0)))
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString

        // Camera discovery
        var cameras: [String] = []
        if #available(macOS 14.0, *) {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .external],
                mediaType: .video,
                position: .unspecified
            )
            for dev in discovery.devices {
                cameras.append(dev.localizedName)
            }
        } else {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .unspecified
            )
            for dev in discovery.devices {
                cameras.append(dev.localizedName)
            }
        }
        let primaryCamera = cameras.first ?? "Built-in Camera"

        // Audio discovery
        let micName = AVCaptureDevice.default(for: .audio)?.localizedName ?? "Built-in Microphone"

        // Hardware model, CPU & Metal GPU discovery
        func sysctlString(_ key: String) -> String? {
            var size = 0
            sysctlbyname(key, nil, &size, nil, 0)
            guard size > 0 else { return nil }
            var buf = [CChar](repeating: 0, count: size)
            sysctlbyname(key, &buf, &size, nil, 0)
            let val = String(cString: buf).trimmingCharacters(in: .whitespacesAndNewlines)
            return val.isEmpty ? nil : val
        }
        let hwModel = sysctlString("hw.model") ?? (Host.current().localizedName ?? "Apple Silicon Mac")
        let cpuBrand = sysctlString("machdep.cpu.brand_string") ?? "Apple Silicon"
        let metalDevice = MTLCreateSystemDefaultDevice()
        let gpuName = metalDevice?.name ?? "Apple Metal GPU"

        // Battery level parsing via pmset
        var battPercent = 100
        var battState = "AC Power"
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        proc.arguments = ["-g", "batt"]
        proc.standardOutput = pipe
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if let match = output.range(of: "\\d+%", options: .regularExpression) {
                    let numStr = output[match].replacingOccurrences(of: "%", with: "")
                    battPercent = Int(numStr) ?? 100
                    battState = output.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                } else {
                    let trimmed = output.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { battState = trimmed }
                }
            }
        }

        // Wi-Fi Local IP Discovery
        var localIP = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                if let interface = ptr?.pointee {
                    let addrFamily = interface.ifa_addr.pointee.sa_family
                    if addrFamily == UInt8(AF_INET) {
                        let name = String(cString: interface.ifa_name)
                        if name == "en0" || name == "en1" {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                            localIP = String(cString: hostname)
                            break
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        return [
            "userName": fullName.isEmpty ? (shortName.isEmpty ? "Mac User" : shortName) : fullName,
            "userLogin": shortName.isEmpty ? "user" : shortName,
            "computerName": Host.current().localizedName ?? hwModel,
            "modelName": hwModel,
            "chip": "\(cpuBrand) (\(cores)-Core)",
            "cores": cores,
            "ramGB": memGB,
            "ramString": "\(memGB) GB Unified Memory",
            "localIP": localIP,
            "primaryCamera": primaryCamera,
            "connectedCameras": cameras,
            "microphone": micName,
            "batteryPercent": battPercent,
            "batteryStatus": battState,
            "os": "macOS \(osVer)",
            "neuralEngine": metalDevice != nil ? "Apple Silicon ANE & Metal Active" : "CoreML CPU/GPU Compute",
            "metalGPU": "\(gpuName) (Metal)"
        ]
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
                "syncToken": staticServer?.pairingToken ?? "",
                "healthKitVersion": "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url,
              let host = url.host,
              host == "127.0.0.1" || host == "localhost",
              let token = staticServer?.pairingToken, !token.isEmpty else {
            return
        }
        let port = staticServer?.port ?? 0
        let js = "window.__apexSyncToken = \"\(token)\"; window.__apexServerPort = \(port); window.dispatchEvent(new CustomEvent('apexPairingReady', { detail: { syncToken: \"\(token)\", port: \(port) } }));"
        webView.evaluateJavaScript(js, completionHandler: nil)
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
