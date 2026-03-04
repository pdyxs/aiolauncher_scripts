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

function util.filter(tbl, predicate)
    local result = {}
    for k, v in pairs(tbl) do
        if predicate(v, k) then
            if type(k) == "number" then
                table.insert(result, v)
            else
                result[k] = v
            end
        end
    end
    return result
end

-- Normalises a table that may have string-integer keys (e.g. after prefs
-- round-trip through JSON) into a proper sequential array, ordered by key.
function util.to_array(tbl)
    if not tbl then return {} end
    local keys = {}
    for k in pairs(tbl) do
        local n = tonumber(k)
        if n then table.insert(keys, { k = k, n = n }) end
    end
    table.sort(keys, function(a, b) return a.n < b.n end)
    local result = {}
    for _, pair in ipairs(keys) do
        table.insert(result, tbl[pair.k])
    end
    return result
end

function util.concat_arrays(...)
    local result = {}
    for _, array in ipairs({...}) do
        for i = 1, #array do
            table.insert(result, array[i])
        end
    end
    return result
end

return util