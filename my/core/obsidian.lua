--- Obsidian integration module
-- Provides functions to open Obsidian files and vaults
local obsidian = {}

local url = require "url"

--- Opens a specific file in Obsidian
-- @param file_path The path to the file within the vault (e.g. "Daily Notes/2025-01-21.md")
function obsidian.open_file(file_path)
    local encoded_file = url.quote(file_path)
    intent:start_activity{
        action = "android.intent.action.VIEW",
        data = "obsidian://open?file=" .. encoded_file
    }
end

--- Opens Obsidian to the default vault
function obsidian.open()
    intent:start_activity{
        action = "android.intent.action.VIEW",
        data = "obsidian://open"
    }
end

return obsidian