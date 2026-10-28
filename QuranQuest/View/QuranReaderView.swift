import SwiftUI

struct QuranReaderView: View {
    @EnvironmentObject private var progress: LearningProgress
    @State private var query = ""
    @State private var section = 0
    private let library = QuranLibrary.shared
    var body: some View {
        List {
            Picker("Browse Quran", selection: $section) {
                Text("Surahs").tag(0); Text("Juz").tag(1); Text("Saved").tag(2)
            }.pickerStyle(.segmented).listRowBackground(Color.clear)
            if let error = library.error { Text(error) }
            if !query.isEmpty {
                Section("Surahs") { surahRows(library.surahs.filter { $0.englishName.localizedCaseInsensitiveContains(query) || $0.name.contains(query) || String($0.number) == query }) }
                Section("Verses") {
                    let matches = library.surahs.flatMap { $0.ayahs ?? [] }.filter { $0.text.localizedStandardContains(query) || (library.translation($0.globalNumber)?.localizedCaseInsensitiveContains(query) ?? false) }
                    Text("\(matches.count) matches").font(.caption).foregroundStyle(.secondary)
                    ForEach(matches.prefix(100)) { ayah in verseLink(ayah.globalNumber) }
                    if matches.count > 100 { Text("Showing the first 100. Refine your search to see fewer results.").font(.footnote) }
                }
            } else if section == 0 {
                Section { surahRows(library.surahs) } footer: { Text("All 114 surahs are available offline. Uthmani text · Al Quran Cloud.") }
            } else if section == 1 {
                ForEach(1...30, id: \.self) { juz in
                    if let ayah = library.surahs.flatMap({ $0.ayahs ?? [] }).first(where: { $0.juz == juz }), let location = library.location(ayah.globalNumber) {
                        NavigationLink { JuzReaderView(juz: juz) } label: {
                            VStack(alignment: .leading, spacing: 4) { Text("Juz \(juz)").font(.headline); Text("Starts at \(location.surah.englishName) \(location.ayah.number)").font(.subheadline).foregroundStyle(.secondary) }
                        }
                    }
                }
            } else {
                if progress.bookmarks.isEmpty { EmptyMessage(title: "Keep a verse close", detail: "Tap the bookmark beside any verse to save it here.", icon: "bookmark") }
                ForEach(progress.bookmarks.sorted(), id: \.self) { verseLink($0) }
            }
        }.navigationTitle("Quran").searchable(text: $query, prompt: "Surah, Arabic or English text")
    }
    @ViewBuilder private func surahRows(_ surahs: [SurahModel]) -> some View {
        ForEach(surahs, id: \.number) { surah in
            NavigationLink { SurahReaderView(surah: surah) } label: { SurahRow(surah: surah) }
        }
    }
    @ViewBuilder private func verseLink(_ global: Int) -> some View {
        if let location = library.location(global) {
            NavigationLink { SurahReaderView(surah: location.surah, initialAyah: global) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(library.reference(global)).font(.subheadline.bold())
                    Text(location.ayah.text).font(.custom("KFGQPCHAFSUthmanicScript-Regula", size: 24, relativeTo: .body)).lineLimit(2).frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

struct SurahRow: View {
    let surah: SurahModel
    var body: some View {
        HStack(spacing: 16) {
            Text("\(surah.number)").font(.subheadline.monospacedDigit()).foregroundStyle(Color.appAccent).frame(width: 40, height: 40).background(Color.appAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(surah.englishName).font(.headline)
                Text("\(surah.englishNameTranslation) · \(surah.numberOfAyahs) ayahs").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 8)
    }
}

struct SurahReaderView: View {
    let surah: SurahModel
    var initialAyah: Int? = nil
    @EnvironmentObject private var progress: LearningProgress
    @ObservedObject private var player = RecitationPlayer.shared
    @ObservedObject private var downloads = AudioDownloads.shared
    @AppStorage("arabicSize") private var arabicSize = 32.0
    @AppStorage("showTranslation") private var translation = false
    @State private var jump = 1
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        ArabicText(text: surah.name, size: 36)
                        Text(surah.englishNameTranslation).font(.title3)
                        Text("\(surah.revelationType) · \(surah.numberOfAyahs) ayahs").foregroundStyle(.secondary)
                        Button { player.play(ayahs: (surah.ayahs ?? []).map(\.globalNumber)) } label: { Label("Listen to surah", systemImage: "play.circle.fill") }.buttonStyle(.borderedProminent).controlSize(.large)
                        HStack {
                            Picker("Jump to ayah", selection: $jump) { ForEach(1...surah.numberOfAyahs, id: \.self) { Text("Ayah \($0)").tag($0) } }
                            Button("Go") { if let ayah = surah.ayahs?.first(where: { $0.number == jump }) { proxy.scrollTo(ayah.id, anchor: .top); progress.lastRead = ayah.id } }.frame(minWidth: 44, minHeight: 44)
                        }
                        Toggle("English translation", isOn: $translation)
                        DownloadControl(surah: surah)
                    }.padding(20).background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
                    ForEach(surah.ayahs ?? []) { ayah in
                        VerseCard(ayah: ayah, surah: surah, translation: translation, size: arabicSize).id(ayah.id)
                    }
                }.padding(16).frame(maxWidth: 760)
            }.frame(maxWidth: .infinity).background(Color.appBackground)
                .onAppear { if let initialAyah { proxy.scrollTo(initialAyah, anchor: .top) } }
                .onChange(of: player.playingAyah) { value in
                    // Highlight current recitation; preserve the reader's scroll position.
                    if let value, surah.ayahs?.contains(where: { $0.id == value }) == true { progress.lastRead = value }
                }
        }.navigationTitle(surah.englishName).navigationBarTitleDisplayMode(.inline)
    }
}

