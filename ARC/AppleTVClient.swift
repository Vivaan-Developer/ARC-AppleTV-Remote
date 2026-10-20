import Foundation
import AppKit

struct AppleTVDevice: Identifiable, Hashable {
    let id:String
    let name:String
    let address:String
}

final class AppleTVClientWeakBox: @unchecked Sendable {
    weak var value: AppleTVClient?
    init(_ value: AppleTVClient) { self.value = value }
}

@MainActor
final class AppleTVClient: ObservableObject {
    @Published var status="Starting Apple TV…"
    @Published var busy=false
    @Published var devices:[AppleTVDevice]=[]
    @Published var selected:AppleTVDevice?
    @Published var connected=false
    @Published var pairingPINRequested=false
    @Published var pairingPIN=""

    private var process:Process?
    private var input:FileHandle?
    private var output:Pipe?
    private var pendingOutput = ""

    init() { status = "Ready • Search for Apple TV" }


    private func startService() {
        guard process == nil else { return }
        guard let helper=Bundle.main.url(forResource:"apple_tv_service",withExtension:"py") ??
                Bundle.main.url(forResource:"apple_tv_service",withExtension:"py",subdirectory:"node") else {
            status="Apple TV service missing"; return
        }
        let p=Process(), inp=Pipe(), out=Pipe()
        // Public-release builds use a packaged helper, so Python is not needed on the user's Mac.
        // Development builds retain the proven Python path as a fallback.
        let bundledService = Bundle.main.url(forResource: "arc_tv_service", withExtension: nil)
        let python313 = "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
        if let bundledService = bundledService,
           FileManager.default.isExecutableFile(atPath: bundledService.path) {
            p.executableURL = bundledService
            p.arguments = []
        } else if FileManager.default.isExecutableFile(atPath: python313) {
            p.executableURL = URL(fileURLWithPath: python313)
            p.arguments = [helper.path]
        } else {
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["python3", helper.path]
        }
        p.standardInput=inp; p.standardOutput=out; p.standardError=Pipe()
        let clientBox = AppleTVClientWeakBox(self)
        out.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if d.isEmpty { return }
            let text = String(data: d, encoding: .utf8) ?? ""
            Task { @MainActor in
                guard let client = clientBox.value else { return }
                client.pendingOutput += text
                while let newline = client.pendingOutput.firstIndex(of: "\n") {
                    let line = String(client.pendingOutput[..<newline])
                    client.pendingOutput.removeSubrange(...newline)
                    if let data = line.data(using: .utf8),
                       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        client.handle(obj)
                    }
                }
            }
        }
        p.terminationHandler = { _ in
            Task { @MainActor in
                guard let client = clientBox.value else { return }
                client.busy = false
                client.process = nil
                client.input = nil
                if !client.connected && client.status.contains("Searching") {
                    client.status = "Apple TV service stopped. Check support installation."
                }
            }
        }
        do {
            try p.run(); process=p; input=inp.fileHandleForWriting; output=out
        } catch { busy=false; status="Could not start Apple TV service" }
    }

    private func handle(_ o:[String:Any]) {
        let event=o["event"] as? String ?? ""
        if event=="ready" { busy=false; status="Ready • Search for Apple TV" }
        else if event=="status" { status=o["message"] as? String ?? "Working…" }
        else if event=="error" { busy=false; status=o["message"] as? String ?? "Apple TV error" }
        else if event=="pairing_pin" { busy=false; pairingPINRequested=true; status=o["message"] as? String ?? "Enter pairing PIN" }
        else if event=="paired" { busy=false; pairingPINRequested=false; pairingPIN=""; status=o["message"] as? String ?? "Paired" }
        else if event=="devices" {
            busy=false
            let a=o["devices"] as? [[String:Any]] ?? []
            devices=a.compactMap {
                guard let id=$0["id"] as? String,let n=$0["name"] as? String,let a=$0["address"] as? String else{return nil}
                return AppleTVDevice(id:id,name:n,address:a)
            }
            status=devices.isEmpty ? "No Apple TV found" : "\(devices.count) Apple TV device(s) found"
        } else if event=="connected" {
            busy=false; connected=true
            status="Connected • \(o["name"] as? String ?? "Apple TV")"
        } else if event=="command" { busy=false }
        else if event=="disconnected" { busy=false; connected=false; status="Disconnected" }
    }

    private func sendJSON(_ o:[String:Any]) {
        startService()
        guard let d=try? JSONSerialization.data(withJSONObject:o),
              var s=String(data:d,encoding:.utf8) else{return}
        s += "\n"
        input?.write(s.data(using:.utf8)!)
    }

    func search(){ busy=true; connected=false; status="Searching for Apple TV…"; sendJSON(["action":"scan"]) }
    func connectSelected(){ guard selected != nil else { status="Select an Apple TV first"; return }; busy=true; sendJSON(["action":"connect"]) }
    func choose(_ d:AppleTVDevice){ selected=d; connected=false; sendJSON(["action":"select","id":d.id]) }
    func send(_ c:String){
        guard selected != nil else { status="Search for Apple TV and select one first"; return }
        sendJSON(["action":"command","command":c])
    }

    func installSupport() {
        guard let installer = Bundle.main.url(forResource: "Install_AppleTV_Support", withExtension: "command") else {
            status = "Installer missing from app bundle"
            return
        }
        let opened = NSWorkspace.shared.open(installer)
        status = opened ? "Installation opened. After completion, press Search." : "Could not open installer"
    }

    func pair() {
        guard selected != nil else { status="Select an Apple TV first"; return }
        busy=true; status="Starting pairing…"; sendJSON(["action":"pair"])
    }
    func submitPairingPIN() {
        guard !pairingPIN.isEmpty else { status="Enter the PIN"; return }
        busy=true
        sendJSON(["action":"pair_pin", "pin":pairingPIN])
    }
    func cancelPairing() {
        pairingPINRequested=false; pairingPIN=""
        sendJSON(["action":"pair_cancel"])
    }
}
