-------------------------------------------------------------------------------
--[[Meltdown]]--
-------------------------------------------------------------------------------

local pollution_damage_resistance_mult = 0
local pollution_damage_reduction = 10
local meltdown_explode = false
local prevent_mining = true
local meltdown_pollution = 1000000
local overheat_damage_per_tick = 0
local overheat_pollution_per_tick = 10 / 60.0
local overheat_fires_per_tick = 1. / 60

--[[ Is the reactor running? ]]--
local function is_reactor_running(reactor)
	return reactor.burner.remaining_burning_fuel > 0
end

--[[ A function that is called whenever an entity is removed for any reason ]]--
local function remove(event)
    local entity = event.entity
	if entity.type == "reactor" then
		local data = global.reactors[entity.unit_number]
		if is_reactor_running(entity) then
			if meltdown_explode then
				entity.surface.create_entity{name = "atomic-rocket", position = entity.position, force = entity.force, target = entity, speed = 1000}
			end
			if meltdown_pollution > 0 then
				entity.surface.pollute(entity.position, meltdown_pollution)
			end
		end
		global.reactors[entity.unit_number] = nil
	end
end

local function on_tick(event)
	local next = next --very slight perfomance improvment
	local tick = event.tick
	local reactors = global.reactors
	local data
	local index = global.index

	if pollution_damage_resistance_mult > 0 then
		for _, player in pairs(game.players) do
			local pollution = player.surface.get_pollution(player.position)
			local damage = pollution * pollution_damage_resistance_mult - pollution_damage_reduction
			if damage > 0 then
				if player.character then
					player.character.damage(damage, "neutral", "poison")
				end
			end
		end
	end

	--check for existing data at index
	if index and reactors[index] then
		data = reactors[index]
	else
		index, data = next(reactors, index)
	end

	if not data then 
		-- [[ hapens when there are no reactors on the map. Disable update ]]--
		return
	end

	local reactor = data.reactor

	if reactor.valid then -- if entity is valid, check it, otherwise remove the entry from the table
		if prevent_mining and is_reactor_running(reactor) then
			reactor.minable = false
		else
			reactor.minable = true
		end
		local temperature = reactor.temperature
		if temperature >= 1000 then
			local last_update = data.last_update or (tick - 1)
			local ticks = tick - last_update
			if overheat_damage_per_tick > 0 then
				reactor.damage(overheat_damage_per_tick * ticks, "neutral")
			end
			if reactor.valid and overheat_pollution_per_tick > 0 then
				reactor.surface.pollute(reactor.position, overheat_pollution_per_tick * ticks)
			end
			if overheat_fires_per_tick > 0 then
				local fires = (data.fires or 0) + overheat_fires_per_tick
				--[[ this should be a loop for correctness, but this ensures not spending too much time on spawning fires ]]--
				if fires >= 1 then
					local ang = 2*math.pi*math.random()
					local dist = 8*math.sqrt(math.random())
					local x = reactor.position.x + math.cos(ang) * dist
					local y = reactor.position.y + math.sin(ang) * dist
					reactor.surface.create_entity{name = "fire-flame", position = { x = x, y = y }, force = "neutral"}
					data.fires = fires - 1
				else
					data.fires = fires
				end
			end
		end
		data.last_update = tick
	else -- Reactor is gone
		reactors[index] = nil
	end
	global.index = next(reactors, index)
end

--[[ A function that is called whenever an entity is built (both by player and by robots) ]]--
local function built(event)
    local entity = event.created_entity
	if entity.type == "reactor" then
		global.reactors[entity.unit_number] = { reactor = entity }
	end
end

local function rebuild_data()
    --[[Setup the global reactors table This table contains the machine entity, the signal entity and the freeze variable]]--
    global.reactors = {}
    global.index = nil

    --[[Find all nuclear reactors on the map. Check each surface]]--
    for _, surface in pairs(game.surfaces) do
        --find-entities-filtered with no area argument scans for all entities in loaded chunks and should
        --be more effiecent then scanning through all chunks like in previous version

        --[[Find all assembling machines within the bounds, and pretend that they were just built]]--
        for _, reactor in pairs(surface.find_entities_filtered{type="reactor"}) do
            built({created_entity = reactor})
        end
    end
end

local function load_settings()
	pollution_damage_resistance_mult = (100-settings.global["meltdown-player-pollution-damage-resistance"].value)/100.0
	pollution_damage_reduction = settings.global["meltdown-player-pollution-damage-reduction"].value
	prevent_mining = settings.global["meltdown-prevent-mining"].value
	meltdown_explode = settings.global["meltdown-explode"].value
	meltdown_pollution = settings.global["meltdown-pollution"].value
	overheat_damage_per_tick = settings.global["meltdown-overheat-damage-per-second"].value / 60.0
	overheat_pollution_per_tick = settings.global["meltdown-overheat-pollution-per-second"].value / 60.0
	overheat_fires_per_tick = settings.global["meltdown-overheat-fires-per-second"].value / 60.0
end

load_settings()

--[[ Setup event handlers ]]--

script.on_init(rebuild_data)
script.on_configuration_changed(rebuild_data)
script.on_event(defines.events.on_runtime_mod_setting_changed, load_settings)
script.on_event(defines.events.on_tick, on_tick)

local e=defines.events
local add_events = {e.on_built_entity, e.on_robot_built_entity}
local remove_events = {e.on_player_mined_entity, e.on_robot_pre_mined, e.on_entity_died}

script.on_event(add_events, built)
script.on_event(remove_events, remove)
