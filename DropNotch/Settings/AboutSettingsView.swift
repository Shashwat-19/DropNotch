import SwiftUI

/// Version, licence, third-party notices and the project page.
struct AboutSettingsView: View {
    @State private var showsNotices = false

    var body: some View {
        Form {
            LabeledContent("Version", value: Self.version)
            LabeledContent("Licence", value: "MIT")
            LabeledContent("Third-party notices") {
                Button("Show") { showsNotices = true }
            }
            LabeledContent("Source code") {
                Link("github.com/Shashwat-19/DropNotch", destination: URL(string: "https://github.com/Shashwat-19/DropNotch")!)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showsNotices) {
            VStack(alignment: .trailing) {
                ScrollView {
                    Text(Self.notices).font(.callout.monospaced()).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("Done") { showsNotices = false }.keyboardShortcut(.defaultAction)
            }
            .padding()
            .frame(width: 520, height: 420)
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    /// THIRD_PARTY_NOTICES.md, bundled as a resource by project.yml.
    static var notices: String {
        Bundle.main.url(forResource: "THIRD_PARTY_NOTICES", withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "The notices file is missing from this build."
    }
}
