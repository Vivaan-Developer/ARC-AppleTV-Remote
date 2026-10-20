import SwiftUI

struct ContentView: View {
    @StateObject private var tv = AppleTVClient()
    @State private var mode = 0
    private let accent = Color(red: 0.49, green: 0.60, blue: 1.0)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    devicePanel
                    HStack(alignment: .top, spacing: 20) {
                        remotePanel.frame(maxWidth: .infinity)
                        extrasPanel.frame(maxWidth: .infinity)
                    }
                    HStack(spacing: 8) {
                        Circle().fill(tv.connected ? Color.green : Color.orange).frame(width: 7, height: 7)
                        Text(tv.status).font(.caption).foregroundColor(.white.opacity(0.55))
                    }.padding(.horizontal, 4)
                }
                .padding(30)
            }
        }
        .frame(minWidth: 930, minHeight: 660)
        .background(Color(red: 0.055, green: 0.065, blue: 0.095))
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                Image(systemName: "appletvremote.gen4.fill")
                    .font(.system(size: 26)).foregroundColor(accent)
                Text("ARC").font(.system(size: 30, weight: .bold, design: .rounded))
            }
            Text("APPLE REMOTE CORE")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.43))
            Divider().overlay(Color.white.opacity(0.1))
            Label("Apple TV Remote", systemImage: "tv.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.18)).cornerRadius(12)
            Spacer()
            Text("VERSION 3.6").font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.38))
        }
        .padding(22).frame(width: 215)
        .background(Color.white.opacity(0.035))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Apple TV Remote")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Control your Apple TV, instantly.")
                    .font(.subheadline).foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(tv.connected ? Color.green : Color.gray).frame(width: 8, height: 8)
                Text(tv.connected ? "Connected" : "Disconnected")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(Color.white.opacity(0.08)).clipShape(Capsule())
        }
    }

    private var devicePanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label("Your Devices", systemImage: "display")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { tv.search() }) {
                    Label("Find Apple TVs", systemImage: "arrow.clockwise")
                }.disabled(tv.busy)
                if tv.busy { ProgressView().controlSize(.small) }
                Button(action: { tv.pair() }) {
                    Label("Pair", systemImage: "lock.shield")
                }
                .disabled(tv.selected == nil || tv.busy)
                Button(action: { tv.connectSelected() }) {
                    Label("Connect", systemImage: "link")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(tv.selected == nil || tv.busy)
            }
            if tv.pairingPINRequested {
                HStack(spacing: 8) {
                    TextField("Apple TV PIN", text: $tv.pairingPIN)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    Button("Confirm PIN") { tv.submitPairingPIN() }
                        .disabled(tv.pairingPIN.isEmpty || tv.busy)
                    Button("Cancel") { tv.cancelPairing() }
                }
                Text("Follow the instructions shown on your Apple TV.")
                    .font(.caption)
            }
            if tv.devices.isEmpty {
                Text("Select ‘Find Apple TVs’ to discover devices on your network.")
                    .font(.caption).foregroundColor(.white.opacity(0.45))
            } else {
                ForEach(tv.devices) { device in
                    Button(action: { tv.choose(device) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "appletv.fill")
                                .font(.title3).foregroundColor(accent)
                                .frame(width: 34, height: 34)
                                .background(accent.opacity(0.13)).cornerRadius(9)
                            Text(device.name).font(.system(size: 13, weight: .medium))
                            Spacer()
                            if tv.selected?.id == device.id {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(accent)
                            } else {
                                Image(systemName: "circle").foregroundColor(.white.opacity(0.25))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(tv.selected?.id == device.id ? 0.10 : 0.04))
                        .cornerRadius(12)
                    }.buttonStyle(.plain)
                }
            }
        }.padding(19).panelStyle()
    }

    private var remotePanel: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Navigation")
                    .font(.system(size: 16, weight: .semibold))
                    .fixedSize(horizontal: true, vertical: false)
                Spacer()
                Picker("Navigation", selection: $mode) {
                    Text("D-pad").tag(0)
                    Text("Touchpad").tag(1)
                }.labelsHidden().pickerStyle(.segmented).frame(width: 190)
            }
            if mode == 0 {
                VStack(spacing: 6) {
                    remoteKey("chevron.up", "Up", "up").frame(width: 108)
                    HStack(spacing: 6) {
                        remoteKey("chevron.left", "Left", "left")
                        remoteKey("circle.inset.filled", "Select", "select", prominent: true)
                        remoteKey("chevron.right", "Right", "right")
                    }
                    remoteKey("chevron.down", "Down", "down").frame(width: 108)
                }.padding(.vertical, 9)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.065))
                        .overlay(RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    VStack(spacing: 12) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 30)).foregroundColor(accent)
                        Text("Swipe to navigate · Click to select")
                            .font(.caption).foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(height: 242)
                .contentShape(Rectangle())
                .onTapGesture { tv.send("select") }
                .gesture(DragGesture(minimumDistance: 22).onEnded { g in
                    if abs(g.translation.width) > abs(g.translation.height) {
                        tv.send(g.translation.width > 0 ? "right" : "left")
                    } else {
                        tv.send(g.translation.height > 0 ? "down" : "up")
                    }
                })
            }
            HStack(spacing: 8) {
                remoteKey("chevron.backward", "Back", "menu")
                remoteKey("house.fill", "Home", "home")
                remoteKey("playpause.fill", "Play/Pause", "play_pause")
            }
        }.padding(20).panelStyle()
    }

    private var extrasPanel: some View {
        VStack(alignment: .leading, spacing: 19) {
            Text("Playback & Power").font(.system(size: 16, weight: .semibold))
            Text("MEDIA").sectionLabel()
            HStack(spacing: 8) {
                remoteKey("backward.end.fill", "Previous", "previous")
                remoteKey("forward.end.fill", "Next", "next")
            }
            Text("VOLUME").sectionLabel()
            HStack(spacing: 8) {
                remoteKey("speaker.minus.fill", "Volume −", "volume_down")
                remoteKey("speaker.plus.fill", "Volume +", "volume_up")
            }
            Text("POWER").sectionLabel()
            HStack(spacing: 8) {
                remoteKey("power", "Wake", "turn_on")
                remoteKey("moon.fill", "Sleep", "turn_off")
            }
            Text("Volume control depends on your Apple TV audio setup.")
                .font(.caption).foregroundColor(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }.padding(20).panelStyle()
    }

    private func remoteKey(_ symbol: String, _ title: String, _ command: String, prominent: Bool = false) -> some View {
        Button(action: { tv.send(command) }) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 21, weight: .medium))
                Text(title).font(.system(size: 11, weight: .medium))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).frame(height: 72)
            .foregroundColor(prominent ? .white : .white.opacity(0.85))
            .background(prominent ? accent.opacity(0.72) : Color.white.opacity(0.085))
            .cornerRadius(15)
        }
        .buttonStyle(.plain)
        .disabled(!tv.connected)
    }
}

private extension View {
    func panelStyle() -> some View {
        self.background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }
    func sectionLabel() -> some View {
        self.font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white.opacity(0.42))
    }
}
