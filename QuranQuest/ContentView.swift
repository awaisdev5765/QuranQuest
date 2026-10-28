import SwiftUI

struct ContentView: View {
    @StateObject private var progress = LearningProgress()
    @ObservedObject private var player = RecitationPlayer.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var playerExpanded = false
    @AppStorage("appearance") private var appearance = "system"
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("Today", systemImage: "sun.max") }
            NavigationStack { QuranReaderView() }.tabItem { Label("Quran", systemImage: "book") }
            NavigationStack { HifzView() }.tabItem { Label("Hifz", systemImage: "brain.head.profile") }
            NavigationStack { ListenView() }.tabItem { Label("Listen", systemImage: "headphones") }
            NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.isActive { MiniPlayer(player: player) { playerExpanded = true } }
        }
        .sheet(isPresented: $playerExpanded) { PlayerSheet(player: player) }
        .environmentObject(progress)
        .tint(Color.appAccent)
        .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        .onChange(of: scenePhase) { phase in if phase == .active { progress.refresh() } }
    }
}

private struct HomeView: View {
    @EnvironmentObject private var progress: LearningProgress
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "book.pages").font(.largeTitle).foregroundStyle(Color.islamicGold).accessibilityHidden(true)
                    Text("A little every day.").font(.system(.largeTitle, design: .serif).bold())
                    Text("Read, listen and make space for the Quran.").font(.body)
                    Label("Quran text is ready offline", systemImage: "checkmark.circle").font(.footnote)
                }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.islamicTeal, in: RoundedRectangle(cornerRadius: 28))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { stats }
                    VStack(alignment: .leading, spacing: 16) { stats }
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Daily intention").font(.headline); Spacer(); Text("\(progress.practicedToday.count) / \(progress.dailyTarget) ayahs").font(.subheadline) }
                    ProgressView(value: Double(min(progress.practicedToday.count, progress.dailyTarget)), total: Double(progress.dailyTarget))
                    Text("Practice a quiz or complete a Hifz self-check.").font(.footnote).foregroundStyle(.secondary)
                }
                if let location = QuranLibrary.shared.location(progress.lastRead) {
                    NavigationLink { SurahReaderView(surah: location.surah, initialAyah: location.ayah.globalNumber) } label: {
                        FeatureCard(title: "Continue reading", subtitle: QuranLibrary.shared.reference(progress.lastRead), icon: "bookmark")
                    }.buttonStyle(.plain)
                }
                Text("Practice & reflect").font(.title2.bold())
                NavigationLink { GuessSurahView() } label: { FeatureCard(title: "Guess the Surah", subtitle: "Recognise a verse and its home", icon: "questionmark.circle") }.buttonStyle(.plain)
                NavigationLink { ConnectAyahView() } label: { FeatureCard(title: "Continue the Ayah", subtitle: "Recall the verse that follows", icon: "arrow.right.circle") }.buttonStyle(.plain)
                NavigationLink { HistoryView() } label: { FeatureCard(title: "Your practice", subtitle: "Review mistakes and recent sessions", icon: "chart.bar") }.buttonStyle(.plain)
            }.padding(20).frame(maxWidth: 720)
        }.frame(maxWidth: .infinity).background(Color.appBackground).navigationTitle("Quran Practice")
    }
    @ViewBuilder private var stats: some View {
        Label("\(progress.dailyStreak) day streak", systemImage: "flame").font(.headline)
        Label("\(progress.correctAnswers) correct", systemImage: "checkmark.seal").font(.headline)
    }
}
