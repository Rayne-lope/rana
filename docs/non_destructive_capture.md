# Non-destructive Capture Storage

Rana stores new captures as clean, geometrically corrected images in Android
MediaStore. Film preset and Rana Style settings remain private app metadata and
are reapplied when Rana renders the image.

## SQLite schema

`capture_styles` contains one row per clean MediaStore URI:

- `clean_image_uri`: stable `content://` key and primary key;
- `preset_id`: preset active at capture time;
- `undertone_x` / `undertone_y`: indexed style coordinates for future editing;
- `created_at_epoch_ms`: metadata creation time.
- `updated_at_epoch_ms`: cache/version timestamp changed by future style edits.

`capture_style_params` stores the complete flat renderer payload as typed
key/value rows. Supported types are null, Boolean, finite number, String, and
finite numeric list. Its composite primary key is `(clean_image_uri,
param_key)`. A foreign key with `ON DELETE CASCADE` removes renderer parameters
when a capture metadata row is deleted.

## Capture transaction

On Android 10 and newer, the clean MediaStore item remains `IS_PENDING` while
Rana writes its SQLite metadata. Rana publishes the media item only after the
metadata commit succeeds. A metadata or publish failure deletes both records.
Older Android versions use the same rollback behavior, although MediaStore does
not provide pending-item isolation there.

Legacy captures without metadata remain valid flat images and bypass dynamic
rendering.

## Dynamic rendering

Rana's Gallery thumbnails, capture Result image, and Photo Detail image decode
the clean MediaStore source and reapply the stored renderer payload. Detail
renders default to a 2048-pixel target while thumbnails keep their requested
size. A bounded in-memory byte cache is keyed by URI, target size, and
`updated_at_epoch_ms`, so a future metadata edit invalidates stale output.

Dust offsets are generated once at capture and persisted with the renderer
payload. Date stamps use `created_at_epoch_ms`. These choices keep repeated
thumbnail and detail renders visually stable and consistent with the original
capture.

If metadata is absent or dynamic rendering fails, Rana falls back to loading
the MediaStore image directly. Successful deletion removes both the MediaStore
item and its metadata/cache entry.
