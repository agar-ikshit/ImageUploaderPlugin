local LrHttp = import 'LrHttp'
local Config = require 'util/Config'
local Logger = require 'util/Logger'

local AlbumAPI = {}

function AlbumAPI.createAlbum(token, albumData)
    local url = Config.API_BASE_URL .. '/album'
    local headers = {
        { field = 'Authorization', value = token },
        { field = 'Content-Type', value = 'application/json' },
        { field = 'Source', value = Config.SOURCE_HEADER },
    }
    local body = {
        name = albumData.name,
        eventDate = albumData.eventDate .. 'T00:00:00.000Z',
        tags = {},
        participants = {},
        projectId = albumData.projectId,
    }
    for tag in string.gmatch(albumData.tags or '', '([^,]+)') do
        table.insert(body.tags, tag:match('^%s*(.-)%s*$'))
    end
    for p in string.gmatch(albumData.participants or '', '([^,]+)') do
        table.insert(body.participants, p:match('^%s*(.-)%s*$'))
    end
    local json = require 'dkjson'
    local bodyStr = json.encode(body)
    local result, hdrs = LrHttp.post(url, bodyStr, headers)
    if not result then
        Logger.log('Failed to create album')
        return nil, 'Failed to create album'
    end
    local resp, pos, err = json.decode(result, 1, nil)
    if not resp or not resp.album then
        Logger.log('Invalid album creation response')
        return nil, 'Invalid response'
    end
    return resp, nil
end

return AlbumAPI