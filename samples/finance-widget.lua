-- type = "widget"
-- name = "Finance API example"
-- description = "Price + async company/search/chart demo (Rich UI)"

local SYMBOL = "AAPL"
local last_company = nil
local last_search = nil
local last_chart_points = nil
local my_gui = nil

local function render()
    local price = finance:price(SYMBOL)
    local company_name = last_company and last_company.name or "n/a"
    local search_count = last_search and tostring(#last_search) or "n/a"
    local chart_count = last_chart_points and tostring(#last_chart_points) or "n/a"

    my_gui = gui{
        {"icon", "fa:chart-line", {size = 16, color = "#4caf50", gravity = "center_v"}},
        {"spacer", 2},
        {"text", "<b>" .. SYMBOL .. "</b>", {size = 18, gravity = "center_v"}},
        {"spacer", 2},
        {"text", tostring(price or "n/a"), {size = 16, gravity = "center_v"}},
        {"new_line", 1},
        {"text", "Company: " .. company_name},
        {"new_line", 1},
        {"text", "Search count: " .. search_count},
        {"new_line", 1},
        {"text", "Chart points: " .. chart_count},
        {"new_line", 2},
        {"button", "Refresh"},
        {"spacer", 2},
        {"button", "Company"},
        {"spacer", 2},
        {"button", "Search"},
        {"spacer", 2},
        {"button", "Chart"},
    }

    my_gui.render()
end

function on_load()
    render()
end

function on_resume()
    render()
end

function on_click(idx)
    local elem = my_gui and my_gui.ui and my_gui.ui[idx]
    if not elem or elem[1] ~= "button" then
        return
    end

    local action = elem[2]
    if action == "Refresh" then
        render()
    elseif action == "Company" then
        finance:company(SYMBOL, "demo")
    elseif action == "Search" then
        finance:search(SYMBOL, "demo")
    elseif action == "Chart" then
        finance:chart(SYMBOL, "demo")
    end
end

function on_finance_company_demo(result)
    if result.ok and result.data then
        last_company = result.data
        render()
    else
        ui:show_toast("Company error: " .. tostring(result.error))
    end
end

function on_finance_search_demo(result)
    if result.ok and result.data then
        last_search = result.data
        render()
    else
        ui:show_toast("Search error: " .. tostring(result.error))
    end
end

function on_finance_chart_demo(result)
    if result.ok and result.data then
        last_chart_points = result.data
        render()
    else
        ui:show_toast("Chart error: " .. tostring(result.error))
    end
end
