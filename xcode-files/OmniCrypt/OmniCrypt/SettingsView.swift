import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("autoPub")  private var autoPub = true
    @AppStorage("pubPath")  private var pubPath = ""
    @AppStorage("autoPriv") private var autoPriv = true
    @AppStorage("privPath") private var privPath = ""

    var body: some View {
        Form {
            Section("Public key (encrypt)") {
                Toggle("Look for pubkey.txt", isOn: $autoPub)
                HStack {
                    TextField("Path to pubkey.txt or .pem", text: $pubPath)
                    Button("Browse") { browseKey { pubPath = $0 } }
                }
            }
            Section("Private key (decrypt)") {
                Toggle("Look for privkey.txt", isOn: $autoPriv)
                HStack {
                    TextField("Path to privkey.txt or .pem", text: $privPath)
                    Button("Browse") { browseKey { privPath = $0 } }
                }
            }
        }
        .padding()
        .frame(width: 520)
    }

    private func browseKey(onPick: (String) -> Void) {
        let p = NSOpenPanel()
        p.canChooseFiles = true
        p.canChooseDirectories = false
        p.allowsMultipleSelection = false
        let pem = UTType(filenameExtension: "pem")
        let txt = UTType.plainText
        p.allowedContentTypes = [pem, txt].compactMap { $0 }
        if p.runModal() == .OK, let url = p.url {
            onPick(url.path)
        }
    }
}
