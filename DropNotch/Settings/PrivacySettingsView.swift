import SwiftUI

/// Network, clipboard and tray data (D7, D25, D33, D34).
struct PrivacySettingsView: View {
    let registry: ModuleRegistry

    @AppStorage(ArtworkDownloader.downloadsOnKey) private var artworkDownloads = true

    var body: some View {
        Form {
            Section {
                Toggle("Download Spotify artwork", isOn: $artworkDownloads)
            } footer: {
                Text("One image per track from Spotify's image server, i.scdn.co. Off, the notch shows Spotify's icon. Music artwork never uses the network.")
                    .foregroundStyle(.secondary)
            }
            if let clipboard {
                Section {
                    Toggle("Clipboard history", isOn: Binding(get: { clipboard.isOn },
                                                              set: { $0 ? clipboard.turnOn() : clipboard.turnOff() }))
                    Toggle("Keep history after quitting", isOn: Binding(get: { clipboard.savesToDisk },
                                                                       set: { clipboard.setSavesToDisk($0) }))
                        .disabled(!clipboard.isOn)
                    Button("Clear Clipboard History") { clipboard.clear() }
                } footer: {
                    Text("Kept history is text and links only, saved on this Mac and never in backups. Images are always forgotten when DropNotch quits. Turning history or keeping off deletes the saved file.")
                        .foregroundStyle(.secondary)
                }
            }
            if let tray {
                Section {
                    Button("Clear Tray") { tray.clear() }
                        // A tray that isn't running hasn't loaded its list, so clearing it would wipe tray.json unseen.
                        .disabled(!registry.enabledIDs.contains(tray.id))
                } footer: {
                    Text("Removes every file from the tray. Your original files stay where they are.").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var clipboard: ClipboardModule? { registry.modules.lazy.compactMap { $0 as? ClipboardModule }.first }
    private var tray: FileTrayModule? { registry.modules.lazy.compactMap { $0 as? FileTrayModule }.first }
}
