# Playsher Mobile App

Flutter sports ground booking app for Android & iOS.

## Requirements
- Flutter 3.22+ (stable channel)
- Dart 3.4+
- Android Studio / Xcode
- Backend running at `http://localhost:3000`

## Setup

### 1. Install dependencies
```bash
cd E:/playsher/Beckend/playsher-app
flutter pub get
```

### 2. Configure API URL
Edit `lib/core/constants.dart`:
- Android Emulator: `http://10.0.2.2:3000/api/v1`
- iOS Simulator:    `http://localhost:3000/api/v1`
- Physical device:  `http://<YOUR_PC_IP>:3000/api/v1`

### 3. Seed the database (first time only)
```bash
cd E:/playsher/Beckend/playsher-api
node database/seed.js
```

### 4. Start the backend
```bash
cd E:/playsher/Beckend/playsher-api
node server.js
```

### 5. Run the Flutter app
```bash
cd E:/playsher/Beckend/playsher-app
flutter run
```

## OTP Login (Development)
The OTP is printed to the **backend console** (no SMS sent in dev).
Watch the server terminal for: `[OTP] mobile=03111234001  otp=123456`

## Test Credentials
| Role         | Login     | Password  |
|--------------|-----------|-----------|
| Admin        | sabarish@playsher.com | sabarish |
| Ground Owner | ali@playsher.com      | Owner@123 |
| Ground Owner | zara@playsher.com     | Owner@123 |
| User (OTP)   | 03111234001 | OTP from console |
| User (OTP)   | 03111234002 | OTP from console |

## Features
- OTP-based phone authentication
- Browse and search sports grounds
- Filter by sport, city
- View ground details with images, sports, amenities, reviews
- Book time slots with calendar picker
- View and cancel bookings
- Browse open community games
- User profile management

## Project Structure
```
lib/
├── main.dart          # Entry point
├── app.dart           # MaterialApp.router + theme
├── core/
│   ├── constants.dart # API URL, storage keys
│   ├── theme.dart     # Material 3 green theme
│   ├── api_client.dart# Dio + JWT interceptor
│   └── storage.dart   # Secure token storage
├── models/            # JSON-serializable data classes
├── providers/         # Riverpod state providers
├── router.dart        # GoRouter + ShellRoute for bottom nav
├── screens/           # All screens (14 screens)
└── widgets/           # Reusable UI components
```

## Build for Release
### Android APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### iOS (Mac required)
```bash
flutter build ios --release
```

## API Endpoints Used
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /auth/send-otp | Send OTP to mobile |
| POST | /auth/verify-otp | Verify OTP → login/check new user |
| POST | /auth/complete-registration | Register new user |
| POST | /auth/refresh-token | Refresh access token |
| GET | /grounds | List grounds (filter by sport, city) |
| GET | /grounds/:id | Ground detail |
| GET | /ground-sports/:id/slots | Available slots for a date |
| POST | /bookings | Create booking |
| GET | /bookings | My bookings |
| PATCH | /bookings/:id/cancel | Cancel booking |
| GET | /sports | List sports |
| GET | /games | List open games |
| GET | /reviews?ground_id= | Ground reviews |
| POST | /reviews | Submit review |
