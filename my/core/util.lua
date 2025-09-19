local util = {}

function util.tables_to_array(...)
    local result = {}
    for _, tbl in ipairs({...}) do
        for _, v in pairs(tbl) do
            table.insert(result, v)
        end
    end
    return result
end

return util