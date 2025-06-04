local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'
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

  -- Run the upload in a separate async task to avoid freezing Lightroom UI
  LrTasks.startAsyncTask(function()
    local status, err = pcall(function()

      local apiToken = exportContext.propertyTable.apiToken
      if not apiToken or apiToken == '' then
        error("API Token is required!")
      end

      Uploader.setApiToken(apiToken)
      Uploader.setContext(exportContext)

      -- Collect photos info after rendering
      local photos = {}
      for _, rendition in exportContext.renditions do
        local success, path = rendition:waitForRender()
        if success then
          table.insert(photos, {
            name = LrPathUtils.leafName(path),
            filePath = path,
          })
        else
          error("Failed to render photo")
        end
      end

      -- Create Album on server
      local album, albumSet = Uploader.createAlbum(
        exportContext.propertyTable.albumName,
        os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        { "tag1", "tag2" },           -- Customize or add UI to input these
        { "Person A", "Person B" },   -- Customize or add UI to input these
        exportContext.propertyTable.projectId
      )

      if not album or not album.id then
        error("Invalid album creation response: missing album ID")
      end

      local albumId = album.id
      local albumSetId = albumSet and albumSet.id

      if not albumSetId then
        error("Album Set ID not found in the response")
      end

      -- Upload photos in batches (uses your Uploader module)
      Uploader.uploadPhotosInBatches(albumId, albumSetId, photos)

      
      LrDialogs.message("Upload Complete", "All photos uploaded successfully!", "info")

    end)

    if not status then
      
      LrDialogs.message("Upload Failed", tostring(err), "critical")
    end
  end)
end

return exportServiceProvider
