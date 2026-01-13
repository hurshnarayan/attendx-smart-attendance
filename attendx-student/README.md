# 📱 AttendX Student App

A beautiful, production-ready Flutter mobile app for the AttendX attendance system. Features a stunning Swiggy/Zomato-inspired UI with smooth animations.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ Features

- 🎯 **QR Code Scanner** - Fast and accurate QR scanning with beautiful overlay
- 🔐 **Device Binding** - Anti-proxy attendance with device fingerprinting
- 📊 **Real-time Stats** - View your attendance statistics at a glance
- 📜 **History Tracking** - Complete attendance history with status
- 🎨 **Stunning UI** - Swiggy/Zomato-level design with smooth animations
- 🌙 **Haptic Feedback** - Tactile feedback for better UX
- 💾 **Offline Support** - Local caching for offline access

## 📸 Screenshots

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   Onboarding    │  │   Home Screen   │  │   QR Scanner    │
│                 │  │                 │  │                 │
│  ┌───────────┐  │  │  Good Morning   │  │  ┌─────────┐   │
│  │  Welcome  │  │  │  Harsh          │  │  │ ▢▢▢▢▢▢ │   │
│  │    to     │  │  │                 │  │  │ ▢    ▢ │   │
│  │  AttendX  │  │  │  ┌───┬───┬───┐  │  │  │ ▢▢▢▢▢▢ │   │
│  └───────────┘  │  │  │ 5 │ 0 │ 5 │  │  │  └─────────┘   │
│                 │  │  └───┴───┴───┘  │  │                 │
│  [Get Started]  │  │  [Scan QR Code] │  │  Point camera   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.0 or higher
- Dart SDK 3.0 or higher
- Android Studio / Xcode
- Go backend running (port 4000)

### Installation

1. **Clone and navigate:**
```bash
cd attendx-student
```

2. **Install dependencies:**
```bash
flutter pub get
```

3. **Configure API URL:**
Edit `lib/utils/constants.dart`:
```dart
class ApiConfig {
  // Change this to your backend URL
  static const baseUrl = 'http://YOUR_SERVER_IP:4000';
  // For Android emulator use: 'http://10.0.2.2:4000'
  // For iOS simulator use: 'http://localhost:4000'
  // For physical device use your computer's IP
}
```

4. **Run the app:**
```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios

# For all available devices
flutter run
```

### Building for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Mac)
flutter build ios --release
```

## 📁 Project Structure

```
attendx-student/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── models.dart           # Data models
│   ├── providers/
│   │   └── app_provider.dart     # State management
│   ├── screens/
│   │   ├── splash_screen.dart    # Animated splash
│   │   ├── onboarding_screen.dart# User registration
│   │   ├── home_screen.dart      # Main dashboard
│   │   ├── scanner_screen.dart   # QR scanner
│   │   ├── manual_entry_screen.dart # Manual token entry
│   │   ├── result_screen.dart    # Success/Error screens
│   │   └── settings_screen.dart  # App settings
│   ├── services/
│   │   ├── api_service.dart      # HTTP client
│   │   ├── device_service.dart   # Device fingerprinting
│   │   └── storage_service.dart  # Local storage
│   ├── utils/
│   │   └── constants.dart        # Colors, spacing, API config
│   └── widgets/
│       ├── stat_card.dart        # Statistics cards
│       └── history_item.dart     # History list item
├── android/
│   └── app/src/main/AndroidManifest.xml
├── ios/
│   └── Runner/Info.plist
└── pubspec.yaml
```

## 🔧 Configuration

### Backend Connection

The app connects to the Go backend. Ensure the backend is running:

```bash
cd backend
go run main.go
# Server starts on http://localhost:4000
```

### Network Configuration

For physical devices, update `ApiConfig.baseUrl` with your computer's local IP:

```dart
// Find your IP:
// Windows: ipconfig
// Mac/Linux: ifconfig or ip addr

static const baseUrl = 'http://192.168.1.100:4000';
```

### Android Emulator

For Android emulator, use the special IP:
```dart
static const baseUrl = 'http://10.0.2.2:4000';
```

## 📱 App Flow

```
┌──────────────┐
│    Splash    │
│    Screen    │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│  Onboarding  │────►│     Home     │
│   (First     │     │    Screen    │
│    Time)     │     └──────┬───────┘
└──────────────┘            │
                            ▼
                    ┌───────┴───────┐
                    │               │
              ┌─────▼─────┐   ┌─────▼─────┐
              │ QR Scan   │   │  Manual   │
              │  Screen   │   │   Entry   │
              └─────┬─────┘   └─────┬─────┘
                    │               │
                    └───────┬───────┘
                            │
                            ▼
                    ┌──────────────┐
                    │   Result     │
                    │   Screen     │
                    │ (Success/    │
                    │  Flagged/    │
                    │  Error)      │
                    └──────────────┘
```

## 🎨 Design System

### Colors

| Color | Hex | Usage |
|-------|-----|-------|
| Primary | `#4F46E5` | Main actions, branding |
| Secondary | `#7C3AED` | Gradients |
| Success | `#10B981` | Present status |
| Warning | `#F59E0B` | Flagged status |
| Danger | `#EF4444` | Errors |

### Typography

- **Font Family:** Plus Jakarta Sans
- **Weights:** 400 (Regular), 500 (Medium), 600 (SemiBold), 700 (Bold), 800 (ExtraBold)

## 🔐 Security Features

1. **Device Fingerprinting** - Creates unique device hash
2. **Token Validation** - Server-side token verification
3. **PIN Entry** - Additional security layer
4. **Anti-Proxy** - Detects different devices

## 🐛 Troubleshooting

### Camera not working
- Check camera permissions in device settings
- Ensure `android.permission.CAMERA` in AndroidManifest.xml
- Ensure `NSCameraUsageDescription` in Info.plist

### Network errors
- Verify backend is running on port 4000
- Check `baseUrl` configuration
- For Android: ensure `android:usesCleartextTraffic="true"`

### Build errors
```bash
flutter clean
flutter pub get
flutter run
```

## 📄 API Endpoints Used

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/attendance/mark` | POST | Mark attendance |
| `/api/students` | POST | Enroll student |
| `/api/attendance` | GET | Get history |
| `/api/token` | GET | Verify connection |

## 🤝 Integration with Teacher Dashboard

1. Teacher starts session on web dashboard
2. QR code is displayed with rotating token
3. Student scans QR code
4. Student enters displayed PIN
5. Attendance is marked and synced in real-time

## 📝 License

MIT License - feel free to use in your projects!

---

Built with ❤️ using Flutter
