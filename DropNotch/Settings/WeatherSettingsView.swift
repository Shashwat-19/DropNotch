import SwiftUI

/// Settings › Weather (D53): choose the city the Weather card shows, and what that sends.
struct WeatherSettingsView: View {
    let module: WeatherModule
    let registry: ModuleRegistry

    @State private var query = ""
    @State private var results: [WeatherPlace] = []
    @State private var searching = false
    @State private var message: LocalizedStringKey?

    var body: some View {
        Form {
            Section {
                Toggle("Weather card", isOn: Binding(get: { registry.enabledIDs.contains(module.id) },
                                                     set: { registry.setEnabled(module.id, $0) }))
                if let place = module.place {
                    LabeledContent("City", value: place.fullName)
                    Button("Remove City") { module.choose(nil) }
                }
            }
            Section {
                HStack {
                    TextField("City", text: $query, prompt: Text("Search for a city"))
                        .onSubmit(search)
                    Button("Search", action: search)
                        .disabled(searching || query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if searching { ProgressView().controlSize(.small) }
                if let message { Text(message).foregroundStyle(.secondary) }
                ForEach(Array(results.enumerated()), id: \.offset) { _, place in
                    Button(place.fullName) {
                        module.choose(place)
                        results = []
                        query = ""
                        message = nil
                    }
                }
            } header: {
                Text(module.place == nil ? "Choose a city" : "Change city")
            } footer: {
                Text("Searching sends what you type to Open-Meteo's geocoding service. After that, DropNotch sends only the city's coordinates, rounded to about 1 km, to Open-Meteo's weather and air-quality services: when the Weather card shows and its reading is more than 30 minutes old. No account and no Location permission. Nothing is logged.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func search() {
        let text = query
        guard !searching, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        searching = true
        message = nil
        Task {
            defer { searching = false }
            do {
                results = try await module.search(text)
                if results.isEmpty { message = "No city matches “\(text)”." }
            } catch {
                results = []
                message = "Couldn't search. Check your connection and try again."
            }
        }
    }
}
