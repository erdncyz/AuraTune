# AuraTune

AuraTune wakes you up every morning with a single song picked just for you. Set your favorite music genres and wake-up time once — AuraTune uses AI to choose the song that best fits your morning energy, sends you a notification at the time you choose, and opens it in your favorite music app with one tap.

> Müzikle uyanmanın en güzel hali. Her sabah farklı bir şarkı, farklı bir hikâye.

---

## Features

- 🎵 **Daily personalized song** — picked by Google Gemini based on your taste and the time of day
- ⏰ **Wake-up notification** — local notification at the time you choose
- 🎧 **Multi-platform playback** — opens in Spotify, Apple Music, or YouTube Music with one tap
- 🌍 **Bilingual** — Turkish and English UI
- 🎨 **Material 3 inspired** design with warm hero gradients
- 🔒 **No ads, no tracking** — your data stays yours

---

## Screenshots

_(Add App Store screenshots here once available)_

---

## Tech Stack

- **SwiftUI** (iOS 26+)
- **Supabase** — auth & profile storage
- **Google Gemini API** (`gemini-2.5-flash-lite`) — song recommendation
- **UserNotifications** — local morning notification scheduling
- Swift Package Manager for dependencies

---

## Project Structure

```
AuraTune/
├── AuraTuneApp.swift           # App entry point
├── ContentView.swift           # Root routing (onboarding vs main)
├── Models/                     # Profile, SongSuggestion
├── Services/                   # Gemini, Supabase, Notifications, Language
├── ViewModels/                 # Home, Onboarding, Settings
├── Views/                      # HomeView, NotificationsView, SettingsView, etc.
│   └── Components/             # Reusable Material 3 components
├── Assets.xcassets/            # AppIcon, AccentColor
├── PrivacyInfo.xcprivacy       # Apple Privacy Manifest
└── en.lproj / tr.lproj         # Localized strings
```

---

## Getting Started

### Prerequisites

- macOS with **Xcode 26+**
- An iOS 26.4+ simulator or device
- A **Google Gemini API key** ([create one](https://aistudio.google.com/app/apikey))
- A **Supabase project** with a `profiles` table

### Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/erdncyz/AuraTune.git
   cd AuraTune
   ```

2. Create `AuraTune/Services/Secrets.swift` (this file is gitignored):
   ```swift
   import Foundation

   enum Secrets {
       static let geminiAPIKey = "YOUR_GEMINI_API_KEY"
   }
   ```

3. Configure Supabase URL and anon key in `AuraTune/Services/SupabaseManager.swift`.

4. Open `AuraTune.xcodeproj` in Xcode and run on a simulator or device.

---

## How It Works

1. **Onboarding** — User picks name, language, wake-up time, favorite genres (max 3), and music platform.
2. **Daily fetch** — On opening the home screen, `HomeViewModel` calls Gemini with the user's genres + current time and receives a JSON song suggestion.
3. **Notification scheduling** — A repeating local notification is registered for the chosen wake-up time. Tapping it deep-links into the selected music app.
4. **Settings update** — Changing the wake-up time or platform reschedules the notification automatically.

---

## Privacy

AuraTune does **not** track users or share data with advertisers.

- Stored: name, wake-up time, favorite genres, platform preference (in Supabase, linked to user)
- Sent to Google Gemini: anonymized prompt containing genres and current time only
- See [`AuraTune/PrivacyInfo.xcprivacy`](AuraTune/PrivacyInfo.xcprivacy) for the full Privacy Manifest

---

## Roadmap

- [ ] Move Gemini calls behind a Supabase Edge Function (avoid client-side key exposure)
- [ ] Sign in with Apple
- [ ] Apple Watch companion
- [ ] Mood-based suggestions (manual mood input)
- [ ] Widget for "Today's Pick"
- [ ] iOS 17/18 backport (currently iOS 26.4+)

---

## Support

For questions, bug reports, or feature requests:

- Open an issue on [GitHub](https://github.com/erdncyz/AuraTune/issues)
- Email: erdncyz@gmail.com

---

## License

© 2026 Erdinç Yılmaz. All rights reserved.
