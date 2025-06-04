local LrHttp = import 'LrHttp'
local LrJSON = import 'LrJSON'

local M = {}

local apiToken = nil
local exportContext = nil

function M.setApiToken(token)
  apiToken = token
end

function M.setContext(context)
  exportContext = context
end

local function buildHeaders(extraHeaders)
  local headers = {
    ["Authorization"] = apiToken or "",
    ["Content-Type"] = "application/json",
    ["Source"] = "APP",
  }
  if extraHeaders then
    for k,v in pairs(extraHeaders) do
      headers[k] = v
    end
  end
  return headers
end

local function post(url, bodyTable)
  local body = LrJSON.encode(bodyTable)
  local headers = buildHeaders()
  local response, status = LrHttp.post(url, body, headers)

  if status ~= 200 and status ~= 201 then
    error("HTTP POST failed: " .. tostring(status) .. " Response: " .. tostring(response))
  end

  return LrJSON.decode(response)
end

function M.createAlbum(name, eventDate, tags, participants, projectId)
  local url = "https://gallery-go-backend-223066796377.us-central1.run.app/album"
  local body = {
    name = name,
    eventDate = eventDate,
    tags = tags,
    participants = participants,
    projectId = projectId,
  }

  local response = post(url, body)
  if not response.album or not response.album.id or not response.album.albumSetIds then
    error("Invalid album creation response: missing required fields")
  end

  return response.album, response.albumSet
end

function M.getSignedUrls(albumId, albumSetId, photos)
  local url = "https://gallery-go-backend-223066796377.us-central1.run.app/initUpload"
  local body = {
    albumId = albumId,
    albumSetId = albumSetId,
    photos = photos,
  }

  return post(url, body)
end

function M.finishUpload(albumId, photos, isLastBatch)
  local url = "https://gallery-go-backend-223066796377.us-central1.run.app/finishUpload"
  local body = {
    albumId = albumId,
    photos = photos,
  }
  if isLastBatch then
    body.isLastBatch = true
  end

  return post(url, body)
end

return M
