-------------------------------------------------------------------------------
--[[Meltdown]]--
-------------------------------------------------------------------------------

--[[ A function that is called whenever an entity is removed for any reason ]]--
local function remove(event)
    local entity = event.entity
	if entity.type == "reactor" then
		local data = global.reactors[entity.unit_number]
		local temperature = data.temperature
		if temperature > 900 then
			entity.surface.create_entity{name = "atomic-rocket", position = entity.position, force = entity.force, target = entity, speed = 1000}
			entity.surface.pollute(entity.position, 1000000)
		end
		global.reactors[entity.unit_number] = nil
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

local function on_tick(event)
	local next = next --very slight perfomance improvment
	local tick = event.tick
	local reactors = global.reactors
	local data
	local index = global.index

	--check for existing data at index
	if index and reactors[index] then
		data = reactors[index]
	else
		index, data = next(reactors, index)
	end

	if not data then 
		-- [[ hapens when there are no reactors on the map. Disable update ]]--
		script.on_event(defines.events.on_tick, nil)
		return
	end

	local reactor = data.reactor

	if reactor.valid then -- if entity is valid, check it, otherwise remove the entry from the table
		local temperature = reactor.temperature
		data.temperature = temperature
		if temperature >= 1000 then
			local last_update = data.last_update or (tick - 1)
			reactor.damage(500 / 3600.0 * (tick - last_update), "neutral")
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
		global.reactors[entity.unit_number] = { reactor = entity, temperature = entity.temperature }
		script.on_event(defines.events.on_tick, on_tick)
	end
end

--[[ Setup event handlers ]]--

script.on_init(rebuild_data)
script.on_configuration_changed(rebuild_data)

local e=defines.events
local add_events = {e.on_built_entity, e.on_robot_built_entity}
local remove_events = {e.on_player_mined_entity, e.on_robot_pre_mined, e.on_entity_died}

script.on_event(add_events, built)
script.on_event(remove_events, remove)
