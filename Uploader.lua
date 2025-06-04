local LrHttp = import 'LrHttp'
local LrJSON = import 'LrJSON'
local LrFileUtils = import 'LrFileUtils'

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

local function put(url, filePath, contentType)
  local file = io.open(filePath, "rb")
  if not file then
    error("Cannot open file: " .. filePath)
  end
  local data = file:read("*all")
  file:close()

  local headers = {
    ["Content-Type"] = contentType or "application/octet-stream",
  }
  local response, status = LrHttp.put(url, data, headers)

  if status < 200 or status >= 300 then
    error("HTTP PUT failed: " .. tostring(status))
  end

  return true
end

local function sleep(sec)
  local start = os.time()
  repeat until os.time() > start + sec
end

function M.uploadWithRetry(url, filePath, contentType)
  local maxRetries = 3
  local retryDelay = 1 -- seconds

  for attempt = 1, maxRetries do
    local ok, err = pcall(put, url, filePath, contentType)
    if ok then
      return true
    else
      if attempt == maxRetries then
        return false, err
      else
        sleep(retryDelay)
        retryDelay = retryDelay * 2
      end
    end
  end
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

local function splitIntoBatches(t, batchSize)
  local batches = {}
  for i = 1, #t, batchSize do
    table.insert(batches, {table.unpack(t, i, math.min(i + batchSize - 1, #t))})
  end
  return batches
end

local function getImageDimensions(filePath)
  local command = string.format('exiftool -ImageWidth -ImageHeight -s3 "%s"', filePath)
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()

  local width, height = result:match("(%d+)%s+(%d+)")
  return tonumber(width), tonumber(height)
end

local function preparePhotoMetadata(photos)
  local prepared = {}
  for _, photo in ipairs(photos) do
    local width, height = getImageDimensions(photo.filePath)

    table.insert(prepared, {
      name = photo.name,
      type = "image/jpeg", -- Optional: make this dynamic later
      dimensionX = width or 0,
      dimensionY = height or 0,
      clickedAt = photo.clickedAt or os.date("!%Y-%m-%dT%H:%M:%S+00:00")
    })
  end
  return prepared
end

local function uploadPhotoWithRetries(photoUrls, originalFilePath, webFilePath)
  local maxRetries = 3
  local retryDelay = 1

  local function upload(url, filePath)
    local ok, err = pcall(M.uploadWithRetry, url, filePath, "image/jpeg")
    return ok, err
  end

  -- Upload original
  for attempt = 1, maxRetries do
    local ok, err = upload(photoUrls.original, originalFilePath)
    if ok then break
    elseif attempt == maxRetries then return false, "Failed original upload: "..tostring(err)
    else
      os.execute("sleep " .. tonumber(retryDelay))
      retryDelay = retryDelay * 2
    end
  end

  -- Reset retry delay for web upload
  retryDelay = 1

  -- Upload web (downsized)
  for attempt = 1, maxRetries do
    local ok, err = upload(photoUrls.web, webFilePath)
    if ok then return true
    elseif attempt == maxRetries then return false, "Failed web upload: "..tostring(err)
    else
      os.execute("sleep " .. tonumber(retryDelay))
      retryDelay = retryDelay * 2
    end
  end
end



function M.uploadPhotosInBatches(albumId, albumSetId, photos)
  local batchSize = 20
  local batches = splitIntoBatches(photos, batchSize)

  for batchIndex, batchPhotos in ipairs(batches) do
    local photoMetadata = preparePhotoMetadata(batchPhotos)

    -- Step 2: Get signed URLs
    local initResponse = M.getSignedUrls(albumId, albumSetId, photoMetadata)

    if not initResponse.photos or #initResponse.photos == 0 then
      error("No signed URLs returned for batch " .. batchIndex)
    end

    -- Upload photos in this batch
    local uploadedPhotos = {}

    for i, photoInfo in ipairs(initResponse.photos) do
      local photo = batchPhotos[i]
      local urls = photoInfo.urls
      local originalPath = photo.filePath
      local webPath = photo.webFilePath or photo.filePath  -- replace with actual downsized path if you have it

      -- Upload with retry (both original and web)
      local success, err = uploadPhotoWithRetries(urls, originalPath, webPath)

      table.insert(uploadedPhotos, {
        _id = photoInfo._id,
        status = success and 1 or 0,
        size = LrFileUtils.fileAttributes(originalPath).fileSize or 0,
      })

      if not success then
        -- Log or handle failed photo upload here
        -- You may decide to continue or stop depending on your requirements
      end
    end

    -- Step 4 & 5: Mark upload completion for this batch
    local isLastBatch = (batchIndex == #batches)
    local finishResponse = M.finishUpload(albumId, uploadedPhotos, isLastBatch)

    if not finishResponse then
      error("Failed to mark upload completion for batch " .. batchIndex)
    end
  end
end



-- You still need to implement:
-- - batching photos in groups of 20
-- - resizing photos if needed before upload
-- - uploadPhotosInBatches function that will:
--   * get signed URLs from server
--   * upload photos with retry using uploadWithRetry
--   * call finishUpload after each batch

return M
