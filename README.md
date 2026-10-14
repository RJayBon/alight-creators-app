# Alight Creators (Flutter app)

Mobile version of the Alight Creators web system. Dark theme, portrait only,
fully offline — no backend and no internet needed to run it. All data lives
in a local SQLite database on the device.

## How to run in VSCodium

1. Unzip this folder somewhere convenient.
2. Open a terminal inside the folder and generate the platform files (this
   project ships only the Dart code and assets):

flutter create . --platforms=android

Add `,ios` on a Mac if you also want an iOS build.
3. Get the packages and run it on your connected phone or emulator:

flutter pub get
flutter run

Requires Flutter 3.24 or newer (uses the current `PopScope` API).

## Sample accounts (alpha test)

| Email                  | Password         | Role  |
| ---------------------- | ---------------- | ----- |
| admin@alight.local     | AlightAdmin2026  | admin |
| student@seait.edu.ph   | password123      | user  |

Sign Up also works — every account, tutorial, rating, love, and message is
stored in a local SQLite database and persists across app restarts. Deleting
the app (or clearing app data) resets everything back to the seeded state.

## What's inside

### Auth
- Welcome → Log In / Sign Up flow, then the logged-in home shell.
- **Log In** by email *or* `@username` (matches the web behavior).
- **Sign Up** with display name, username, email, birthdate (13+ enforced),
gender (Male / Female / Others + custom), password + confirm.
- **Forgot Password** generates a 64-character token (15-minute expiry,
one-time use) and walks you through a reset screen. This mirrors the web
flow, where the token would normally arrive by email.
- Passwords are stored as `sha256:<salt>:<hash>` — never plaintext.

### Home shell (icon-only bottom navigation)
- **Home** — "Master Alight Motion" banner, **Recommended** (ranked by
rating, falling back to views), **Latest** (by creation date), and a
**Popular Tutorials** panel at the bottom.
- **Tutorials** — search bar (matches title / description / category) and
category chips (All / Beginners / Intermediate / Advanced / Tips & Tricks).
Results are shown in a 2-column grid with an empty state and a
clear-search link.
- **Post** — full tutorial form: title, animated category dropdown,
thumbnail picker, guiding video (URL *or* file), short description, dynamic
steps (add/remove, min 1, max 15), downloads & assets (preset or asset,
URL-based), and a result video (URL *or* file). Submits into SQLite
transactionally and redirects to Home.
- **Contact** — message form with the sender's name auto-filled from the
account. Submissions are stored and shown in the admin panel. Rate-limited
to 3 messages / 10 minutes.
- **Profile** — shows your avatar/initials, display name, handle, and role
badge. Buttons for **View Public Profile**, **Edit Profile**, **Settings**,
**Log Out**, and **Delete Account**. Admins also see **Manage Users** and
**Contact Messages**.

### Profile
- **Public profile** — Discord-style banner + avatar overlap, name, handle,
role badge, bio, "loves received" pill (tappable on other people's
profiles to love/unlove), and a list of published tutorials.
- **Edit profile** — banner crop (4:1) and avatar crop (1:1) using the
native image cropper, display name, username handle, email, gender,
birthdate, and bio. Admins editing another user also see a role dropdown
and an optional password reset field.
- **Delete account** cascades to tutorials, steps, resources, ratings,
views, and loves, and removes every uploaded file from disk.

### Tutorials
- **Detail screen** — category tag, view counter, author link (taps into
their public profile), title, description, guide video (YouTube URL opens
externally; uploaded file plays inline via `video_player`), downloadable
resources, an interactive rating card (Quality + Easy to Read, one per
user, `ON CONFLICT`-style upsert), a step-by-step breakdown grid, and the
Popular Tutorials panel at the bottom.
- **Edit / Delete** — available to the author or any admin. Edit pre-fills
every field and adds "Remove current file" checkboxes for thumbnail,
guide video, and result video.
- **Views** are counted once per non-author visitor per tutorial (matches
the web's `tutorial_views` table).

### Admin
- **Manage Users** — debounced search across name / `@handle` / email,
paginated list (20 per page), role pills, tutorial counts, and quick
actions to view the public profile or edit the user.
- **Contact Messages** — Total / Today / Last 7 Days stats, per-message
cards with mailto links, per-message delete, and a "Clear All" action.

### Styling
- Matches the web theme: dark background `#0C121D`, cyan accent `#00D2FF`,
Varela Round font, glow effects, and animated focus rings on inputs.
- The SVG logo `assets/images/icons/icon.svg` is rendered with `flutter_svg`.
- The font is bundled locally at `assets/fonts/VarelaRound-Regular.ttf`
(Varela Round, SIL Open Font License). Replace that file with your own copy
if you prefer — keep the same name and nothing else needs changing.

## Data & file storage

- SQLite database: `alight_creators.db` in the app's databases directory
(version 2 schema — users, tutorials, steps, resources, views, ratings,
loves, contact messages, password resets).
- Uploaded files: stored under the app's documents directory in
`uploads/avatars/`, `uploads/banners/`, `uploads/thumbnails/`, and
`uploads/videos/`.
- On first launch the app seeds the two demo accounts plus five demo
tutorials with steps, a rating, and a love so the UI never starts empty.

## Notes

- Phone back button: from any tab it returns to Home; from Home it exits the
app; from a detail or auth screen it goes back normally.
- Orientation is locked to portrait.
- The app never talks to the network — `image_picker`, `image_cropper`,
`video_player`, and `url_launcher` are the only plugins that interact with
the OS, and none of them require internet.

## Directory layout
lib/
├── main.dart, app.dart, theme.dart, constants.dart
├── models/ user.dart, tutorial.dart, contact_message.dart
├── services/ database, seed, session, rate-limit, file,
│ auth, password-reset, user, tutorial, contact
├── utils/ validators, formatters, password_util, category_colors
├── widgets/ shared UI (pill button, labeled field, tutorial card,
│ step builder, resource builder, rating stars, ...)
└── screens/
├── welcome_screen.dart, not_found_screen.dart
├── auth/ login, sign_up, forgot_password, reset_password
├── shell/ home_shell (bottom nav)
├── tabs/ home, tutorials, post, contact, profile,
│ about, settings
├── tutorial/ tutorial_detail, edit_tutorial
├── profile/ public_profile, edit_profile
└── admin/ admin_users, admin_messages