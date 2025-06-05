local LrHttp = import 'LrHttp'
local Config = require 'util/Config'
local Logger = require 'util/Logger'

local FinishAPI = {}
local json = require 'dkjson'

function FinishAPI.finishUpload(token, albumId, photos, isLastBatch)
    local url = Config.API_BASE_URL .. '/finishUpload'
    local headers = {
        { field = 'Authorization', value = token },
        { field = 'Content-Type', value = 'application/json' },
        { field = 'Source', value = Config.SOURCE_HEADER },
    }
    local body = {
        albumId = albumId,
        photos = photos,
    }
    if isLastBatch then
        body.isLastBatch = true
    end
    local bodyStr = json.encode(body)
    local result, hdrs = LrHttp.post(url, bodyStr, headers)
    if not result then
        Logger.log('Failed to finish upload')
        return nil, 'Failed to finish upload'
    end
    local resp, pos, err = json.decode(result, 1, nil)
    if not resp or not resp.message then
        Logger.log('Invalid finish upload response')
        return nil, 'Invalid response'
    end
    return resp, nil
end

return FinishAPI