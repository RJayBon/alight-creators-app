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

const String kDefaultAvatar = 'assets/images/icons/icon.svg';

/// Upload folder layout (relative to app documents dir).
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

/// Domain used when building share links (mirrors web URL format).
const String kShareBaseUrl = 'https://alight-creators.xo.je';