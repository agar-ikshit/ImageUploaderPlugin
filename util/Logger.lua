local Logger = {}

function Logger.log(msg)
    local LrDialogs = import 'LrDialogs'
    LrDialogs.message('UploaderGallery Log', tostring(msg), 'info')
end

function Logger.debug(msg)
    -- For more verbose logging, could write to a file
    -- For now, just print to console
    print('[UploaderGallery DEBUG] ' .. tostring(msg))
end

return Logger