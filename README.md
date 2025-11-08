# 🌱 DachaBezProblem - Smart Garden AI Assistant

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.3.3+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**AI-powered mobile gardening assistant with plant disease recognition, smart care calendar, and automated reminders**

[Features](#-key-features) • [Installation](#-installation) • [Screenshots](#-screenshots) • [Tech Stack](#-tech-stack) • [Contributing](#-contributing)

</div>

---

## 📖 About

**DachaBezProblem** (Dacha Without Problems) is a comprehensive mobile application designed for gardeners and plant enthusiasts. Using advanced AI technology, the app helps identify plant species, diagnose diseases, and provides personalized care recommendations to keep your garden thriving.

Whether you're a beginner or an experienced gardener, this app simplifies plant care with intelligent automation and expert guidance.

## ✨ Key Features

### 🔬 AI-Powered Plant Recognition
- **Instant Identification** - Point your camera at any plant to identify species
- **Disease Detection** - Advanced image analysis for early disease diagnosis
- **Treatment Recommendations** - Get specific solutions for plant health issues
- **Scan History** - Track all your plant scans and diagnoses

### 📅 Smart Care Management
- **Intelligent Calendar** - Automated scheduling for watering, fertilizing, and maintenance
- **Custom Reminders** - Set personalized notifications for each plant
- **Care Automation** - Suggestions based on plant type, season, and weather
- **Task Tracking** - Mark completed tasks and view care history

### 🌿 Garden Collection
- **My Plants** - Organize your entire garden in one place
- **Detailed Profiles** - Store photos, notes, and care logs for each plant
- **Favorites** - Quick access to your most important plants
- **Growth Tracking** - Monitor plant development over time

### 💬 AI Chat Assistant
- **24/7 Support** - Get instant answers to gardening questions
- **Expert Advice** - Personalized recommendations based on your garden
- **Problem Solving** - Troubleshoot issues with interactive guidance

### 🏆 Gamification
- **Achievement System** - Earn badges for consistent plant care
- **Progress Tracking** - Visualize your gardening journey
- **Motivation** - Stay engaged with rewards and milestones

### 📊 Analytics & Insights
- **Care Statistics** - View your gardening activity and patterns
- **Health Reports** - Monitor overall garden health
- **Recommendations** - Data-driven suggestions for improvement

## 📱 Supported Platforms

| Platform | Status | Min Version |
|----------|--------|-------------|
| 🤖 Android | ✅ Supported | SDK 21+ (Android 5.0) |
| 🍎 iOS | ✅ Supported | iOS 11.0+ |
| 🌐 Web | 🚧 In Development | - |

## 🛠 Tech Stack

### Frontend
- **Framework:** Flutter 3.3.3+
- **Language:** Dart 3.0+
- **UI Components:** Custom Material Design
- **Fonts:** Gilroy, SF Pro

### Backend & Services
- **Authentication:** Firebase Auth (Google, Apple, Phone)
- **Database:** REST API
- **Real-time:** WebSocket for live notifications
- **Storage:** SharedPreferences (local)

### Features & Libraries
- **Camera:** `camera ^0.10.5+9`
- **Image Processing:** `image ^4.1.7`, custom crop service
- **HTTP Client:** `http ^1.1.0`
- **Calendar:** `table_calendar ^3.1.1`
- **Image Picker:** `image_picker ^1.1.2`
- **Video Player:** `video_player ^2.8.3`
- **SVG Support:** `flutter_svg ^2.1.0`
- **Internationalization:** `intl ^0.20.2`

## 🏗 Project Architecture

```
lib/
├── config/              # API configuration and app logger
├── homepage/            # Main dashboard and components
├── loginauth/           # Authentication flow screens
├── models/              # Data models (Plant, Reminder, Achievement, etc.)
├── pages/               # Feature screens
│   ├── ai_chat_page.dart
│   ├── calendar_page.dart
│   ├── my_dacha_page.dart
│   ├── plant_detail_page.dart
│   └── ...
├── plant_result/        # Scan results and analysis screens
├── scanner/             # Camera and image processing
├── services/            # Business logic and API clients
│   ├── api/            # API service layer
│   ├── events/         # Event system
│   └── ...
├── utils/              # Helper functions
├── widgets/            # Reusable UI components
└── main.dart           # App entry point
```

## 🚀 Installation

### Prerequisites

- Flutter SDK 3.3.3 or higher
- Dart SDK 3.0+
- Android Studio / Xcode (for mobile development)
- Firebase account (for authentication features)

### Setup Steps

1. **Clone the repository**
```bash
git clone https://github.com/madnessbrainsbl/DachaBezProblem.git
cd DachaBezProblem
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase** (Required for authentication)
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Add Android app: Download `google-services.json` → Place in `android/app/`
   - Add iOS app: Download `GoogleService-Info.plist` → Place in `ios/Runner/`
   - Create `lib/firebase_options.dart` with your Firebase configuration

4. **Run the app**
```bash
# For Android
flutter run

# For iOS
flutter run -d ios

# For specific device
flutter devices
flutter run -d <device-id>
```

### Build Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 📸 Screenshots

> Add screenshots here to showcase your app's UI and features

## 🎯 Roadmap

- [x] AI plant recognition and disease detection
- [x] Smart calendar with automated reminders
- [x] Achievement system and gamification
- [x] AI chat assistant
- [x] Multi-platform authentication (Google, Apple, Phone)
- [ ] Web version
- [ ] Weather integration
- [ ] Community features (share plants, tips)
- [ ] Marketplace for plants and supplies
- [ ] Offline mode with local database
- [ ] Multi-language support

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and development process.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **madnessbrainsbl** - *Initial work* - [GitHub](https://github.com/madnessbrainsbl)

## 🙏 Acknowledgments

- AI plant recognition technology
- Flutter community for excellent packages
- All contributors and testers
- Plant enthusiasts who provided feedback

## 📞 Support

If you encounter any issues or have questions:

- 🐛 [Report a bug](https://github.com/madnessbrainsbl/DachaBezProblem/issues)
- 💡 [Request a feature](https://github.com/madnessbrainsbl/DachaBezProblem/issues)
- 📧 Contact: [Open an issue](https://github.com/madnessbrainsbl/DachaBezProblem/issues)

## ⭐ Show Your Support

If you find this project helpful, please give it a ⭐️ on GitHub!

---

<div align="center">

**Made with ❤️ for gardeners and plant lovers**

[⬆ Back to Top](#-dachabezproblem---smart-garden-ai-assistant)

</div>
