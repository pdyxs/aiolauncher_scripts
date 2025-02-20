-- name = "Tick Tick"
-- author = "Paul Sztajer"
-- version = "1.0"
-- uses_app = "com.ticktick.task"
-- on_resume_when_folding = "true"

local prefs = require "prefs"
local fmt = require "fmt"

local w_bridge = nil
local lines = {}
local link_numbers = {}
local listname = nil

function on_resume()
    if not widgets:bound(prefs.wid) then
        setup_app_widget()
    end

    widgets:request_updates(prefs.wid)
end

function on_app_widget_updated(bridge)
    local strings = bridge:dump_strings().values
    lines = {}

    -- We use dump_tree instead of dump_table because Lua tables
    -- do not preserve the order of elements (which is important in this case).
    -- Additionally, the text tree is simply easier to parse.
    local tree = bridge:dump_tree()
    local all_lines = extract_list_item_lines(tree)
    lines = combine_lines(all_lines)

    table.insert(lines, "%%fa:square-plus%% "..fmt.secondary("Add task"))

    listname = string.sub(strings[1], 4, #strings[1] - 4)

    w_bridge = bridge
    if (ui:folding_flag()) then
        local line1 = lines[1]
        if #lines == 1 then
            line1 = fmt.secondary("All done!").." %%fa:party-horn%%"
        end

        local extra = ""
        if #lines > 2 then
            extra = fmt.secondary(" (+"..(#lines - 2)..")")
        end

        my_gui = gui{
            {"text", strings[1]..": "},
            {"text", line1..extra},
            {"icon", "fa:square-plus", {gravity="right"}},
            {"spacer", 3}
        }
        my_gui.render()
        lines[1] = strings[1]..": "..lines[1]
    else
        table.insert(lines, 1, strings[1])
        ui:show_lines(lines)
    end
end

function on_click(idx)
    if (ui:folding_flag()) then
        if idx == 1 then
            tasker:run_task("TickTick list "..listname)
        elseif idx == 2 then
            if (#lines > 1) then
                w_bridge:click("text_"..link_numbers[idx])
            end
        else
            w_bridge:click("image_3")
        end
    else
        if idx == #lines then
            -- "Plus" button
            w_bridge:click("image_3")
        elseif idx == 1 then
            tasker:run_task("TickTick list "..listname)
        else
            -- First task name
            w_bridge:click("text_"..link_numbers[idx])
        end
    end
end

function on_settings()
    w_bridge:click("text_1")
end

-- Extract all elements with a nesting level of 6 (task texts and dates)
function extract_list_item_lines(str)
    for line in str:gmatch("[^\n]+") do
        if line:match("^%s%s%s%s%s%s%s%s%s%s%s%s") then
            table.insert(lines, extract_text_after_colon(line))
        end
    end
    return lines
end

-- Tasks list elements in the the dump are separated by a 1x1 image,
-- so we can use it to understand where one task ends and another begins.
function combine_lines(lines)
    local result = {}
    local temp_lines = {}
    local last_count = 2
    local counts = {1}

    for i, line in ipairs(lines) do
        if line == "1x1" then
            if #temp_lines > 0 then
                table.insert(result, concat_lines(temp_lines))
                table.insert(counts, last_count)
                last_count = last_count + #temp_lines
                temp_lines = {}
            end
        else
            table.insert(temp_lines, line)
        end
    end

    if #temp_lines > 0 then
        table.insert(result, concat_lines(temp_lines))
        table.insert(counts, last_count)
    end

    link_numbers = counts
    return result
end

-- The text and date of a task in the dump appear consecutively,
-- and we need to combine them, keeping in mind that the date might be absent.
function concat_lines(lines)
    if lines[1] then
        lines[1] = fmt.primary(lines[1])
    end

    if lines[2] then
        lines[2] = fmt.secondary(lines[2])
    end

    return table.concat(lines, fmt.secondary(" - "))
end

function extract_text_after_colon(text)
    return text:match(":%s*(.*)")
end

function setup_app_widget()
    local id = widgets:setup("com.ticktick.task/com.ticktick.task.activity.widget.GoogleTaskAppWidgetProviderLarge")
    if (id ~= nil) then
        prefs.wid = id
    else
        ui:show_text("Can't add widget")
    end
end
