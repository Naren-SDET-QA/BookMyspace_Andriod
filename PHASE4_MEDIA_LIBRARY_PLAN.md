# Phase 4 — CMS Media Library Implementation Plan

## Current State Assessment

The project already has a foundational media library layer:
- **Domain**: `CmsMediaAsset`, `CmsMediaRef`, `CmsMediaRules`, `CmsMediaRepository` (abstract)
- **Infrastructure**: `SupabaseCmsMediaRepository` (list, upload, delete)
- **Presentation**: `AdminMediaLibraryScreen` (basic grid, upload, search, delete, assign)
- **Providers**: `cmsMediaRepositoryProvider`, `cmsMediaAssetsProvider`
- **Storage**: `category-media` bucket with `cms/` namespace, RLS policies
- **Tests**: `cms_media_asset_test.dart` (basic rules tests)

## What Phase 4 Adds

### 1. Domain Layer Enhancements

**`cms_media_repository.dart`** — Add two methods to the abstract interface:
- `replace(old, name, bytes)` → upload new file, return new asset (caller updates CmsMediaRef)
- `listAll()` → unfiltered list for usage scanning

**`cms_media_asset.dart`** — Add:
- `CmsMediaRules.maxThumbnailWidth` constant (400px)
- `CmsMediaRules.isImageContentType(type)` helper
- `CmsMediaRules.humanReadableSize(bytes)` for display

### 2. Infrastructure Layer Enhancements

**`supabase_cms_media_repository.dart`** — Implement:
- `replace()`: delete old asset, upload new one at new timestamp path, return new asset
- `listAll()`: list without namespace filter for cross-reference scanning

### 3. Presentation Layer Enhancements

**`admin_media_library_screen.dart`** — Major enhancements:
- **Filter chips**: All / Images only (toggle)
- **Replace flow**: Long-press tile → "Replace" option → pick file → upload → return new ref
- **Usage badge**: Show "In use" chip on assets whose path appears in catalog content
- **Lazy thumbnails**: Use `CachedNetworkImage` with `filterQuality: FilterQuality.low` and `memCacheWidth` for memory efficiency
- **Empty state**: Branded empty state with illustration
- **Upload progress**: Show file name during upload
- **Grid responsiveness**: Adjust column count based on screen width

**`missing_media_placeholder.dart`** — New shared widget:
- Shown when `CmsMediaRef.url` fails to load or is empty
- Displays a branded placeholder with icon + "No image" text
- Used in: catalog preview, admin catalog editor, media library tiles

**`media_picker_button.dart`** — New reusable widget:
- A button that opens `AdminMediaLibraryScreen` in picker mode
- Returns `CmsMediaRef` via callback
- Shows current media thumbnail when assigned
- "Clear" button to remove assignment
- Used in `_NodeEditor` of `admin_catalog_screen.dart` replacing the raw URL text field

### 4. Integration with Admin Catalog Screen

**`admin_catalog_screen.dart`** — Replace the raw "Image address" `TextFormField` with `MediaPickerButton`:
- Shows current media thumbnail
- "Pick from library" opens `AdminMediaLibraryScreen` with `onAssign`
- "Clear" removes the media assignment
- Keeps the existing image preview below

### 5. Tests

**`cms_media_asset_test.dart`** — Extend:
- Test `humanReadableSize` for various byte values
- Test `isImageContentType` for various MIME types
- Test `replace` path validation
- Test `listAll` returns unfiltered results

**`admin_media_library_screen_test.dart`** — New widget test file:
- Test grid renders when assets load
- Test empty state shows when no assets
- Test search filters displayed assets
- Test filter chips toggle between all/images
- Test upload button triggers file picker
- Test delete shows confirmation dialog
- Test "Use" button returns CmsMediaRef via onAssign
- Test error state shows retry button

**`missing_media_placeholder_test.dart`** — New widget test file:
- Test renders placeholder icon and text
- Test adapts to available space

**`media_picker_button_test.dart`** — New widget test file:
- Test shows "No media" when CmsMediaRef is empty
- Test shows thumbnail when media is assigned
- Test clear button removes assignment

### 6. Router & Dashboard

No changes needed — route `/admin/media` and `AdminMediaLibraryScreen` already exist.

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/cms/presentation/widgets/missing_media_placeholder.dart` | Shared fallback widget |
| `lib/features/cms/presentation/widgets/media_picker_button.dart` | Reusable media picker button |
| `test/features/cms/admin_media_library_screen_test.dart` | Widget tests for media library |
| `test/features/cms/missing_media_placeholder_test.dart` | Widget tests for placeholder |
| `test/features/cms/media_picker_button_test.dart` | Widget tests for picker button |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/features/cms/domain/cms_media_repository.dart` | Add `replace()`, `listAll()` |
| `lib/features/cms/domain/cms_media_asset.dart` | Add helpers |
| `lib/features/cms/infrastructure/supabase_cms_media_repository.dart` | Implement `replace()`, `listAll()` |
| `lib/features/cms/presentation/screens/admin_media_library_screen.dart` | Filter, replace, usage badge, lazy thumbnails |
| `lib/features/cms/presentation/screens/admin_catalog_screen.dart` | Replace URL field with MediaPickerButton |
| `lib/features/cms/presentation/cms_media_providers.dart` | Add usage tracking provider |
| `test/features/cms/cms_media_asset_test.dart` | Extend tests |

## Security Constraints

- Media stored as `CmsMediaRef` (url + path) in JSON — never raw bytes
- Storage RLS: `public.is_category_manager()` gates all writes
- Path isolation: `cms/` namespace only, no `..` traversal
- Service-role key never exposed to client
- Missing media never crashes — always falls back to placeholder

## What Does NOT Change

- booking, payment, auth, Function Hall, 3D Glass Matrix, navigation, inventory
- No AI, MCP, external APIs, or advanced capabilities
- No new database tables or migrations
- No new storage buckets
