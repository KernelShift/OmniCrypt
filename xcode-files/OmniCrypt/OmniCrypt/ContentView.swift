import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var runner: Runner
    @EnvironmentObject var openHandler: OpenHandler

    @AppStorage("autoPub")  private var autoPub = true
    @AppStorage("pubPath")  private var pubPath = ""
    @AppStorage("autoPriv") private var autoPriv = true
    @AppStorage("privPath") private var privPath = ""

    @State private var srcPath = ""
    @State private var destDir = ""
    @State private var keyPaste = ""
    @State private var useKeyFile = true

    var mode: OmniMode? {
        guard !srcPath.isEmpty else { return nil }
        return srcPath.lowercased().hasSuffix(".omni") ? .decrypt : .encrypt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("🔐 OmniCrypt").font(.largeTitle).padding(.bottom, 4)

            // Source picker
            HStack {
                Text("Source:")
                TextField("Choose a file or folder…", text: $srcPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse…") { pickSource() }
            }

            // Destination picker
            HStack {
                Text("Destination:")
                TextField("Leave blank to use source folder", text: $destDir)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") { pickDest() }
            }

            // Mode indicator
            HStack(spacing: 10) {
                Text("Mode:")
                Text(modeText)
                    .fontWeight(.semibold)
                    .foregroundStyle(modeColor)
            }

            // Key source
            Picker("Key source", selection: $useKeyFile) {
                Text("Use key file").tag(true)
                Text("Paste key").tag(false)
            }.pickerStyle(.segmented)

            if useKeyFile {
                HStack {
                    Text(mode == .decrypt ? "Private key:" : "Public key:")
                    TextField(defaultKeyPath, text: bindingForKeyPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { pickKey() }
                    Toggle("Use automatically", isOn: bindingForAutoToggle)
                        .toggleStyle(.checkbox)
                        .help("If enabled, this key file will be used by default.")
                }
            } else {
                TextEditor(text: $keyPaste)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.gray.opacity(0.3)))
                    .help("Paste full PEM, including BEGIN/END lines.")
            }

            HStack {
                Spacer()
                Button(action: run) {
                    Text(actionTitle)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(runner.busy || srcPath.isEmpty || (useKeyFile && bindingForKeyPath.wrappedValue.isEmpty))
            }

            Divider()
            Text("Output:")
            ScrollView {
                Text(runner.log)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 140)
        }
        .padding(18)
        .frame(minWidth: 720, minHeight: 560)

        // Handle “Open With” / double-click .omni
        .onReceive(openHandler.$pendingPaths) { paths in
            guard let last = paths.last else { return }
            srcPath = last
            useKeyFile = (mode == .decrypt ? autoPriv : autoPub)
            // Optional: auto-run here if you want:
            // run()
        }

        // Also handle "open -a OmniCrypt <file>" scenario
        .onAppear {
            let args = ProcessInfo.processInfo.arguments.dropFirst()
            if srcPath.isEmpty, let path = args.first { srcPath = path }
            useKeyFile = (mode == .decrypt ? autoPriv : autoPub)
        }
    }

    // MARK: - Derived UI bits
    private var actionTitle: String { mode == .decrypt ? "Decrypt" : "Encrypt" }
    private var modeText: String { mode == .decrypt ? "Decrypt (.omni detected)" : "Encrypt" }
    private var modeColor: Color { mode == .decrypt ? .orange : .blue }
    private var defaultKeyPath: String {
        mode == .decrypt ? "Path to privkey.txt / .pem" : "Path to pubkey.txt / .pem"
    }
    private var bindingForKeyPath: Binding<String> {
        Binding(
            get: { mode == .decrypt ? privPath : pubPath },
            set: { newVal in
                if mode == .decrypt { privPath = newVal } else { pubPath = newVal }
            }
        )
    }
    private var bindingForAutoToggle: Binding<Bool> {
        Binding(
            get: { mode == .decrypt ? autoPriv : autoPub },
            set: { newVal in
                if mode == .decrypt { autoPriv = newVal } else { autoPub = newVal }
            }
        )
    }

    // MARK: - Pickers (using allowedContentTypes)
    private func pickSource() {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = true
        p.allowsMultipleSelection = false
        // Any file or folder:
        p.allowedContentTypes = [.item]
        if p.runModal() == .OK, let url = p.url {
            srcPath = url.path
        }
    }

    private func pickDest() {
        let p = NSOpenPanel()
        p.canChooseFiles = false
        p.canChooseDirectories = true
        p.allowsMultipleSelection = false
        p.allowedContentTypes = [.folder]
        if p.runModal() == .OK, let url = p.url {
            destDir = url.path
        }
    }

    private func pickKey() {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = false
        p.allowsMultipleSelection = false
        // Accept .txt and .pem
        let pem = UTType(filenameExtension: "pem")
        let txt = UTType.plainText
        p.allowedContentTypes = [pem, txt].compactMap { $0 }
        if p.runModal() == .OK, let url = p.url {
            bindingForKeyPath.wrappedValue = url.path
        }
    }

    // MARK: - Action
    private func run() {
        guard let m = mode else { return }
        let dest = destDir.isEmpty ? nil : destDir
        let keyFilePath = (m == .decrypt) ? privPath : pubPath
        let paste = useKeyFile ? nil : keyPaste
        runner.run(mode: m, src: srcPath, destDir: dest,
                   useKeyFile: useKeyFile, keyFilePath: keyFilePath, pasteKey: paste)
    }
}
