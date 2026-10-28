import SwiftUI

struct MiniPlayer: View {
    @ObservedObject var player: RecitationPlayer
    let expand: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Button(action: expand) {
                HStack(spacing: 12) {
                    Image(systemName: player.isLive ? "dot.radiowaves.left.and.right" : "waveform").foregroundStyle(Color.appAccent).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(player.title).font(.subheadline.bold()).lineLimit(1)
                        Text(player.state == .failed ? "Couldn't play · tap for details" : player.state == .waiting ? "Your turn to recite…" : player.state.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }.frame(minHeight: 48).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("Open player. \(player.title). \(player.state.rawValue)")
            if player.state == .loading { ProgressView().accessibilityLabel("Buffering audio") }
            Button { player.canPause ? player.pause() : player.resume() } label: {
                Image(systemName: player.canPause ? "pause.fill" : "play.fill").frame(width: 44, height: 44)
            }.accessibilityLabel(player.canPause ? "Pause" : "Play")
            Button { player.stop() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close player and stop audio")
        }.padding(.horizontal, 16).padding(.vertical, 4).background(.regularMaterial)
    }
}

struct PlayerSheet: View {
    @ObservedObject var player: RecitationPlayer
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: player.isLive ? "dot.radiowaves.left.and.right" : "book.closed").font(.system(size: 64)).foregroundStyle(Color.appAccent).padding(24).accessibilityHidden(true)
                    Text(player.title).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(player.isLive ? "Live Quran · Internet required" : player.selectedReciterName).foregroundStyle(.secondary)
                    if player.title != "Practice recitation", let ayah = player.playingAyah, let location = QuranLibrary.shared.location(ayah) { ArabicText(text: location.ayah.text) }
                    if player.state == .loading { ProgressView("Buffering audio…") }
                    if player.state == .waiting { Label("Your turn to recite…", systemImage: "mic") }
                    if player.state == .completed { Label("Listening complete", systemImage: "checkmark.circle") }
                    if let error = player.errorMessage {
                        Text(error).multilineTextAlignment(.center)
                        Button("Retry playback") { player.retry() }.buttonStyle(.borderedProminent)
                    }
                    if !player.isLive {
                        Slider(value: Binding(get: { min(player.elapsed, max(1, player.duration)) }, set: player.seek), in: 0...max(1, player.duration))
                            .disabled(player.duration == 0).accessibilityLabel("Playback position")
                        HStack { Text(time(player.elapsed)); Spacer(); Text(time(player.duration)) }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 32) {
                        Button { player.previous() } label: { Image(systemName: "backward.end.fill").frame(width: 48, height: 48) }.disabled(player.isLive || player.queue.isEmpty).accessibilityLabel("Previous verse")
                        Button { player.canPause ? player.pause() : player.resume() } label: {
                            Image(systemName: player.canPause ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 64)).frame(minWidth: 64, minHeight: 64)
                        }.accessibilityLabel(player.canPause ? "Pause recitation" : "Resume recitation")
                        Button { player.next() } label: { Image(systemName: "forward.end.fill").frame(width: 48, height: 48) }.disabled(player.isLive || player.queueIndex + 1 >= player.queue.count).accessibilityLabel("Next verse")
                    }
                    if !player.isLive {
                        Picker("Playback speed", selection: $player.speed) {
                            Text("0.75×").tag(Float(0.75)); Text("1×").tag(Float(1)); Text("1.25×").tag(Float(1.25)); Text("1.5×").tag(Float(1.5))
                        }.pickerStyle(.segmented)
                        if !player.queue.isEmpty { Text("Verse playback \(player.queueIndex + 1) of \(player.queue.count)").font(.footnote).foregroundStyle(.secondary) }
                    }
                    Button("Stop listening") { player.stop(); dismiss() }.buttonStyle(.bordered)
                }.padding(24).frame(maxWidth: 700)
            }.frame(maxWidth: .infinity).navigationTitle("Now playing").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func time(_ seconds: Double) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
}

struct ReciterPicker: View {
    @ObservedObject var player = RecitationPlayer.shared
    @State private var query = ""
    var body: some View {
        List {
            Section {
                if player.isLoadingReciters { ProgressView("Refreshing reciters…") }
                if let error = player.reciterError { Text(error).font(.footnote); Button("Retry") { Task { await player.loadReciters() } } }
                ForEach(player.reciters.filter { query.isEmpty || $0.englishName.localizedCaseInsensitiveContains(query) || $0.name.contains(query) }) { reciter in
                    Button { player.select(reciter) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) { Text(reciter.englishName).foregroundStyle(.primary); Text(reciter.name).font(.custom("Cairo-Regular", size: 18, relativeTo: .body)).foregroundStyle(.secondary) }
                            Spacer()
                            if player.selectedIdentifier == reciter.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.appAccent) }
                        }.frame(minHeight: 48)
                    }.accessibilityValue(player.selectedIdentifier == reciter.id ? "Selected" : "")
                }
            } footer: { Text("Changing the reciter stops current audio. Downloads are stored separately for each reciter.") }
        }.navigationTitle("Reciter").searchable(text: $query).task { await player.loadReciters() }
    }
}
