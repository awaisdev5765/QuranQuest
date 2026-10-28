import Foundation

struct AyahModel: Codable, Identifiable, Hashable {
    let number: Int
    let globalNumber: Int
    let text: String
    var juz: Int = 1
    var page: Int = 1
    var id: Int { globalNumber }
    enum CodingKeys: String, CodingKey {
        case number = "numberInSurah", globalNumber = "number", text, juz, page
    }
}
