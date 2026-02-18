-- type = "widget"
-- name = "Currencies API example"
-- description = "Convert and refresh exchange rates"

local BASE = "EUR"
local QUOTE = "USD"

local function render()
    local value = currencies:rate(BASE, QUOTE, 1)
    if value == nil then
        ui:show_text("Rate not loaded yet: " .. BASE .. " -> " .. QUOTE)
    else
        ui:show_table({
            {"Pair", BASE .. "/" .. QUOTE},
            {"1 " .. BASE, tostring(value) .. " " .. QUOTE}
        }, 1)
    end
    ui:show_buttons({"Refresh", "Show supported count"})
end

function on_load()
    render()
    currencies:refresh("main")
end

function on_click(index)
    if index == 1 then
        currencies:refresh("main")
    elseif index == 2 then
        local all = currencies:supported()
        ui:show_toast("Supported currencies: " .. tostring(#all))
    end
end

function on_currencies_result_main(result)
    if result.ok then
        render()
    else
        ui:show_text("Currencies refresh failed: " .. tostring(result.error))
    end
end

