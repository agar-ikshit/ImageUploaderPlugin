# Uploader Gallery Lightroom Classic Plugin

## Overview
This plugin allows you to export and upload photos from Lightroom Classic to a custom gallery backend, following a multi-step, robust upload process with batching and retries.

## Features
- Create albums with metadata
- Batch upload photos (20 per batch)
- Upload both original and web versions
- Retry failed uploads with exponential backoff
- Mark upload completion per batch
- Works in background/minimized mode

## Setup
1. Copy the `UploaderGallery.lrplugin` folder to your Lightroom plugins directory.
2. Ensure you have the `dkjson.lua` library in the plugin folder (for JSON encoding/decoding).
3. In Lightroom Classic, go to `File > Plug-in Manager` and add the `UploaderGallery.lrplugin` folder.

## Usage
1. Select photos to export.
2. Choose `Uploader Gallery` as the export destination.
3. When prompted, enter your API token.
4. Fill in album details (name, date, tags, participants, projectId).
5. The plugin will process and upload photos in batches, showing a summary at the end.

## Testing Background/Lock Behavior
- **Background:** Uploading continues if Lightroom is minimized or in the background.
- **Locked Computer:** Uploading continues if the computer is locked (Win+L), as long as the system does not sleep.
- **Sleep:** If the computer sleeps, uploading will pause and resume when the system wakes up.

## Notes
- If an upload fails, it is retried up to 3 times with exponential backoff.
- Both original and web versions must upload successfully for a photo to be marked as uploaded.
- The plugin uses the API endpoints and flow described in the project documentation.

## Customization
- Edit `util/Config.lua` to change API base URL, batch size, or retry settings.

## Requirements
- Lightroom Classic 6.0+
- Internet connection
- API token for the gallery backend
- `dkjson.lua` (place in plugin root)

---
For support, contact the plugin author.