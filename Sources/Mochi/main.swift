import AppKit

let arguments = CommandLine.arguments
if let i = arguments.firstIndex(of: "--render-icon"), i + 1 < arguments.count {
    Exporters.exportIconset(to: arguments[i + 1])
    exit(0)
}
if let i = arguments.firstIndex(of: "--render-previews"), i + 1 < arguments.count {
    Exporters.exportPreviews(to: arguments[i + 1])
    exit(0)
}
if let i = arguments.firstIndex(of: "--render-zoom"), i + 1 < arguments.count {
    Exporters.exportZoom(to: arguments[i + 1])
    exit(0)
}
if let i = arguments.firstIndex(of: "--render-ui"), i + 1 < arguments.count {
    setenv("MOCHI_DATA_DIR", NSTemporaryDirectory() + "mochi-snapshots", 1)
    Exporters.exportUI(to: arguments[i + 1])
    exit(0)
}
if arguments.contains("--self-test") {
    setenv("MOCHI_DATA_DIR", NSTemporaryDirectory() + "mochi-selftest", 1)
    Exporters.selfTest()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
