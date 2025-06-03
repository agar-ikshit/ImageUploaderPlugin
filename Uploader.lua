local config = require("config")  -- load your config file

local LrTasks = import 'LrTasks'
local LrHttp = import 'LrHttp'
local LrDialogs = import 'LrDialogs'
local LrExportSession = import 'LrExportSession'

LrTasks.startAsyncTask(function()
    local exportSession = exportContext.exportSession
    local nPhotos = exportSession:countRenditions()

    local successCount = 0
    local failCount = 0

    for i, rendition in exportSession:renditions() do
        local success, pathOrMessage = rendition:waitForRender()

        if success then
            local file = io.open(pathOrMessage, "rb")
            local data = file:read("*all")
            file:close()

            local headers = {
                ["Content-Type"] = "image/jpeg",
                ["Authorization"] = "Bearer " .. config.api_key
            }

            local response = nil
            local try = 0

            repeat
                try = try + 1
                response = LrHttp.post(config.upload_url, data, { headers = headers })
            until (response and response ~= "") or try >= config.max_retries

            if response and response ~= "" then
                successCount = successCount + 1
            else
                failCount = failCount + 1
            end
        else
            failCount = failCount + 1
        end
    end

    -- Show final summary
    LrDialogs.message("Upload Summary", "Success: " .. successCount .. "\nFailed: " .. failCount, "info")
end)
