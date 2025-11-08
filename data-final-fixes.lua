require("constants")
local collision_mask_util = require("__core__.lualib.collision-mask-util")

hovercraft_entities = {
  ["hovercraft-collision"] = true,
  ["hovercraft"] = true,
  ["missile-hovercraft"] = true,
  ["electric-hovercraft"] = true,
  ["laser-hovercraft"] = true,
}

local prototypes = collision_mask_util.collect_prototypes_with_layer("player")

data:extend{
  {
    type = "collision-layer",
    name = "hovercraft",
  }
}


for _, prototype in pairs(prototypes) do
  if prototype.type ~= "tile" and not hovercraft_entities[prototype.name] then
    local collision_mask = collision_mask_util.get_mask(prototype)
    if not collision_mask.layers.is_object and not collision_mask.layers.train and not collision_mask.layers.car then
      -- Entity doesn't already collide with hovercraft, so add hovercraft layer to it
      -- E.g. aquilo icebergs, vulcanus chimneys
      collision_mask.layers.hovercraft = true
      prototype.collision_mask = collision_mask
    end
  end
end

for name, _ in pairs(hovercraft_entities) do
  local prototype = data.raw.car[name]
  if prototype then
    prototype.collision_mask.layers["player"] = nil
    prototype.collision_mask.layers["hovercraft"] = true
  end
end


local burner_hovercrafts = {
  data.raw["car"]["hovercraft"],
  data.raw["car"]["missile-hovercraft"],
}

if mods["IndustrialRevolution"] then
  for _, prototype in pairs(burner_hovercrafts) do
    if prototype and prototype.energy_source then
      prototype.energy_source.fuel_categories = {"chemical", "battery"}
      prototype.energy_source.burnt_inventory_size = 1
    end
  end
end

if mods["Krastorio2"] then
  for _, prototype in pairs(burner_hovercrafts) do
    if prototype and prototype.energy_source then
      prototype.energy_source.fuel_categories = {"vehicle-fuel"}
      prototype.energy_source.burnt_inventory_size = 1
    end
  end
end
