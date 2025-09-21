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

function util.map(tbl, func)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = func(v, k)
    end
    return result
end

function util.contains(array, value)
    for i, v in ipairs(array) do
        if v == value then return true end
    end
    return false
end

return util