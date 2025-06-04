local API = require 'Uploader.API'
local Utils = require 'Uploader.PhotoUtils'
local Upload = require 'Uploader.UploadHelpers'

local M = {}

function M.setApiToken(token)
  API.setApiToken(token)
end

function M.setContext(context)
  API.setContext(context)
end

function M.createAlbum(name, eventDate, tags, participants, projectId)
  return API.createAlbum(name, eventDate, tags, participants, projectId)
end

function M.uploadPhotosInBatches(albumId, albumSetId, photos)
  Upload.uploadInBatches(albumId, albumSetId, photos)
end

return M
