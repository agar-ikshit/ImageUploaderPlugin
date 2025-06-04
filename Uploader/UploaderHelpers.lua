local LrFileUtils = import 'LrFileUtils'
local API = require 'Uploader.API'

local M = {}

local function sleep(sec)
  local start = os.time()
  repeat until os.time() > start + sec
end

function M.uploadWithRetry(url, filePath, contentType)
  local maxRetries = 3
  local retryDelay = 1 -- seconds

  for attempt = 1, maxRetries do
    local file = io.open(filePath, "rb")
    if not file then
      error("Cannot open file: " .. filePath)
    end
    local data = file:read("*all")
    file:close()

    local headers = {
      ["Content-Type"] = contentType or "application/octet-stream",
    }

    local ok, err = pcall(function()
      local response, status = require('LrHttp').put(url, data, headers)
      if status < 200 or status >= 300 then
        error("HTTP PUT failed: " .. tostring(status))
      end
    end)

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

function M.uploadPhotoWithRetries(photoUrls, originalFilePath, webFilePath)
  local maxRetries = 3
  local retryDelay = 1

  local function upload(url, filePath)
    return M.uploadWithRetry(url, filePath, "image/jpeg")
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

local function splitIntoBatches(t, batchSize)
  local batches = {}
  for i = 1, #t, batchSize do
    table.insert(batches, {table.unpack(t, i, math.min(i + batchSize - 1, #t))})
  end
  return batches
end

function M.uploadInBatches(albumId, albumSetId, photos)
  local batches = splitIntoBatches(photos, 20)

  for batchIndex, batchPhotos in ipairs(batches) do
    local photoMetadata = {}
    local Utils = require 'Uploader.PhotoUtils'

    -- Prepare photo metadata with dimensions, MIME, clickedAt etc.
    photoMetadata = Utils.preparePhotoMetadata(batchPhotos)

    -- Step 2: Get signed URLs
    local initResponse = API.getSignedUrls(albumId, albumSetId, photoMetadata)

    if not initResponse.photos or #initResponse.photos == 0 then
      error("No signed URLs returned for batch " .. batchIndex)
    end

    local uploadedPhotos = {}

    for i, photoInfo in ipairs(initResponse.photos) do
      local photo = batchPhotos[i]
      local urls = photoInfo.urls
      local originalPath = photo.filePath
      local webPath = photo.webFilePath or photo.filePath

      local success, err = M.uploadPhotoWithRetries(urls, originalPath, webPath)

      table.insert(uploadedPhotos, {
        _id = photoInfo._id,
        status = success and 1 or 0,
        size = LrFileUtils.fileAttributes(originalPath).fileSize or 0,
      })

      if not success then
        -- Optionally log failure here
      end
    end

    local isLastBatch = (batchIndex == #batches)
    local finishResponse = API.finishUpload(albumId, uploadedPhotos, isLastBatch)

    if not finishResponse then
      error("Failed to mark upload completion for batch " .. batchIndex)
    end
  end
end

return M
