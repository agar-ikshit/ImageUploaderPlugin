local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'


local AlbumAPI = (loadfile(LrPathUtils.child(_PLUGIN.path, "api/AlbumAPI.lua")))()
local UploadAPI = (loadfile(LrPathUtils.child(_PLUGIN.path, "api/UploadAPI.lua")))()
local FinishAPI = (loadfile(LrPathUtils.child(_PLUGIN.path, "api/FinishAPI.lua")))()
local Config = (loadfile(LrPathUtils.child(_PLUGIN.path, "util/Config.lua")))()
local Logger = (loadfile(LrPathUtils.child(_PLUGIN.path, "util/Logger.lua")))()

local dkjson = require 'dkjson'

local service = {}

function service.processRenderedPhotos(functionContext, exportContext)
    LrTasks.startAsyncTask(function()
        -- Prompt for API token
        local token = LrDialogs.promptForString('Enter API Token', '')
        if not token or token == '' then
            LrDialogs.message('Token required', 'You must provide an API token.', 'critical')
            return
        end
        -- Prompt for album details
        local albumData = AlbumDialog.promptForAlbum()
        if not albumData then
            LrDialogs.message('Album creation cancelled.')
            return
        end
        -- Create album
        local albumResp, err = AlbumAPI.createAlbum(token, albumData)
        if not albumResp then
            LrDialogs.message('Album creation failed', err or '', 'critical')
            return
        end
        local albumId = albumResp.album.id
        local albumSetId = albumResp.albumSet.id
        -- Gather photo info
        local photos = {}
        local renditions = {}
        for _, rendition in exportContext:renditions() do
            table.insert(renditions, rendition)
        end
        for i, rendition in ipairs(renditions) do
            local success, pathOrMsg = rendition:waitForRender()
            if success then
                local filePath = pathOrMsg
                local fileName = LrPathUtils.leafName(filePath)
                local fileType = 'image/jpeg' -- Assume JPEG for now
                local dimX, dimY = 0, 0
                -- Optionally, get image dimensions here
                photos[#photos+1] = {
                    name = fileName,
                    type = fileType,
                    dimensionX = dimX,
                    dimensionY = dimY,
                    clickedAt = os.date('!%Y-%m-%dT%H:%M:%S+00:00'),
                }
            else
                Logger.log('Failed to render photo: ' .. (pathOrMsg or ''))
            end
        end
        -- Batch upload
        local batchSize = Config.BATCH_SIZE
        local total = #photos
        local uploaded = 0
        local failed = 0
        for batchStart = 1, total, batchSize do
            local batchEnd = math.min(batchStart + batchSize - 1, total)
            local batch = {}
            for i = batchStart, batchEnd do
                table.insert(batch, photos[i])
            end
            -- Get signed URLs
            local signedPhotos, err = UploadAPI.getSignedUrls(token, albumId, albumSetId, batch)
            if not signedPhotos then
                Logger.log('Failed to get signed URLs for batch')
                failed = failed + #batch
            else
            -- Upload each photo in batch
            local finishPhotos = {}
            for i, photoSet in ipairs(signedPhotos) do
                local idx = batchStart + i - 1
                local rendition = renditions[idx]
                local filePath = rendition and rendition.destinationPath
                local fileData = filePath and LrFileUtils.readFile(filePath)
                -- For web version, just use the same file (or resize if needed)
                local webData = fileData
                local ok = false
                if fileData then
                    ok = UploadAPI.uploadPhotoSet(photoSet, fileData, webData, 'image/jpeg')
                end
                finishPhotos[#finishPhotos+1] = {
                    _id = photoSet._id,
                    status = ok and 1 or 0,
                    size = fileData and #fileData or 0,
                }
                if ok then uploaded = uploaded + 1 else failed = failed + 1 end
            end
            -- Mark upload completion for this batch
            local isLastBatch = (batchEnd == total)
            local _, err = FinishAPI.finishUpload(token, albumId, finishPhotos, isLastBatch)
        end -- closes the 'if not signedPhotos ... else ... end'
    end -- closes the 'for batchStart = 1, total, batchSize do' loop

    LrDialogs.message('Upload Complete', string.format('Uploaded: %d, Failed: %d', uploaded, failed), 'info')
    end) -- closes LrTasks.startAsyncTask
end -- closes service.processRenderedPhotos

return  {
    title = "Uploader Gallery",
    hideSections = { 'exportLocation', 'fileNaming' },
    allowFileFormats = { 'JPEG' },
    allowColorSpaces = { 'sRGB' },
    exportPresetFields = {
        { key = 'albumName', default = 'Untitled Album' },
    },
    processRenderedPhotos = service.processRenderedPhotos
}