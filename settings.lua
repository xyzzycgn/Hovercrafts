-- settings.lua

local grid_dimensions = {
  "4x4",
  "4x6",
  "6x2",
  "6x6",
  "6x8",
  "8x2",
  "8x4",
  "8x8",
  "10x2",
  "10x4",
  "10x6",
  "10x8",
  "10x10",
}

data:extend({
  {
    type = "string-setting",
    name = "hovercraft-drifting",
    setting_type = "startup",
	  allowed_values = {"off", "old", "new"},
    default_value = "new",
	  order = "a",
  },
  {
    type = "bool-setting",
    name = "enable-electric-hovercraft",
    setting_type = "startup",
    default_value = true,
    order = "b",
  },
  {
    type = "bool-setting",
    name = "enable-missile-hovercraft",
    setting_type = "startup",
    default_value = true,
    order = "c",
  },
  {
    type = "bool-setting",
    name = "enable-laser-hovercraft",
    setting_type = "startup",
    default_value = true,
    order = "d",
  },
  {
    type = "string-setting",
    name = "hovercraft-grid-size",
    setting_type = "startup",
    default_value = "4x6",
    allowed_values = grid_dimensions,
    order = "f",
  },
  {
    type = "string-setting",
    name = "missile-hovercraft-grid-size",
    setting_type = "startup",
    default_value = "6x6",
    allowed_values = grid_dimensions,
    order = "g",
  },
})