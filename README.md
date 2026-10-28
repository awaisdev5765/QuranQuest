# 📖 QuranQuest

<p align="center">
  <img src="screenshot/1.png" width="220" alt="QuranQuest Today screen">
</p>

**QuranQuest** is a beautiful, offline-first SwiftUI app that makes daily Quran practice simple: read, listen, memorize (Hifz), and test yourself with gentle quizzes — a little every day.

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16.4+-000000?logo=ios&logoColor=white)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-MVVM-007AFF)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Features

- **🏠 Today** — a daily home with streak tracking, correct-answer stats, a daily intention goal, and "continue reading" resume
- **📖 Quran Reader** — browse all 114 surahs or by juz, search in Arabic or English, save/bookmark ayahs, full Arabic text with translation
- **🧠 Hifz (Memorization)** — create memorization plans with a surah/ayah range, repeat verses at your own pace, hide/reveal text, self-check recall, and scheduled revisions
- **🎧 Listen** — continuous surah recitation with multiple reciters, offline audio downloads, and live Quran radio
- **🎮 Quizzes** — *Guess the Surah* (recognise a verse's surah) and *Continue the Ayah* (recall the verse that follows)
- **🌙 Dark Mode, VoiceOver & Dynamic Type** supported

## 📱 Screenshots

| Today | Practice & Reflect | Quran | Hifz | Listen |
|:---:|:---:|:---:|:---:|:---:|
| ![Today](screenshot/1.png) | ![Practice](screenshot/2.png) | ![Quran](screenshot/3.png) | ![Hifz](screenshot/4.png) | ![Listen](screenshot/5.png) |

## 🛠 Tech Stack

- **SwiftUI** + MVVM architecture
- Native **URLSession** networking with proper error handling
- Quran text & audio from the [AlQuran Cloud API](https://alquran.cloud/api)
- Bundled offline surah metadata & Quran text (`quran.json`, `surahs.json`)
- `UserDefaults`-based persistence for progress, streaks, and plans

## 🚀 Getting Started

1. Clone the repository
   ```bash
   git clone https://github.com/awaisdev5765/QuranQuest.git
   ```
2. Open `QuranQuest.xcodeproj` in **Xcode 15+**
3. Select the **QuranQuest** scheme and run on an iOS 16.4+ simulator or device

## 📂 Project Structure

```
QuranQuest/
├── View/          # SwiftUI views (Today, Reader, Hifz, Listen, Quizzes)
├── ViewModel/     # MVVM view models
├── Model/         # Data models
├── Network/       # API client & error handling
├── Core/          # App-wide services & persistence
├── Helper/        # Utilities
└── Resources/     # Assets, bundled JSON
```

## 🤝 Contributing

Contributions are welcome! Open an issue or submit a pull request.

## ☕ Support

If this project helps you, please consider supporting my work:

<p align="center">
  <a href="https://buymeacoffee.com/awaisdev572">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=%E2%98%95&slug=awaisdev572&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" alt="Buy Me A Coffee">
  </a>
</p>

Or [become a supporter on Buy Me a Coffee](https://buymeacoffee.com/awaisdev572) 💛

## 📄 License

Released under the [MIT License](LICENSE).

## 🙏 Credits

- Quran text & audio: [AlQuran Cloud API](https://alquran.cloud/api)
- Original concept inspired by *Fun Quran Game* by [Muhammad Rezky Sulihin](https://www.linkedin.com/in/mrezkys/)
