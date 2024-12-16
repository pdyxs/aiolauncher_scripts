-- name = "Remote Phone"
-- description = "Control a phone remotely via tasker"
-- type = "widget"
-- author = "Paul Sztajer"
-- version = "1.0"

function on_resume()
    local my_gui = gui{
        {"button", "%%fa:phone%% %%fa:star%%", {expand=true}}, 
        {"spacer", 1 },
        {"button", "%%fa:phone%% %%fa:address-book%%", {expand=true}}, 
        {"spacer", 1 },
        {"button", "%%fa:phone%% %%fa:clock-rotate-left%%", {expand=true}},
        {"spacer", 1 },
        {"button", "%%fa:phone%% %%fa:hashtag%%", {expand=true}}
    }
    my_gui.render();
end

function on_click(idx)
    if idx == 1 then
        tasker:run_task("Pick Favourite And Call")
    elseif idx == 3 then
        tasker:run_task("Pick And Call")
    elseif idx == 5 then
        tasker:run_task("Request History")
    elseif idx == 7 then
        tasker:run_task("Call Number")
    end
end