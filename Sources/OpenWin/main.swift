import Cocoa
import Foundation

// Redirect stderr to log file for debugging
let logPath = "/tmp/openwin-debug.log"
FileManager.default.createFile(atPath: logPath, contents: nil)
let logFile = FileHandle(forWritingAtPath: logPath)!
logFile.seekToEndOfFile()

func zlog(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    logFile.write(line.data(using: .utf8)!)
    logFile.synchronizeFile()
}

zlog("OpenWin starting...")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
