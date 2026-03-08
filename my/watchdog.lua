-- name = "Watchdog"
-- type = "widget"

function on_alarm()
    tasker:run_task("Watchdog")
    ui:show_text("✓")
end
