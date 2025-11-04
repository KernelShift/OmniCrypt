import Foundation
import AppKit

enum OmniMode { case encrypt, decrypt }

final class Runner: ObservableObject {
    @Published var log: String = ""
    @Published var busy: Bool = false

    // ViewModel/Runner.swift
    var helperPath: String? {
        Bundle.main.url(forAuxiliaryExecutable: "omni")?.path
    }

    func run(mode: OmniMode,
             src: String,
             destDir: String?,
             useKeyFile: Bool,
             keyFilePath: String?,
             pasteKey: String?) {

        guard let exe = helperPath else {
            log += "Helper not found in bundle.\n"
            return
        }

        // quick sanity checks
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: exe)
        let canExec = fm.isExecutableFile(atPath: exe)
        log += "DEBUG: Helper path → \(exe)\n"
        log += "DEBUG: exists=\(exists) exec=\(canExec)\n"
        if !exists || !canExec { return }

        busy = true

        var args: [String] = []
        switch mode {
        case .encrypt: args += ["--encrypt", src]
        case .decrypt: args += ["--decrypt", src]
        }
        if let destDir, !destDir.isEmpty { args += ["--dest", destDir] }
        args += ["--quiet", "--delete-source"]

        var needsPaste = false
        switch mode {
        case .encrypt:
            if useKeyFile, let p = keyFilePath, !p.isEmpty {
                args += ["--pubkey-file", (p as NSString).expandingTildeInPath]
            } else { args += ["--paste-pubkey"]; needsPaste = true }
        case .decrypt:
            if useKeyFile, let p = keyFilePath, !p.isEmpty {
                args += ["--privkey-file", (p as NSString).expandingTildeInPath]
            } else { args += ["--paste-privkey"]; needsPaste = true }
        }

        log += "DEBUG: Launching → \(exe)\n"
        log += "DEBUG: Args → \(args.joined(separator: " "))\n"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: exe)
        task.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        var inPipe: Pipe?
        if needsPaste {
            inPipe = Pipe()
            task.standardInput = inPipe
        }

        // Stream output to avoid pipe deadlock
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            guard let s = self else { return }
            if let str = String(data: h.availableData, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async { s.log += str }
            }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            guard let s = self else { return }
            if let str = String(data: h.availableData, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async { s.log += str }
            }
        }

        task.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                self?.busy = false
                self?.log += "DEBUG: Exit status \(p.terminationStatus)\n"
            }
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try task.run()

                if needsPaste, let paste = pasteKey {
                    inPipe?.fileHandleForWriting.write((paste + "\n").data(using: .utf8)!)
                    inPipe?.fileHandleForWriting.closeFile()
                }
            } catch {
                DispatchQueue.main.async {
                    self.log += "Failed to launch helper: \(error.localizedDescription)\n"
                    self.busy = false
                }
            }
        }
    }
}
