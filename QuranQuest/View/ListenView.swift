import SwiftUI

struct RadioStation: Codable, Identifiable {
    let id: Int
    let name: String
    let url: URL
}

@MainActor
final class RadioDirectory: ObservableObject {
    @Published var stations: [RadioStation] = []
    @Published var loading = false
    @Published var error: String?
    private struct Response: Decodable { let radios: [RadioStation] }
    init() {
        if let url = Bundle.main.url(forResource: "radios", withExtension: "json"), let data = try? Data(contentsOf: url),
           let response = try? JSONDecoder().decode(Response.self, from: data) {
            stations = response.radios.filter { $0.url.scheme == "https" }
        }
    }
    func refresh() async {
        guard !loading else { return }; loading = true; error = nil
        defer { loading = false }
        do {
            var request = URLRequest(url: URL(string: "https://www.mp3quran.net/api/v3/radios?language=eng")!); request.timeoutInterval = 20
            let (data, response) = try await URLSession.shared.data(for: request)
            try Task.checkCancellation()
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            stations = try JSONDecoder().decode(Response.self, from: data).radios.filter { $0.url.scheme == "https" }
        } catch {
            if !Task.isCancelled { self.error = "Couldn't refresh stations. The included directory is shown. Live listening still requires internet." }
        }
    }
}

struct ListenView: View {
    @ObservedObject private var player = RecitationPlayer.shared
    @StateObject private var radio = RadioDirectory()
    @State private var mode = 0
    @State private var query = ""
    var body: some View {
        List {
            Picker("Listening mode", selection: $mode) { Text("Surahs").tag(0); Text("Live radio").tag(1) }.pickerStyle(.segmented)
            if mode == 0 {
                Section {
                    NavigationLink { ReciterPicker() } label: { LabeledContent("Reciter", value: player.selectedReciterName) }
                    NavigationLink { DownloadsView() } label: { Label("Offline downloads", systemImage: "arrow.down.circle") }
                }
                Section("Continuous recitation") {
                    ForEach(QuranLibrary.shared.surahs.filter { query.isEmpty || $0.englishName.localizedCaseInsensitiveContains(query) }, id: \.number) { surah in
                        Button { player.play(ayahs: (surah.ayahs ?? []).map(\.id)) } label: {
                            HStack { SurahRow(surah: surah); Image(systemName: "play.circle").font(.title2).foregroundStyle(Color.appAccent) }.foregroundStyle(.primary)
                        }.accessibilityLabel("Listen to \(surah.englishName)")
                    }
                }
            } else {
                Section {
                    Text("Live Quran radio").font(.headline)
                    Text("Continuous broadcasts from MP3Quran. Internet is required; download surahs for offline listening.").font(.subheadline).foregroundStyle(.secondary)
                    if radio.loading { ProgressView("Refreshing stations…") }
                    if let error = radio.error { Text(error).font(.footnote); Button("Retry directory") { Task { await radio.refresh() } } }
                    if player.offlineOnly { Text("Offline-only audio is on. Turn it off in Settings to use live radio.").foregroundStyle(.secondary) }
                }
                ForEach(radio.stations.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { station in
                    Button { player.playRadio(name: station.name, url: station.url) } label: {
                        Label(station.name, systemImage: "dot.radiowaves.left.and.right").frame(minHeight: 44)
                    }.disabled(player.offlineOnly)
                }
            }
        }.navigationTitle("Listen").searchable(text: $query, prompt: mode == 0 ? "Find a surah" : "Find a station")
            .task { await radio.refresh() }
    }
}

struct DownloadsView: View {
    @ObservedObject private var downloads = AudioDownloads.shared
    @ObservedObject private var player = RecitationPlayer.shared
    @State private var pendingRemoval: SurahModel?
    @State private var confirmRemoval = false
    var body: some View {
        List {
            Section {
                Label("Quran text and translation are included", systemImage: "checkmark.circle")
                Text("Audio storage: \(ByteCountFormatter.string(fromByteCount: downloads.storedBytes, countStyle: .file))").font(.subheadline)
                NavigationLink { ReciterPicker() } label: { LabeledContent("Reciter", value: player.selectedReciterName) }
                Toggle("Play downloaded audio only", isOn: $player.offlineOnly)
                Text("Downloads continue while you use the app. Keep the app open until they finish. Interrupted downloads retain completed verses.").font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(QuranLibrary.shared.surahs, id: \.number) { surah in
                Section(surah.englishName) {
                    DownloadControl(surah: surah)
                    if downloads.count(surah, reciter: player.selectedIdentifier) > 0 {
                        Button("Remove downloaded audio", role: .destructive) { pendingRemoval = surah; confirmRemoval = true }
                    }
                }
            }
        }.navigationTitle("Downloads")
            .confirmationDialog("Remove this surah's audio for \(player.selectedReciterName)?", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("Remove audio", role: .destructive) { if let surah = pendingRemoval { player.stop(); downloads.remove(surah, reciter: player.selectedIdentifier) } }
                Button("Keep audio", role: .cancel) { }
            }
    }
}
