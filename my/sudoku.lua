-- name = "Sudoku Stats"
-- description = "Shows the stats of my puzzles in the side menu"
-- type = "drawer"
-- author = "pdyxs"

local puzzles = {
    "Cartography", 
    "A murder most fogged", 
    "Plans of a Medic", 
    "Recounting the Counting", 
    "The grid of forking paths", 
    "Something this puzzle might give you", 
    "Little Fillers",
    "Commonality"
}

function on_drawer_open()
    local newPuzzles = {}

    for k, puzzle in pairs(puzzles) do
        newPuzzles[k] = puzzle;
    end
    drawer:show_list(newPuzzles)

    for k, puzzle in pairs(puzzles) do
        local key = string.lower(puzzle:gsub(" ", ""))
        -- newPuzzles[k] = key;
        local response = shttp:get("https://api.sudokupad.com/counter/pdyxs-"..key)

        if response.code >= 200 and response.code < 300 then
            newPuzzles[k] = "["..ajson:get_value(response.body, "object double:count").."] "..puzzle
        end

        drawer:show_list(newPuzzles)
    end

    drawer:show_list(newPuzzles)
end