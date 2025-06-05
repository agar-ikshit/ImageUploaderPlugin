local LrHttp = import 'LrHttp'
local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'

local Config = (loadfile(LrPathUtils.child(_PLUGIN.path, "util/Config.lua")))()
local Logger = (loadfile(LrPathUtils.child(_PLUGIN.path, "util/Logger.lua")))()

local UploadAPI = {}

local json = require 'dkjson'

function UploadAPI.getSignedUrls(token, albumId, albumSetId, photos)
    local url = Config.API_BASE_URL .. '/initUpload'
    local headers = {
        { field = 'Authorization', value = token },
        { field = 'Content-Type', value = 'application/json' },
        { field = 'Source', value = Config.SOURCE_HEADER },
    }
    local body = {
        albumId = albumId,
        albumSetId = albumSetId,
        photos = photos,
    }
    local bodyStr = json.encode(body)
    local result, hdrs = LrHttp.post(url, bodyStr, headers)
    if not result then
        Logger.log('Failed to get signed URLs')
        return nil, 'Failed to get signed URLs'
    end
    local resp, pos, err = json.decode(result, 1, nil)
    if not resp or not resp.photos then
        Logger.log('Invalid signed URL response')
        return nil, 'Invalid response'
    end
    return resp.photos, nil
end

local function uploadWithRetry(url, data, contentType, maxRetries)
    local attempt = 0
    local backoff = Config.INITIAL_BACKOFF
    while attempt < maxRetries do
        local headers = {
            { field = 'Content-Type', value = contentType },
        }
        local result, hdrs = LrHttp.put(url, data, headers)
        if result and (hdrs.status == 200 or hdrs.status == 201) then
            return true
        else
            attempt = attempt + 1
            Logger.debug('Upload failed, retry #' .. attempt .. ' for ' .. url)
            LrTasks.sleep(backoff)
            backoff = backoff * 2
        end
    end
    return false
end

function UploadAPI.uploadPhotoSet(photoSet, originalData, webData, contentType)
    -- photoSet: { _id, urls = { original, web } }
    local ok1 = uploadWithRetry(photoSet.urls.original, originalData, contentType, Config.MAX_RETRIES)
    local ok2 = uploadWithRetry(photoSet.urls.web, webData, contentType, Config.MAX_RETRIES)
    return ok1 and ok2
end

return UploadAPI