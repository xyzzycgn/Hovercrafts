-- control.lua
--local drifting_multipliers = { --unused?
--  ["hcraft-entity"] = 0.95, --2500  (weight)
--  ["mcraft-entity"] = 0.97, --10000 (weight)
--  ["ecraft-entity"] = 0.97, --7500  (weight)
--  ["lcraft-entity"] = 0.95, --1500  (weight)
--}
local isHovercraft = {
  ["hovercraft"] = true,
  ["electric-hovercraft"] = true,
  ["missile-hovercraft"] = true,
  ["laser-hovercraft"] = true
}
local function print(...)
	tbl = {...}
	local concat = ""
	for a,b in pairs(tbl) do
		concat = concat..b.."\t"
	end
	concat=concat:sub(1,-2)
	game.print(concat)
end


function distance(pos1,pos2)
  local x = (pos1.x-pos2.x)^2
  local y = (pos1.y-pos2.y)^2
  return (x+y)^0.5
end

-- aesthetic ripple
local function make_ripple(player)
  local vehicle = player.vehicle
  if (vehicle and isHovercraft[vehicle.name]) then
    local tile = vehicle.surface.get_tile(vehicle.position)
    if tile.valid and storage.is_water_tile[tile.name] then
      local p = vehicle.position
      local surface = vehicle.surface
      local r = 2.5
      local area = {{p.x - r, p.y - r}, {p.x + r, p.y + r}}
      if surface.count_tiles_filtered{area = area, name = storage.water_tiles, limit = 25} >= 25
      then      -- only ripple if in large water patch
        surface.create_entity{name = "water-ripple" .. math.random(1, 4) .. "-smoke", position={p.x,p.y+.75}}
      end
    end
  end
end

-- aesthetic splash
local function make_splash(player)
  local vehicle = player.vehicle
  if (vehicle and isHovercraft[vehicle.name]) then
    local tile = vehicle.surface.get_tile(vehicle.position)
    if tile.valid and storage.is_water_tile[tile.name] then
      local speed = 1+math.min(9,math.floor(math.abs(vehicle.speed)*9))
      player.surface.create_entity{name = "water-splash-smoke-"..speed, position = {vehicle.position.x+0.2, vehicle.position.y+0.5}}
    end
  end
end


-- when moving about in a hovercraft
script.on_event(defines.events.on_player_changed_position, function(e)
  local player = game.get_player(e.player_index)
  if not storage.mods_installed.canal_builder then
    make_ripple(player)
    make_splash(player)
  end
end)

function projection(orientation, distance, position)
  if not position then position = {x=0,y=0} end
  local temp_x = math.sin((orientation+0)*2*math.pi)*distance
  local temp_y =  math.sin((orientation+0.75)*2*math.pi)*distance
  return{x = temp_x+position.x, y = temp_y+position.y}
end
function orientation_from_coords(coords)
  return (math.atan2(coords.x,coords.y)/math.pi/2-0.5)*-1
end

