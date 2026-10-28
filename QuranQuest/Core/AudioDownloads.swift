import Foundation

@MainActor
final class AudioDownloads: ObservableObject {
    static let shared = AudioDownloads()
    @Published private(set) var activeKey: String?
    @Published private(set) var completed = 0
    @Published private(set) var total = 0
    @Published private(set) var message: String?
    @Published private(set) var messageKey: String?
    @Published private(set) var revision = 0
    @Published private(set) var storedBytes: Int64 = 0
    private var task: Task<Void, Never>?
    private var generation = UUID()
    let root: URL

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Recitations", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            var url = self.root
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        } catch { message = "Audio storage is unavailable: \(error.localizedDescription)" }
        updateStorage()
    }
    static func remoteURL(reciter: String, ayah: Int) -> URL? {
        guard reciter.range(of: "^[a-zA-Z0-9._-]+$", options: .regularExpression) != nil, (1...6236).contains(ayah) else { return nil }
        return URL(string: "https://cdn.islamic.network/quran/audio/128/\(reciter)/\(ayah).mp3")
    }
    private func file(reciter: String, ayah: Int) -> URL {
        root.appendingPathComponent(reciter, isDirectory: true).appendingPathComponent("\(ayah).mp3")
    }
    func localURL(reciter: String, ayah: Int) -> URL? {
        guard Self.remoteURL(reciter: reciter, ayah: ayah) != nil else { return nil }
        let url = file(reciter: reciter, ayah: ayah)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    func count(_ surah: SurahModel, reciter: String) -> Int {
        (surah.ayahs ?? []).filter { localURL(reciter: reciter, ayah: $0.globalNumber) != nil }.count
    }
    func download(_ surah: SurahModel, reciter: String) {
        cancel()
        let token = UUID(); generation = token
        activeKey = "\(reciter):\(surah.number)"
        messageKey = activeKey
        total = surah.numberOfAyahs; completed = count(surah, reciter: reciter); message = nil
        task = Task {
            do {
                let folder = root.appendingPathComponent(reciter, isDirectory: true)
                guard Self.remoteURL(reciter: reciter, ayah: 1) != nil else { throw URLError(.badURL) }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                for ayah in surah.ayahs ?? [] {
                    try Task.checkCancellation()
                    if localURL(reciter: reciter, ayah: ayah.globalNumber) != nil { continue }
                    guard let url = Self.remoteURL(reciter: reciter, ayah: ayah.globalNumber) else { throw URLError(.badURL) }
                    var request = URLRequest(url: url); request.timeoutInterval = 45
                    let (temporaryURL, response) = try await URLSession.shared.download(for: request)
                    defer { try? FileManager.default.removeItem(at: temporaryURL) }
                    try Task.checkCancellation()
                    guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                          response.mimeType?.hasPrefix("audio/") == true,
                          (try temporaryURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) > 0 else { throw URLError(.badServerResponse) }
                    guard generation == token else { return }
                    try FileManager.default.moveItem(at: temporaryURL, to: file(reciter: reciter, ayah: ayah.globalNumber))
                    completed += 1; revision += 1
                }
                guard generation == token else { return }
                message = "\(surah.englishName) is ready offline."
            } catch {
                guard generation == token else { return }
                if !Task.isCancelled { message = "Download interrupted. Saved verses are kept. Tap Download to retry. \(error.localizedDescription)" }
            }
            if generation == token { activeKey = nil; task = nil; updateStorage() }
        }
    }
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil
        if activeKey != nil { messageKey = activeKey; message = "Download paused. Saved verses are kept; download again to resume." }
        activeKey = nil; updateStorage()
    }
    func remove(_ surah: SurahModel, reciter: String) {
        messageKey = "\(reciter):\(surah.number)"
        if activeKey == "\(reciter):\(surah.number)" { cancel() }
        do {
            for ayah in surah.ayahs ?? [] {
                if let url = localURL(reciter: reciter, ayah: ayah.globalNumber) { try FileManager.default.removeItem(at: url) }
            }
            message = "Downloaded audio removed. Quran text remains available."
        } catch { message = "Some files could not be removed. \(error.localizedDescription)" }
        updateStorage()
    }
    private func updateStorage() {
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
        var bytes: Int64 = 0
        while let url = files?.nextObject() as? URL {
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]), values.isRegularFile == true { bytes += Int64(values.fileSize ?? 0) }
        }
        storedBytes = bytes; revision += 1
    }
}
