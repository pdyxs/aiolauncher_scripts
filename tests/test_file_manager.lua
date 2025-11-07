package.path = package.path .. ";../my/core/?.lua;../lib/?.lua;./my/core/?.lua;./lib/?.lua"

-- Load utils to extend string with split() and other methods
require "utils"

-- Mock modules required by file-manager
_G.tasker = {
    run_task = function(self, name, params)
    end
}

require 'busted.runner'()

describe("File Manager", function()
    local file_manager
    local parser
    local manager
    local test_filepath = "test.md"
    local test_content = "This is a test markdown content: with: colons."
    local parsed_prefix = "Parsed: "
    local tasker_spy
    local match = require("luassert.match")

    setup(function()
        tasker_spy = spy.on(_G.tasker, "run_task")
    end)

    before_each(function()
        tasker_spy:clear()
        package.loaded.prefs = {}
        file_manager = require "file-manager"
        parser = {
            version = 1,
            parse = function(content)
                return parsed_prefix .. content
            end
        }
        manager = file_manager.create()
    end)

    after_each(function()
        package.loaded['file-manager'] = nil
        package.loaded.prefs = {}
        file_manager = nil
        parser = nil
        manager = nil
    end)

    it("loads and caches markdown files", function()
        local received_data = nil
        manager:load(test_filepath, function(data)
            received_data = data
        end, parser)
        assert.spy(tasker_spy).was.called_with(match.is_truthy(), "Load_Markdown", {
            filepath = test_filepath,
            last_updated = 0
        })

        -- Simulate command from tasker
        local command_data = "MarkdownData:" .. test_filepath .. ":123456:" .. test_content
        manager:on_command(command_data)

        -- Verify that the callback was called with parsed content
        assert.are.equal(parsed_prefix .. test_content, received_data, "Markdown content should be parsed correctly")

        -- Verify that the content is cached
        local cached_data = manager:get(test_filepath)
        assert.are.equal(parsed_prefix .. test_content, cached_data, "Cached markdown content should match parsed content")
    end)

    it("sends tasker command with last updated timestamp", function()
        local last_updated_sent = nil

        manager:load(test_filepath, function(data) end, parser)
        assert.spy(tasker_spy).was.called_with(match.is_truthy(), "Load_Markdown", {
            filepath = test_filepath,
            last_updated = 0
        })
        tasker_spy:clear()

        -- Simulate command from tasker to cache content
        local command_data = "MarkdownData:" .. test_filepath .. ":123456:" .. test_content
        manager:on_command(command_data)

        -- Second load, should send actual last_updated timestamp
        manager:load(test_filepath, function(data) end, parser)
        assert.spy(tasker_spy).was.called_with(match.is_truthy(), "Load_Markdown", {
            filepath = test_filepath,
            last_updated = 123456
        })
        
    end)
end)