-- Now and then create smoke, ripple
local function tickHandler(e)
  local eTick = e.tick
  if eTick % 7==2 then
    for _, player in pairs(game.connected_players) do
      local vehicle = player.vehicle
      if player.character and vehicle then
        if isHovercraft[vehicle.name] then
          player.surface.create_trivial_smoke{name = "hover-smoke", position = player.position}
        end
      end
    end
  end
  if eTick % 120 == 4 then
    for _,player in pairs(game.connected_players) do
      if not storage.mods_installed.canal_builder then
        make_ripple(player)
      end
    end
  end

  if storage.settings["hovercraft-drifting"] ~= "off" then
    for unit_number, tbl in pairs(storage.hovercrafts) do
      if tbl.entity and tbl.entity.valid then
        local entity = tbl.entity
        local pos = entity.position
        local speed = entity.speed
        if settings.startup["hovercraft-drifting"].value == "new" then
		      if tbl.drift.x~=0 or tbl.drift.y~=0 or entity.get_driver() then
		        tbl.idle_ticks = 0

			      -- calculating virtual acceleration:
            local thrust_pct = entity.burner.heat/entity.burner.heat_capacity
			      if entity.burner.currently_burning then
				      thrust_pct = 1
			      end
            local mass = entity.prototype.weight
            local native_acceleration = entity.prototype.consumption * entity.prototype.effectivity
            local fuel_acceleration_mult = 1 --Note: fuel_speed_mult only affects trains
            if entity.burner.currently_burning then -- ".name" is the item prototype in 2.0 for some reason:
              fuel_acceleration_mult = entity.burner.currently_burning.name.fuel_acceleration_multiplier + entity.burner.currently_burning.name.fuel_acceleration_multiplier_quality_bonus * entity.burner.currently_burning.quality.level
            end
            local exoskeleton_mult = 1
            if entity.grid then
              for _, eq in pairs(entity.grid.equipment) do
                if eq.type == "movement-bonus-equipment" then
                  local charge = eq.energy / eq.max_energy
                  exoskeleton_mult = exoskeleton_mult + eq.movement_bonus * charge
                end
              end
            end

            -- since we're still moving, this spot is 98% safe:
            if math.abs(entity.speed) >0.001 then
              tbl.last_safe_pos = entity.position
              tbl.last_safe_orientation = entity.orientation
            end

            --vanilla speeds: (vanilla has slower acceleration)
            --solid fuel: 129
                  --rocket fuel: 158.7
            --nuclear fuel: 187
            --laser: 151.6 (3 exoskeletons: 209)
            --electric: 217 (3 exoskeletons: 300)
            if entity.speed == 0  and math.abs(tbl.last_speed) >0.001 then -- crashed/stopped:
              entity.teleport(tbl.last_safe_pos)
              entity.orientation = tbl.last_safe_orientation
              tbl.last_pos = tbl.last_safe_pos
              tbl.last_speed = 0
              tbl.drift = {x=0,y=0}
              if math.abs(tbl.last_speed) >0.01 then
                --game.print("crash")
              end
            elseif math.abs(entity.speed) >0.005 then --moving
			        -- preventing hovercraft from after-drifting too much with 1 km/h; calculating slowdown_x and slowdow_y for friction
              local slowdown_x = tbl.drift.x >=0 and 0.0005 or -0.0005
              local slowdown_y = tbl.drift.y >=0 and 0.0005 or -0.0005
              local x_y_factor = math.max(0.0001,math.abs(tbl.drift.x))/math.max(0.0001,math.abs(tbl.drift.y))
              if x_y_factor>1 then
                slowdown_y = slowdown_y/x_y_factor
              else
                slowdown_x = slowdown_x*x_y_factor
              end
              if math.abs(entity.speed) < 0.5 then
                slowdown_x = slowdown_x*(1-math.abs(entity.speed)/0.5)
                slowdown_y = slowdown_y*(1-math.abs(entity.speed)/0.5)
			        end

			        -- apply friction:
              if entity.get_driver() then
                tbl.drift.x = tbl.drift.x *0.995 -slowdown_x
                tbl.drift.y = tbl.drift.y *0.995 -slowdown_y
              else
                tbl.drift.x = tbl.drift.x *0.97 -slowdown_x
                tbl.drift.y = tbl.drift.y *0.97 -slowdown_y
              end

              -- apply thrust:
              local riding_state = entity.riding_state.acceleration
              if riding_state == defines.riding.acceleration.braking then
                if entity.speed>0 then
                  tbl.drift = projection(entity.orientation,-thrust_pct*native_acceleration*fuel_acceleration_mult*exoskeleton_mult/mass/((0.6+entity.speed)*700),tbl.drift)
                else
                  tbl.drift = projection(entity.orientation, thrust_pct*native_acceleration*fuel_acceleration_mult*exoskeleton_mult/mass/((0.6+entity.speed)*700),tbl.drift)
                end
              elseif riding_state == defines.riding.acceleration.accelerating then
                  tbl.drift = projection(entity.orientation, thrust_pct*native_acceleration*fuel_acceleration_mult*exoskeleton_mult/mass/((0.6+entity.speed)*700),tbl.drift)
              elseif riding_state == defines.riding.acceleration.reversing then
                  tbl.drift = projection(entity.orientation,-thrust_pct*native_acceleration*fuel_acceleration_mult*exoskeleton_mult/mass/((0.6+entity.speed)*700),tbl.drift)
              end

              -- collision with destructables:
              if entity.speed > 0 and entity.speed < tbl.last_speed then
              tbl.drift.x = tbl.drift.x * entity.speed / tbl.last_speed
              tbl.drift.y = tbl.drift.y * entity.speed / tbl.last_speed
              end

			        -- drift: (100% drift, zero vanilla motion)
              local new_pos = {x = tbl.last_pos.x+tbl.drift.x, y = tbl.last_pos.y+ tbl.drift.y}
              entity.teleport(new_pos)

			        -- calculating real speed from drift and setting it on the entity for collision damage:
              local drift_speed = (tbl.drift.x^2+tbl.drift.y^2)^0.5
              entity.speed = drift_speed

			        -- data
              tbl.last_speed = drift_speed
			        tbl.last_pos = new_pos
              tbl.last_orientation = entity.orientation
			      else --not moving
			      end
          else
            tbl.idle_ticks = 120
          end
		      tbl.position = tbl.entity.position
        else  --old drifting:
          if speed == 0 and (tbl.drift.x^2+tbl.drift.y^2)^0.5 <0.001 then
            tbl.idle_ticks = tbl.idle_ticks + 1
          else
            tbl.idle_ticks = 0
          end
          if tbl.idle_ticks < 120 then
            --local surroundings = #tbl.entity.surface.find_entities_filtered {area = {{pos.x-1, pos.y-1}, {pos.x+1, pos.y+1}}}
            --if speed ~=0 or surroundings == 1 then
            local drift_x = pos.x-tbl.position.x
            local drift_y = pos.y-tbl.position.y
            drift_x = drift_x*0.05+tbl.drift.x*0.95
            drift_y = drift_y*0.05+tbl.drift.y*0.95
            if (drift_x^2+drift_y^2)^0.5 >0.001 then
              local new_pos = {x = tbl.position.x+drift_x, y = tbl.position.y+drift_y}
              tbl.entity.teleport(-5,-5)
              local cliffsize = 2
              local cliffs = tbl.entity.surface.find_entities_filtered{ type = "cliff", area = {{new_pos.x-cliffsize, new_pos.y-cliffsize}, {new_pos.x+cliffsize, new_pos.y+cliffsize}} }
              local rocks = tbl.entity.surface.find_entities_filtered{ type = "simple-entity", area = {{new_pos.x-1, new_pos.y-1}, {new_pos.x+1, new_pos.y+1}} }
              if #cliffs > 0 or #rocks > 0 then
                local noncolliding = tbl.entity.surface.find_non_colliding_position("hovercraft-collision", new_pos, 0.1, 0.03)
                if noncolliding and distance(noncolliding,new_pos) < 0.04 then
                  tbl.entity.teleport(noncolliding)
                  tbl.idle_ticks = 120
                else
                  tbl.entity.teleport(5,5)
                  tbl.drift = {x=0,y=0}
                  tbl.idle_ticks = 120
                end
              else
                if tbl.entity.surface.can_place_entity{name = "hovercraft-collision", position = new_pos, direction = tbl.entity.orientation} then
                  tbl.entity.teleport(new_pos)
                else
                  tbl.entity.teleport(5,5)
                end
              end
              tbl.drift = {x = drift_x, y = drift_y}
            else
              tbl.drift = {x = 0, y = 0}
            end
          else
            tbl.drift = {x = 0, y = 0}
          end
          tbl.position = tbl.entity.position
          tbl.last_pos = tbl.position
          tbl.last_safe_pos = tbl.position
          tbl.last_safe_orientation = tbl.entity.orientation
		    end
      else
        storage.hovercrafts[unit_number] = nil
      end
    end
  end
