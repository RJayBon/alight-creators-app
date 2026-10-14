/// Category keys used by the app — MUST match the web `tutorials.category` values.
const List<String> kCategories = [
  'All',
  'Beginner',
  'Intermediate',
  'Advanced',
  'Tips & Tricks',
];

/// Sidebar / chip labels → server values.
const Map<String, String> kCategoryLabels = {
  'All':           'All',
  'Beginner':      'Beginners',
  'Intermediate':  'Intermediate',
  'Advanced':      'Advanced',
  'Tips & Tricks': 'Tips & Tricks',
};

/// Fallback avatar asset.
///
/// This used to point at `assets/images/icons/icon.svg` — the *launcher*
/// source. That file is a 512×512 adaptive-icon foreground with transparency,
/// which is not what an avatar placeholder should look like (and it was never
/// referenced anywhere, so the mismatch stayed hidden). The declared
/// `assets/images/default-avatar.webp` is the real one.
const String kDefaultAvatar = 'assets/images/default-avatar.webp';

/// Upload folder layout (relative to app documents dir).
///
/// Every writer must use these rather than a literal, so a rename can't leave
/// some files in an orphaned directory (that is exactly what happened between
/// `FileService.deleteFile` and the hand-written `'uploads/thumbnails'`
/// strings in the composer).
const String kUploadsDir      = 'uploads';
const String kAvatarsDir      = 'uploads/avatars';
const String kBannersDir      = 'uploads/banners';
const String kThumbnailsDir   = 'uploads/thumbnails';
const String kVideosDir       = 'uploads/videos';

/// Size limits (bytes) — same as web.
const int kThumbnailMaxBytes = 2 * 1024 * 1024;
const int kVideoMaxBytes     = 100 * 1024 * 1024;
const int kAvatarMaxBytes    = 2 * 1024 * 1024;
const int kBannerMaxBytes    = 4 * 1024 * 1024;

/// Playback speeds offered by the tutorial player (`AppVideoPlayer`).
///
/// 0.25/0.5 are the "slow that step down" presets this app exists for; 1.5/2
/// are for re-watching a clip you already know. No next/previous is
/// intentional — a tutorial has one guide clip and one result clip, they are
/// not a playlist.
const List<double> kPlayerSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// How far the player's chrome sits from the edge of the video box.
///
/// Small on purpose: the scrim paints to the true edge and only the controls
/// are inset, which is what "the buttons are hanging outside the frame" looked
/// like when the *background* was padded instead.
const double kPlayerControlInset = 6.0;

/// Bio written for the first-run administrator account (`AuthService.createFirstAdmin`).
///
/// Deliberately not the beginner-author copy the demo users carried — that text
/// was copied onto the admin row in the seed export, which read as a bug.
const String kAdminDefaultBio = 'Official Alight Creators administrator account.';

/// Domain used when building share links (mirrors web URL format).
const String kShareBaseUrl = 'https://alight-creators.xo.je';