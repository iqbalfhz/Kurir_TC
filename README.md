# 🪄 Flutter + Laravel Starter Kit (Full Auth Template)

A modern **Flutter starter kit** integrated with a **Laravel API backend**.  
Perfect for developers who want to build a mobile app with **login, logout, and password reset via OTP** — without setting everything up from scratch.

## 🔗 Backend Pair

📦 **Laravel API Repository:**  
👉 [https://github.com/iqbalfhz/API-Android](https://github.com/iqbalfhz/API-Android)

> Make sure the Laravel API is running before starting this Flutter project.  
> The app connects directly to the same routes and structure from that backend.

---

## 🚀 Features

✅ Login (email + password)  
✅ Logout (invalidate Sanctum token)  
✅ Password reset via OTP  
✅ Real-time validation & error messages  
✅ Light/Dark mode toggle  
✅ Modern glassmorphism UI with animation  
✅ Production-ready structure (services, models, utils, widgets)

---

## ⚙️ Setup Instructions

### 1️⃣ Prepare the Laravel API

1. Clone and set up the backend:  
   👉 [iqbalfhz/API-Android](https://github.com/iqbalfhz/API-Android)
2. Run the Laravel server:
   ```bash
   php artisan serve
   ```
   The default URL is:
   ```
   http://127.0.0.1:8000
   ```
3. Test the API endpoints using Postman:
   - `POST /api/auth/login`
   - `POST /api/auth/send-otp`
   - `POST /api/auth/reset-password`

---

### 2️⃣ Clone & Setup the Flutter App

```bash
git clone https://github.com/iqbalfhz/starter_kit.git
cd starter_kit
flutter pub get
```

---

### 3️⃣ Configure the Base API URL

Edit this file:  
📄 `lib/utils/constants.dart` (or `api_service.dart` if constants.dart doesn’t exist)

```dart
// Android emulator
const baseUrl = 'http://10.0.2.2:8000';

// iOS simulator
const baseUrl = 'http://127.0.0.1:8000';

// Physical device
const baseUrl = 'http://192.168.x.x:8000'; // your PC’s local IP
```

💡 _Ensure your phone/emulator and PC are on the same Wi-Fi network._

---

### 4️⃣ Run the App

```bash
flutter run
```

---

## 🧠 Using This Template for Your Own Project

### ✳️ 1. Change App Identity

Edit:

- `pubspec.yaml` → update app name & description
- `android/app/build.gradle` → update `applicationId`
- `ios/Runner/Info.plist` → update display name

Example:

```yaml
name: my_new_app
description: A modern Flutter app with Laravel backend.
```

### ✳️ 2. Update Base URL

Make sure `lib/utils/constants.dart` points to your own API domain or IP.

### ✳️ 3. Customize UI or Structure

Modify these pages:

- `login_page.dart` → login UX
- `forgot_password_page.dart` → OTP/reset flow
- `home_page.dart` → your main dashboard

### ✳️ 4. (Optional) Adjust API Service

If your endpoint names differ, modify:
📄 `lib/services/api_service.dart`

### ✳️ 5. Build APK/IPA

```bash
flutter build apk --release
flutter build ios --release
```

---

## 💡 Emulator Connection Guide

| Platform         | API URL                   |
| ---------------- | ------------------------- |
| Android Emulator | `http://10.0.2.2:8000`    |
| iOS Simulator    | `http://127.0.0.1:8000`   |
| Physical Device  | `http://192.168.x.x:8000` |

> Ensure `php artisan serve` remains active during testing.

---

## 📬 Contributing

1. Fork this repo
2. Create a new branch (`feature/your-feature`)
3. Commit & push
4. Submit a pull request 😄

---

## ⭐ Credits

This starter kit was built to help developers focus on app logic — not repetitive setup.  
It’s inspired by the integration between **Laravel Sanctum** and **Flutter (Dio)**.

🧑‍💻 Developed by [@iqbalfhz](https://github.com/iqbalfhz)

> Don’t forget to give a ⭐ to both repos:
>
> - [Flutter Starter Kit](https://github.com/iqbalfhz/starter_kit)
> - [Laravel API Backend](https://github.com/iqbalfhz/API-Android)