end
script.on_event(defines.events.on_tick, tickHandler)


script.on_event(defines.events.on_entity_died, function(event)
  if isHovercraft[event.entity.name] then
    if storage.hovercrafts[event.entity.unit_number] and storage.hovercrafts[event.entity.unit_number].collision then
      storage.hovercrafts[event.entity.unit_number].collision.destroy()
    end
  end
end)

function max_range(pos1,pos2,range)
  local distance = distance(pos1,pos2)
  pos2.x = pos2.x-pos1.x
  pos2.y = pos2.y-pos1.y
  pos2.x = pos2.x*math.min(1,range/distance)
  pos2.y = pos2.y*math.min(1,range/distance)
  pos1.x = pos1.x+pos2.x
  pos1.y = pos1.y+pos2.y
  return pos1
end

local function update_storage_state()
  storage.settings = {}
  storage.settings["hovercraft-drifting"] = settings.startup["hovercraft-drifting"].value
  storage.mods_installed = {}
  storage.mods_installed.laser_tanks = script.active_mods["laser_tanks"] or script.active_mods["laser_tanks_updated"]

  -- check for other mods that make water effects
  storage.mods_installed.canal_builder = remote.interfaces["CanalBuilder"] and remote.interfaces["CanalBuilder"]["exists"]

  storage.is_water_tile = {}
  storage.water_tiles = {}
  for name, tile_prototype in pairs(prototypes.tile) do
    local layers = tile_prototype.collision_mask.layers
    if layers and layers["water_tile"] and not layers["lava_tile"] then
      storage.is_water_tile[name] = true
      table.insert(storage.water_tiles, name)
    end
  end
