local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrFunctionContext = import 'LrFunctionContext'

local AlbumDialog = {}

function AlbumDialog.promptForAlbum()
    local f = LrView.osFactory()
    local props = LrView.bindable()
    props.name = ''
    props.eventDate = ''
    props.tags = ''
    props.participants = ''
    props.projectId = ''

    local c = f:column {
        bind_to_object = props,
        spacing = f:control_spacing(),
        f:static_text { title = 'Create Album for Uploader Gallery' },
        f:edit_field { value = LrView.bind('name'), width_in_chars = 30, placeholder_string = 'Album Name' },
        f:edit_field { value = LrView.bind('eventDate'), width_in_chars = 30, placeholder_string = 'Event Date (YYYY-MM-DD)' },
        f:edit_field { value = LrView.bind('tags'), width_in_chars = 30, placeholder_string = 'Tags (comma separated)' },
        f:edit_field { value = LrView.bind('participants'), width_in_chars = 30, placeholder_string = 'Participants (comma separated)' },
        f:edit_field { value = LrView.bind('projectId'), width_in_chars = 30, placeholder_string = 'Project ID' },
    }

    local result = LrDialogs.presentModalDialog {
        title = 'Create Album',
        contents = c,
    }

    if result == 'ok' then
        return {
            name = props.name,
            eventDate = props.eventDate,
            tags = props.tags,
            participants = props.participants,
            projectId = props.projectId,
        }
    else
        return nil
    end
end

return AlbumDialog