struct VerseCard: View {
    let ayah: AyahModel
    let surah: SurahModel
    let translation: Bool
    let size: Double
    @EnvironmentObject private var progress: LearningProgress
    @ObservedObject private var player = RecitationPlayer.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(surah.number):\(ayah.number)").font(.subheadline.bold()).foregroundStyle(Color.appAccent)
                Spacer()
                Button { player.toggle(ayahNumber: ayah.id) } label: {
                    Image(systemName: player.playingAyah == ayah.id && player.canPause ? "pause.circle" : "play.circle").font(.title2).frame(width: 44, height: 44)
                }.accessibilityLabel("\(player.playingAyah == ayah.id && player.canPause ? "Pause" : "Listen to") ayah \(ayah.number)")
                Button { progress.toggleBookmark(ayah.id) } label: {
                    Image(systemName: progress.bookmarks.contains(ayah.id) ? "bookmark.fill" : "bookmark").frame(width: 44, height: 44)
                }.accessibilityLabel("Bookmark ayah \(ayah.number)").accessibilityValue(progress.bookmarks.contains(ayah.id) ? "Saved" : "Not saved")
                Menu {
                    Button("Continue listening from here") { player.play(ayahs: (surah.ayahs ?? []).filter { $0.number >= ayah.number }.map(\.id)) }
                    Button("Set as reading position") { progress.lastRead = ayah.id }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("More actions for ayah \(ayah.number)")
            }
            ArabicText(text: ayah.text, size: size)
            if translation, let text = QuranLibrary.shared.translation(ayah.id) { Text(text).font(.body).lineSpacing(6).foregroundStyle(.secondary) }
            if progress.lastRead == ayah.id { Label("Reading position", systemImage: "book").font(.caption).foregroundStyle(Color.appAccent) }
        }.padding(20).background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(player.playingAyah == ayah.id ? Color.appAccent : Color.clear, lineWidth: 2))
    }
}

struct JuzReaderView: View {
    let juz: Int
    @AppStorage("arabicSize") private var size = 32.0
    @AppStorage("showTranslation") private var translation = false
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(QuranLibrary.shared.surahs, id: \.number) { surah in
                    ForEach((surah.ayahs ?? []).filter { $0.juz == juz }) { ayah in VerseCard(ayah: ayah, surah: surah, translation: translation, size: size) }
                }
            }.padding(16).frame(maxWidth: 760)
        }.frame(maxWidth: .infinity).background(Color.appBackground).navigationTitle("Juz \(juz)")
    }
}

struct DownloadControl: View {
    let surah: SurahModel
    @ObservedObject private var player = RecitationPlayer.shared
    @ObservedObject private var downloads = AudioDownloads.shared
    var body: some View {
        let count = downloads.count(surah, reciter: player.selectedIdentifier)
        let active = downloads.activeKey == "\(player.selectedIdentifier):\(surah.number)"
        VStack(alignment: .leading, spacing: 8) {
            Text("\(count) / \(surah.numberOfAyahs) verses saved · \(player.selectedReciterName)").font(.caption).foregroundStyle(.secondary)
            if active {
                ProgressView(value: Double(downloads.completed), total: Double(max(1, downloads.total))).accessibilityLabel("Audio download progress")
                Button("Cancel download") { downloads.cancel() }
            } else if count == surah.numberOfAyahs {
                Label("Audio ready offline", systemImage: "checkmark.circle").font(.subheadline).foregroundStyle(Color.appAccent)
            } else {
                Button { downloads.download(surah, reciter: player.selectedIdentifier) } label: { Label(count == 0 ? "Download audio" : "Resume download", systemImage: "arrow.down.circle") }.disabled(downloads.activeKey != nil)
            }
            if downloads.messageKey == "\(player.selectedIdentifier):\(surah.number)", let message = downloads.message { Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }
    }
}
