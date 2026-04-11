## NaiveVPN iOS Client

Minimal iOS client for NaiveProxy built around a Packet Tunnel extension and
`Libbox.xcframework` from the official `sing-box` Apple runtime.

### What it does

- Shows `host`, `type`, `port`, `user`, and `password`
- Generates a sing-box config for a Naive outbound
- Starts and stops an iOS Packet Tunnel VPN from a single button

### Project layout

- `NaiveVPN/`: iOS app target
- `NaiveTunnelExtension/`: Packet Tunnel extension target
- `Shared/`: config, model, and NetworkExtension helpers used by the app and extension
- `Scripts/build_libbox.sh`: builds `Libbox.xcframework`
- `Scripts/generate_xcodeproj.rb`: regenerates `NaiveVPN.xcodeproj`

### Build steps

1. Build the runtime framework:

```bash
cd app
./Scripts/build_libbox.sh
```

2. Open `NaiveVPN.xcodeproj` in Xcode.

3. Set your own signing team and bundle identifier prefix if needed:

- `BASE_PACKAGE_IDENTIFIER`

4. Build and run on a real iPhone or iPad.

### Notes

- Packet Tunnel VPNs do not work in the iOS Simulator.
- `Libbox.xcframework` is not committed here; build it locally with the script above.
- The generated config assumes full-tunnel Naive routing and maps the UI `type`
  field to Naive `HTTPS` or `QUIC`.
