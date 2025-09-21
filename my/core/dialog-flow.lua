-- core/dialog-stack.lua - Simple dialog flow implementation for AIO Launcher widgets
-- Supports radio and edit dialogs only (no list dialogs for simplicity)

local M = {}
local util = require "core.util"

function M.open_dialog(dialog_config, results)
    if dialog_config.type == "radio" then
        return M.open_radio_dialog(dialog_config, results)
    elseif dialog_config.type == "edit" then
        return M.open_input_dialog(dialog_config, results)
    elseif dialog_config.type == "checkbox" then
        return M.open_checkbox_dialog(dialog_config, results)
    elseif dialog_config.type == "list" then
        return M.open_list_dialog(dialog_config, results)
    elseif dialog_config.type == "text" then
        return M.open_text_dialog(dialog_config, results)
    end
end

function M.open_list_dialog(dialog_config, results)
    local lines = dialog_config.get_lines(results)
    dialogs:show_list_dialog({
        title = dialog_config.title,
        search = false,
        split_symbol = ":",
        lines = lines
    })

    return function(result)
        return result
    end
end

function M.open_text_dialog(dialog_config, results)
    local text = dialog_config.get_text(results)
    dialogs:show_dialog(dialog_config.title, text)

    return function(result)
        return result
    end
end

function M.open_checkbox_dialog(dialog_config, results)
    local options, metas = dialog_config.get_options(results)
    dialogs:show_checkbox_dialog(dialog_config.title, options)

    return function(result)
        if result == -1 then
            return -1
        end
        return { indices=result, values=util.map(result, function(r) return options[r] end), options=options }
    end
end

function M.open_radio_dialog(dialog_config, results)
    local options, metas = dialog_config.get_options(results)
    dialogs:show_radio_dialog(dialog_config.title, options)

    return function(result)
        if type(result) ~= "number" or result < 1 then
            return -1
        end
        if metas == nil then
            return { index=result, value=options[result] }
        else
            return { index=result, value=options[result], meta=metas[result] }
        end
    end
end

function M.open_input_dialog(dialog_config)
    local prompt = dialog_config.prompt
    local default_text = dialog_config.default_text or ""
    dialogs:show_edit_dialog(dialog_config.title, prompt, default_text)

    return function(result)
        if type(result) ~= "string" or result == "" then
            return -1
        end
        return result
    end
end

-- Dialog Flow for handling sequential dialog interactions
function M.create_dialog_flow()
    local flow = {
        config = nil,
        results = {},
        dialogs = {},
        parse_result = nil
    }

    function flow:start(config)
        self:clear()
        self.config = config
        self:push_dialog(self.config.main)
    end

    function flow:push_dialog(dialog_config)
        table.insert(self.dialogs, dialog_config)
        self:open_dialog(dialog_config)
    end

    function flow:open_dialog(dialog_config)
        self.parse_result = M.open_dialog(dialog_config, self.results)
    end

    function flow:handle_result(result)
        result = self.parse_result(result)
        if result == -1 then
            self:handle_cancel()
            return
        end

        table.insert(self.results, result)
        local next = self:get_current_dialog().handle_result(self.results, self.config)
        if next == -1 then
            self:handle_cancel()
            return
        elseif next then
            self:push_dialog(next)
        else
            self:handle_complete()
        end
    end

    function flow:handle_cancel()
        table.remove(self.dialogs)
        if not self:is_empty() then
            self:open_dialog(self:get_current_dialog())
        else
            self:clear()
        end
    end

    function flow:handle_complete()
        self:clear()
    end

    function flow:get_current_dialog()
        return self.dialogs[#self.dialogs]
    end

    function flow:is_empty()
        return #self.dialogs == 0
    end

    function flow:clear()
        self.config = nil
        self.dialogs = {}
        self.results = {}
        self.parse_result = nil
    end

    return flow
end

return M