end
script.on_event(defines.events.on_runtime_mod_setting_changed, update_storage_state)

script.on_init(function()
  if remote.interfaces["electric-vehicles-lib"] and prototypes.equipment["ehvt-equipment"] then
    remote.call("electric-vehicles-lib", "register-transformer", {name = "ehvt-equipment"})
  end
  --[[if script.active_mods["electric-vehicles-lib-reborn"] or script.active_mods["laser_tanks"] and settings.startup["lasertanks-electric-engine"].value then
    remote.call("electric-vehicles-lib", "register-transformer", {name = "ehvt-equipment"})
  end]]--
  storage.vehicles={}
  storage.hovercrafts = {}
  storage.version = 11
  update_storage_state()
end)

script.on_configuration_changed(function()
  if remote.interfaces["electric-vehicles-lib"] and prototypes.equipment["ehvt-equipment"] then
    remote.call("electric-vehicles-lib", "register-transformer", {name = "ehvt-equipment"})
  end
  if not storage.version then
    --if script.active_mods["electric-vehicles-lib-reborn"] then
    --  remote.call("electric-vehicles-lib", "register-transformer", {name = "ehvt-equipment"})
    --end
    storage.vehicles = {}
    storage.hovercrafts = {}
    storage.version = 9
    for _, surface in pairs(game.surfaces) do
      local names = {}
      for name in pairs(isHovercraft) do
        table.insert(names,name)
      end
      entities = surface.find_entities_filtered{name = names}
      for _, entity in pairs(entities) do
        storage.hovercrafts[entity.unit_number]={entity = entity,drift={x=0,y=0}, position = entity.position,idle_ticks = 0}-- direction = 0, speed = 0}
      end
    end
  end
  if storage.version < 10 then
    for unit_number, tbl in pairs(storage.hovercrafts) do
      if tbl.entity and tbl.entity.valid then
        storage.hovercrafts[unit_number].last_speed = tbl.entity.speed
        storage.hovercrafts[unit_number].last_pos = tbl.entity.position
      else
        storage.hovercrafts[unit_number] = nil
      end
    end
    storage.version = 10
  end
  if storage.version < 11 then
    for unit_number, tbl in pairs(storage.hovercrafts) do
        storage.hovercrafts[unit_number].last_safe_pos = tbl.entity.position
        storage.hovercrafts[unit_number].last_safe_orientation = tbl.entity.orientation
    end
    storage.version = 11
  end
  update_storage_state()
end)

