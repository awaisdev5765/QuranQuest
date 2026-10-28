import SwiftUI

extension Color {
    static let islamicInk = Color(red: 0.025, green: 0.12, blue: 0.13)
    static let islamicTeal = Color(red: 0.02, green: 0.31, blue: 0.30)
    static let islamicGold = Color(red: 0.91, green: 0.71, blue: 0.30)
    static let islamicMint = Color(red: 0.45, green: 0.82, blue: 0.69)
    static let islamicPaper = Color(red: 0.98, green: 0.95, blue: 0.87)
    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let appCard = Color(uiColor: .secondarySystemGroupedBackground)
    static let appAccent = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.45, green: 0.82, blue: 0.69, alpha: 1) : UIColor(red: 0.02, green: 0.36, blue: 0.33, alpha: 1) })
}

struct ArabicText: View {
    let text: String
    var size: Double = 32
    var body: some View {
        Text(text).font(.custom("KFGQPCHAFSUthmanicScript-Regula", size: size, relativeTo: .title2))
            .lineSpacing(12).multilineTextAlignment(.trailing)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct FeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(Color.appAccent)
                .frame(width: 48, height: 48).background(Color.appAccent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary).accessibilityHidden(true)
        }.padding(16).background(Color.appCard, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct EmptyMessage: View {
    let title: String
    let detail: String
    let icon: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Color.appAccent).accessibilityHidden(true)
            Text(title).font(.title3.bold())
            Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(32).frame(maxWidth: .infinity)
    }
}
