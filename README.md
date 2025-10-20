<div align="center">

# Darasa Huru — Mobile App (Flutter)

Modern Flutter application for browsing news, study notes, and exams content from the Darasa Huru WordPress site.

Developed by: <b>Ezra Daniel Gyunda</b>

</div>

---

## Overview
Darasa Huru Mobile brings the rich content of the Darasa Huru WordPress website to Android, iOS, and desktop (Windows/macOS) via a fast, clean Flutter app. It fetches posts, categories, and pages using the official WordPress REST API and presents them in an intuitive UI with tabs for Home/News, Notes (Study Notes), and Exams.

- **Platform**: Flutter (Dart)
- **Data Source**: WordPress REST API `https://darasahuru.ac.tz/wp-json/wp/v2/...`
- **Developer**: Ezra Daniel Gyunda

> Note (Swahili): App hii imejengwa kwa ajili ya watumiaji wa Darasa Huru, ikichukua taarifa kutoka kwenye tovuti yao ya WordPress na kuziwasilisha kwa urahisi ndani ya simu.

## Features
- **Home/News feed** with category chips (All, A level, O level, Primary, Necta Info, Un & Colleges, Tamisemi)
- **Study Notes (Notes)** with hierarchical subcategories and notes lists
- **Exams** browser with subcategory cards and drill-down navigation
- **Post details** with rich content rendering (images, iframes/YouTube)
- **External opening for links**
  - Google Drive/Docs and PDF links open in external apps/browser
- **Friendly offline messages**
  - When APIs fail or you’re offline, the app shows “Please turn on the internet and try again.”
- **Settings page**
  - Links to social channels, About, Privacy Policy, Services, Share App, Contact (email)
- **Search**
  - In-app post search with filter-by-title
- **Performance & UX**
  - Pagination and background loading of additional pages
  - Cached images, responsive layouts

## Screens and Flow
- `HomeTab` — News feed with category selector and infinite load.
- `NotesTab` — News-like feed for News categories (labelled Notes/News in code), with subcategory support.
- `MyNotesTab` — Study notes hierarchy for `study-notes` root, drill down to notes lists.
- `ExamsTab` — Exams (MITIHANI) subcategory cards → lists of posts.
- `PostDetailScreen` — Renders a single post (HTML) and recommended posts.
- `SettingsScreen` — Socials, About/Privacy/Services pages (fetched via slugs), rate/share.

## Tech Stack
- Flutter 3.x
- Dart 3.x
- Packages:
  - `http`, `url_launcher`, `flutter_html`, `cached_network_image`
  - `webview_flutter` (optional path), `share_plus`, `html_unescape`
  - `flutter_typeahead` (search/typeahead)

## Project Structure (key files)
- `lib/main.dart` — App entry, theme, navigation, bottom tabs, search.
- `lib/home_tab.dart` — Home/News feed and category chips.
- `lib/notes_tab.dart` — News feed with subcategories and recommended posts.
- `lib/my_notes_tab.dart` — Study Notes hierarchy and notes lists.
- `lib/exams_tab.dart` — Exams categories and posts.
- `lib/post_detail_screen.dart` — Post detail renderer, link handling.
- `lib/settings_screen.dart` — Settings with links and app info.
- `lib/api/api_service.dart` — Helper(s) for category drilldown (Exams).

## Data Source and Pages
This app consumes endpoints like:

```text
GET /wp-json/wp/v2/posts
GET /wp-json/wp/v2/categories
GET /wp-json/wp/v2/posts?categories=<id>&per_page=<n>&_embed=1
```

Some detail pages (About Us, Privacy Policy, Services) are opened via `PageDetailScreen` and WordPress page slugs.

## Link Handling
- Internal links to `darasahuru.ac.tz` are opened inside the app by fetching the post via ID/slug.
- External links:
  - `drive.google.com`, `docs.google.com` and `*.pdf` — open externally using `url_launcher`.

## Offline and Errors
- All major screens show a friendly message when data fails to load:

```text
Please turn on the internet and try again.
```

## Getting Started (Development)
1. Install Flutter and Dart SDKs.
2. Clone the repo:

```bash
git clone https://github.com/raydanielg/darasahurumobile.git
cd darasahurumobile
```

3. Install dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run
```

### Build APK / AppBundle
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
- Open `ios/` in Xcode, set signing, then:

```bash
flutter build ios --release
```

### Windows/macOS (optional)
```bash
flutter config --enable-windows-desktop --enable-macos-desktop
flutter build windows
flutter build macos
```

## Configuration
- Update brand assets under `assets/` (e.g., `assets/Darasa-Huru-Juu-New.png`, `assets/icon.png`).
- Check `pubspec.yaml` for assets declarations.
- Update package names, app name, and icons as needed.

## Known Behaviors
- Sharing button in `PostDetailScreen` is currently disabled (AppBar action removed).
- Onboarding/Tour screens are present in code but disabled at startup.

## Contributing
Pull requests are welcome. For large changes, please open an issue first to discuss what you would like to change.

### Code Style
- Follow Flutter/Dart analyzer suggestions (`analysis_options.yaml`).

## Security & Privacy
- The app reads public content from the Darasa Huru WordPress site.
- No sensitive keys are embedded; if keys are introduced in the future, store them securely and never commit secrets.

## Credits
- **Developer**: Ezra Daniel Gyunda
- **Content Source**: Darasa Huru WordPress website

## License
This project is licensed under the MIT License — see [`LICENSE`](LICENSE) for details.