script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
  if event.entity.name == "laser-hovercraft" then
    table.insert(storage.vehicles,event.entity)
  end
  if isHovercraft[event.entity.name] then
    --collision.set_driver(event.entity.surface.create_entity{name = "character", position = event.entity.position})
    storage.hovercrafts[event.entity.unit_number] = {entity = event.entity, drift={x=0,y=0}, last_speed = 0, collision = collision, last_pos = event.entity.position, position = event.entity.position, idle_ticks = 0}-- direction = 0, speed = 0}
  end
end)


-------------------------------------------------------------
------------Laser tank script for lcraft's turret------------
-------------------------------------------------------------

TICKS_PER_UPDATE = 20 --*3 (per 3rd tick)
ENERGY_PER_CHARGE = 749998 -- wtf 500k is buggy?

function table_length(tbl)
  if tbl == nil then
    return 0
  else
    local count = 0
    for _ in pairs(tbl) do
      count = count + 1
    end
    return count
  end
end

script.on_nth_tick(3, function(event)
  if not storage.mods_installed.laser_tanks then return end
  local temp_count = table_length(game.connected_players )
  local i

  local player_count = math.floor((temp_count+(storage.tick_delayer or 0))/TICKS_PER_UPDATE)
  if not (player_count > 0) then
    storage.tick_delayer = (storage.tick_delayer or 0) + temp_count
  else
    storage.tick_delayer = 0

    if not storage.iterate_players then
      storage.iterate_players = next(game.connected_players, storage.iterate_players)
    elseif not game.connected_players [storage.iterate_players] then
      storage.iterate_players = nil
    end
    i = 0
    --maxruns = math.min(1,player_count) --max 20/s
    while i< player_count and storage.iterate_players do
      if game.connected_players[storage.iterate_players].character and game.connected_players[storage.iterate_players].controller_type == defines.controllers.character then
        local playerid = storage.iterate_players
        local techlevel = 0
        if game.connected_players[playerid].force.technologies["laser-rifle-1"].researched then
          techlevel = 1
          if game.connected_players[playerid].force.technologies["laser-rifle-2"].researched then
            techlevel = 2
            if game.connected_players[playerid].force.technologies["laser-rifle-3"].researched then
              techlevel = 3
            end
          end
          local stack = game.connected_players[playerid].get_inventory(defines.inventory.character_main).find_item_stack("lasertanks-ammo-"..techlevel)
          if stack then
            stack.clear()
          end
          stack = game.connected_players[playerid].get_inventory(defines.inventory.character_main).find_item_stack("lasertanks-cannon-ammo-"..techlevel)
          if stack then
            stack.clear()
          end

          stack = game.connected_players[playerid].get_inventory(defines.inventory.character_ammo).find_item_stack("lasertanks-ammo-"..techlevel)
          if stack then
            stack.clear()
          end

          stack = game.connected_players[playerid].get_inventory(defines.inventory.character_ammo).find_item_stack("lasertanks-cannon-ammo-"..techlevel)
          if stack then
            stack.clear()
          end
        end
      end
      storage.iterate_players = next(game.connected_players, storage.iterate_players)  --iterating...
      if not storage.iterate_players then
        storage.iterate_players = next(game.connected_players, storage.iterate_players)
      end
      i=i+1
    end
  end

  temp_count = table_length(storage.vehicles)
  local vehicle_count = math.floor((temp_count+(storage.tick_delayer_veh or 0))/TICKS_PER_UPDATE)
  if not (vehicle_count > 0) then
    storage.tick_delayer_veh = (storage.tick_delayer_veh or 0) + temp_count
  else
    storage.tick_delayer_veh = 0

    if not storage.iterate_vehicles then
      storage.iterate_vehicles = next(storage.vehicles, storage.iterate_vehicles)
    elseif not storage.vehicles [storage.iterate_vehicles] then
      storage.iterate_vehicles = nil
    end
    i = 0
    --maxruns = math.min(1,vehicle_count) --max 20/s
    while i< vehicle_count and storage.iterate_vehicles do
      if not storage.vehicles[storage.iterate_vehicles].valid then
        storage.vehicles[storage.iterate_vehicles] = nil
        --game.players[1].print("invalid")
      else
        local vehicle = storage.vehicles[storage.iterate_vehicles]
        local techlevel = 0
        if vehicle.force.technologies["laser-rifle-1"].researched then
          techlevel = 1
          if vehicle.force.technologies["laser-rifle-2"].researched then
            techlevel = 2
            if vehicle.force.technologies["laser-rifle-3"].researched then
              techlevel = 3
            end
          end
          local stack = vehicle.get_inventory(defines.inventory.car_trunk).find_item_stack("lasertanks-ammo-"..techlevel)
          if stack then
            stack.clear()
          end
          stack = vehicle.get_inventory(defines.inventory.car_trunk).find_item_stack("lasertanks-cannon-ammo-"..techlevel)
          if stack then
            stack.clear()
          end
          local gun_index = 2
          if vehicle.name == "laser-hovercraft" then
            gun_index = 1
          end
          local ammo = vehicle.get_inventory(defines.inventory.car_ammo)[gun_index]
          if not ammo.valid_for_read then
            ammo = 0
          else
            if ammo.name ~= "lasertanks-ammo-"..techlevel then
              ammo.set_stack{name = "lasertanks-ammo-"..techlevel, count = 1,ammo=ammo.ammo}
            end
            ammo = ammo.ammo
          end
          local cannon_ammo = 10
          if vehicle.name == "lasertank" then
            cannon_ammo = vehicle.get_inventory(defines.inventory.car_ammo)[1]
            if not cannon_ammo.valid_for_read then
              cannon_ammo = 0
            else
              if cannon_ammo.name ~= "lasertanks-cannon-ammo-"..techlevel then
                cannon_ammo.set_stack{name = "lasertanks-cannon-ammo-"..techlevel, count = 1,ammo=cannon_ammo.ammo}
              end
              cannon_ammo = cannon_ammo.ammo
            end
          end
          if ammo <50 or cannon_ammo < 10 then
            local energy = 0
            local modules = 0
            for _, eq in pairs(vehicle.grid.equipment) do
              if eq.name == "lcraft-charger" or eq.name == "laserrifle-charger" then
                energy = energy+eq.energy
                modules = modules+1
                --game.connected_players [playerid].print(eq.energy)
              end
            end
            local inserted = 0
            if ammo < cannon_ammo*5 then
              if energy >= ENERGY_PER_CHARGE/(2.5-techlevel*0.5) then
                inserted = math.min(50-ammo,math.floor(energy/(ENERGY_PER_CHARGE/(2.5-techlevel*0.5))))
                if ammo == 0 then
                  vehicle.get_inventory(defines.inventory.car_ammo)[gun_index].set_stack{name = "lasertanks-ammo-"..techlevel, count = 1,ammo=inserted}
                else
                  vehicle.get_inventory(defines.inventory.car_ammo)[gun_index].ammo = ammo+inserted
                end
              end
            else
              if energy >= ENERGY_PER_CHARGE*2/(2.5-techlevel*0.5) then
                inserted = math.min(10-cannon_ammo,math.floor(energy/(ENERGY_PER_CHARGE*2/(2.5-techlevel*0.5))))
                if cannon_ammo == 0 then
                  vehicle.get_inventory(defines.inventory.car_ammo)[1].set_stack{name = "lasertanks-ammo-"..techlevel, count = 1,ammo=inserted}
                else
                  vehicle.get_inventory(defines.inventory.car_ammo)[1].ammo = cannon_ammo+inserted
                end
                inserted = inserted * 2
              end
            end
            for _, eq in pairs(vehicle.grid.equipment) do
              if eq.name == "lcraft-charger" or eq.name == "laserrifle-charger" then
                eq.energy = eq.energy - inserted*(ENERGY_PER_CHARGE/(2.5-techlevel*0.5))/modules
              end
            end
          end
        end
      end
      storage.iterate_vehicles = next(storage.vehicles, storage.iterate_vehicles)  --iterating...
      if not storage.iterate_vehicles then
        storage.iterate_vehicles = next(storage.vehicles, storage.iterate_vehicles)
      end
      i=i+1
    end
  end
end)
