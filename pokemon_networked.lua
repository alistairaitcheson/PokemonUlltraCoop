-- https://datacrystal.romhacking.net/wiki/Pok%C3%A9mon_Red/Blue:RAM_map#Misc.

-- there needs to be some kind of timestamping
-- if there are multiple copies of the same data area, only use the one with the latest timestamp

console.clear();

DEBUG_MODE = true

DATA_AREAS_LOC = { -- INCLUSIVE ARRAYS
    {0x1009, 0x1030, "battle"}, -- in-battle pokemon data
    {0x1163, 0x116A, "pokemon"}, -- pokemon party list
    {0x116B, 0x1196, "pokemon"}, -- pokemon 1
    {0x1197, 0x11C2, "pokemon"}, -- pokemon 2
    {0x11C3, 0x11EE, "pokemon"}, -- pokemon 3
    {0x11EF, 0x121A, "pokemon"}, -- pokemon 4
    {0x121B, 0x1246, "pokemon"}, -- pokemon 5
    {0x1247, 0x1272, "pokemon"}, -- pokemon 6
    {0x1273, 0x12B4, "pokemon"}, -- trainer name per pokemon
    {0x12B5, 0x12F6, "pokemon"}, -- nickname per pokemon
    {0x131D, 0x1346, "items"}, -- items (include?)
    {0x1347, 0x1349, "money"}, -- money (include?)
    {0x1356, 0x1356, "events"}, -- badges
    {0x135B, 0x135B, "music"}, -- music track (use this? needs something paired with it?)
    {0x153A, 0x159F, "items"}, -- stored items (use it?)
    {0x15A6, 0x185F, "events"}, -- event flags (and a bunch of other stuff in the middle? Should I limit this?)
}

math.randomseed(os.time())

function addToDebugLog(text)
	if DEBUG_MODE then
		console.log(text)
	end
end

function tablelength(T)
    -- addToDebugLog("tableLength: " .. tostring(T))
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

function file_exists(filePath)
	local f = io.open(filePath, "rb")
	if f then f:close() end
	return f ~= nil
end

area_states = {}

for whichArea = 1, tablelength(DATA_AREAS_LOC) do 
    bounds = DATA_AREAS_LOC[whichArea]
    state = {}
    table.insert(area_states, state)

    for i = bounds[1], bounds[2], 1 do
        state[i] = memory.readbyte(i, "WRAM")
    end
end

function checkForLocalChanges()
    for whichArea = 1, tablelength(DATA_AREAS_LOC) do 
        bounds = DATA_AREAS_LOC[whichArea]
        has_changed = false

        for i = bounds[1], bounds[2], 1 do
            last_val = area_states[whichArea][i]
            now_val = memory.readbyte(i, "WRAM")
            if last_val ~= now_val then
                has_changed = true
                area_states[whichArea][i] = now_val
            end
        end

        if has_changed then
            -- send this state over the network!
            file_index = math.random(1, 100)
            file_path_to_write = "pokemon_network_data/write_" .. tostring(file_index) .. ".txt"
            attempts = 0
            while attempts < 100 and file_exists(file_path_to_write) do
                file_index = math.random(1, 100)
                file_path_to_write = "pokemon_network_data/write_" .. tostring(file_index) .. ".txt"
                attempts = attempts + 1
            end
            if attempts >= 100 then
                -- cannot send data SHOW AN ALERT!
                -- is the assistant switched on?
                addToDebugLog("Out of space to send! Is the assistant switched on?")
                return
            end

            output_text = "" .. tostring(whichArea)

            for i = bounds[1], bounds[2], 1 do
                output_text = output_text .. "\n" .. tostring(area_states[whichArea][i]) 
            end

            local write_file = io.open(file_path_to_write,"w")
            write_file:write(output_text)
            write_file:close()

            addToDebugLog("Wrote to output " .. file_path_to_write)
            -- addToDebugLog("Wrote data: " .. output_text)
        end
    end
end

function checkForNetworkChanges()
    -- if we detect a change remember to make sure area_states is edited, *then* memory is written!
    for i = 1, 100, 1 do
        file_path_to_read = "pokemon_network_data/read_" .. tostring(i) .. ".txt"
        if file_exists(file_path_to_read) then
            addToDebugLog("Reading from file at " .. file_path_to_read)
            local f = io.open(file_path_to_read, "r")
            index = -1
            which_data_area = -1
            for line in io.lines(file_path_to_read) do
                if index == -1 then 
                    which_data_area = tonumber(line)
                elseif which_data_area > 0 then
                    loc = DATA_AREAS_LOC[which_data_area][1] + index
                    val = tonumber(line)
                    memory.writebyte(loc, val, "WRAM")
                    area_states[which_data_area][loc] = val
                end
                index = index + 1
            end
            f:close()
            -- addToDebugLog("Removing file at " .. file_path_to_read)
            os.remove(file_path_to_read)
        end
    end
end

while true do
    checkForNetworkChanges()
    checkForLocalChanges()

    emu.frameadvance()
end
