local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local bind = LrView.bind

local exportServiceProvider = {}

exportServiceProvider.hideSections = { 'exportLocation', 'video', 'metadata', 'watermarking' }

exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = { 'sRGB' }

exportServiceProvider.exportPresetFields = {
  { key = 'apiToken', default = '' },
  { key = 'albumName', default = 'My Album' },
  { key = 'projectId', default = '' },
}

exportServiceProvider.sectionsForBottomOfDialog = function(viewFactory, propertyTable)
  return {
    {
      title = 'Gallery Upload Settings',

      synopsis = bind 'albumName',

      viewItems = {
        viewFactory:edit_field {
          title = 'API Token',
          value = bind 'apiToken',
          width_in_chars = 40
        },

        viewFactory:edit_field {
          title = 'Album Name',
          value = bind 'albumName',
          width_in_chars = 30
        },

        viewFactory:edit_field {
          title = 'Project ID',
          value = bind 'projectId',
          width_in_chars = 30
        },
      }
    }
  }
end

exportServiceProvider.processRenderedPhotos = function(functionContext, exportContext)
  local Uploader = require 'Uploader'

  -- Set API token from user input in UI
  local apiToken = exportContext.propertyTable.apiToken
  if not apiToken or apiToken == '' then
    LrDialogs.message("Error", "API Token is required!", "critical")
    return
  end
  Uploader.setApiToken(apiToken)
  Uploader.setContext(exportContext)

  -- Collect photo info after rendering
  local photos = {}
  for _, rendition in exportContext.renditions do
    local success, path = rendition:waitForRender()
    if success then
      table.insert(photos, {
        name = LrPathUtils.leafName(path),
        filePath = path,
      })
    end
  end

  -- Create Album
  local album, albumSet = Uploader.createAlbum(
    exportContext.propertyTable.albumName,
    os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
    { "tag1", "tag2" },           -- Customize or get from UI if you want
    { "Person A", "Person B" },   -- Customize or get from UI
    exportContext.propertyTable.projectId
  )

  -- Use album.id and albumSet.id for next steps
  local albumId = album.id
  local albumSetId = albumSet and albumSet.id

  if not albumSetId then
    LrDialogs.message("Error", "Album Set ID not found in the response", "critical")
    return
  end

  -- Upload photos in batches (you must implement this in Uploader)
  Uploader.uploadPhotosInBatches(albumId, albumSetId, photos)

  LrDialogs.message("Upload Complete", "All photos uploaded successfully!", "info")
end

return exportServiceProvider
