---
--- Created by xyzzycgn.
---

local surface_conditions = {}

function surface_conditions.surface_condition(property, min, max)
    return { property = property, min = min, max = max }
end

function surface_conditions.pressure()
    return surface_conditions.surface_condition("pressure", 800, 10000)
end

-- checks the existence of space age DLC and only if it's present return the result of the referred function
function surface_conditions.check_existence_of_SPA(func)
    if mods["space-age"] then
        return func()
    end

    return nil
end

return surface_conditions
