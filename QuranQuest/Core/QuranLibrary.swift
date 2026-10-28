import Foundation

final class QuranLibrary {
    static let shared = QuranLibrary()
    let surahs: [SurahModel]
    let error: String?
    private let translations: [String: String]

    init(bundle: Bundle = .main) {
        do {
            guard let url = bundle.url(forResource: "quran", withExtension: "json") else { throw LibraryError.missing }
            let values = try JSONDecoder().decode([SurahModel].self, from: Data(contentsOf: url))
            try Self.validate(values)
            surahs = values
            error = nil
        } catch {
            surahs = []
            self.error = "The offline Quran could not be opened. Please reinstall the app to restore its text."
        }
        if let url = bundle.url(forResource: "translation", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let values = try? JSONDecoder().decode([String: String].self, from: data) {
            translations = values
        } else { translations = [:] }
    }

    enum LibraryError: Error { case missing, invalid }
    static func validate(_ surahs: [SurahModel]) throws {
        guard surahs.map(\.number) == Array(1...114),
              surahs.flatMap({ $0.ayahs ?? [] }).map(\.globalNumber) == Array(1...6236) else { throw LibraryError.invalid }
        for surah in surahs {
            guard let ayahs = surah.ayahs, ayahs.count == surah.numberOfAyahs,
                  ayahs.map(\.number) == Array(1...ayahs.count),
                  ayahs.allSatisfy({ !$0.text.isEmpty && (1...30).contains($0.juz) }) else { throw LibraryError.invalid }
        }
    }
    func surah(_ number: Int) -> SurahModel? { surahs.first { $0.number == number } }
    func location(_ global: Int) -> (surah: SurahModel, ayah: AyahModel)? {
        for surah in surahs {
            if let ayah = surah.ayahs?.first(where: { $0.globalNumber == global }) { return (surah, ayah) }
        }
        return nil
    }
    func reference(_ global: Int) -> String {
        guard let item = location(global) else { return "Ayah \(global)" }
        return "\(item.surah.englishName) · \(item.surah.number):\(item.ayah.number)"
    }
    func translation(_ global: Int) -> String? { translations[String(global)] }
}
