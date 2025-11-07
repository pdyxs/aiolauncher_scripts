local file_manager = {}
local prefs = require "prefs"

local COMMAND_DELIM = ":"

function file_manager.create()
    local manager = {
        loading = {}
    }

    function manager:load(filepath, callback, parser)
        local cache = prefs.file_manager_cache or {}
        local last_updated = 0

        if cache[filepath] then
            if cache[filepath].parser_version == parser.version then
                last_updated = cache[filepath].last_updated
            end
        end

        self.loading[filepath] = {
            parser = parser,
            callback = callback
        }

        tasker:run_task("Load_Markdown", {
            filepath = filepath,
            last_updated = last_updated
        })
    end

    function manager:get(filepath)
        local cache = prefs.file_manager_cache or {}
        if cache[filepath] then    
            return cache[filepath].data
        end
        
        return nil
    end

    function manager:on_command(data)
        local parts = data:split(COMMAND_DELIM)
        if #parts < 1 then
            return
        end

        if parts[1] == "MarkdownData" then
            local filepath = parts[2]
            local lastUpdated = tonumber(parts[3])
            local callback = self.loading[filepath].callback
            local parser = self.loading[filepath].parser
            local content = parser.parse(table.concat(parts, COMMAND_DELIM, 4))

            local cache = prefs.file_manager_cache or {}
            cache[filepath] = {
                data = content,
                last_updated = lastUpdated,
                parser_version = parser.version
            }
            prefs.file_manager_cache = cache

            callback(content)
        end
    end

    return manager
end

return file_manager