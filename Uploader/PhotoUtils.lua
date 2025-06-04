local function getImageDimensions(filePath)
  local command = string.format('exiftool -ImageWidth -ImageHeight -s3 "%s"', filePath)
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()

  local width, height = result:match("(%d+)%s+(%d+)")
  return tonumber(width), tonumber(height)
end

local function getImageInfo(filePath)
  local command = string.format('exiftool -ImageWidth -ImageHeight -DateTimeOriginal -s3 "%s"', filePath)
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()

  local width, height, dateTime = result:match("(%d+)%s+(%d+)%s+([^\n]+)")
  return tonumber(width), tonumber(height), dateTime
end

local function getMimeType(filePath)
  local ext = filePath:match("^.+(%..+)$")
  if not ext then return "application/octet-stream" end

  ext = ext:lower()
  local map = {
    [".jpg"] = "image/jpeg",
    [".jpeg"] = "image/jpeg",
    [".png"] = "image/png",
    [".gif"] = "image/gif",
    [".tif"] = "image/tiff",
    [".tiff"] = "image/tiff",
    [".bmp"] = "image/bmp",
    [".webp"] = "image/webp",
  }

  return map[ext] or "application/octet-stream"
end

local function preparePhotoMetadata(photos)
  local prepared = {}
  for _, photo in ipairs(photos) do
    local width, height, dateTime = getImageInfo(photo.filePath)
    table.insert(prepared, {
      name = photo.name,
      type = getMimeType(photo.filePath),
      dimensionX = width or 0,
      dimensionY = height or 0,
      clickedAt = dateTime or photo.clickedAt or os.date("!%Y-%m-%dT%H:%M:%S+00:00"),
    })
  end
  return prepared
end

return {
  getImageDimensions = getImageDimensions,
  getImageInfo = getImageInfo,
  getMimeType = getMimeType,
  preparePhotoMetadata = preparePhotoMetadata,
}
