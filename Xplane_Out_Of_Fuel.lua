-- Xplane Out Of Fuel
-- Prototype 0.4
-- Airport-to-airport fuel system and next-hop suggestions

local PLUGIN_NAME = "2030 - AI Apocalypse"
local MISSION_BRIEFING_LINE_ONE =
    "You must transport a Black Prompt key to EGLL that may save Humans from an"
local MISSION_BRIEFING_LINE_TWO =
    "escaped rouge AI that has a firm grip on all online systems. You must make it. Please..."
local CURRENT_MISSION_STATUS =
    "Current Status: Get enough fuel to cross the ditch to YSSY"

-- The black key journey always begins at Manapouri / Te Anau Airport.
-- NZMO is the ICAO identifier used by X-Plane; TEU is its IATA code.
local CAMPAIGN_START_AIRPORT_ICAO = "NZMO"
local CAMPAIGN_START_AIRPORT_NAME = "Manapouri / Te Anau"
local CAMPAIGN_SAVE_VERSION = 1
local CAMPAIGN_SAVE_PATH =
    SYSTEM_DIRECTORY
    .. "Output"
    .. DIRECTORY_SEPARATOR
    .. "preferences"
    .. DIRECTORY_SEPARATOR
    .. "Xplane_Out_Of_Fuel_Campaign.txt"

------------------------------------------------------------
-- GAME SETTINGS
------------------------------------------------------------

-- Depot allocations range from 20 kg to 160 kg. The midpoint (and therefore
-- the intended average across airports) is 90 kg.
local AVERAGE_AIRPORT_FUEL_KG = 90
local AIRPORT_FUEL_VARIATION_KG = 70
local INITIAL_CAMPAIGN_FUEL_KG = 40

local STOPPED_SPEED_MPS = 1.0
local MAX_AIRPORT_DISTANCE_KM = 5.0

-- Approximate flight-planning assumptions
local ESTIMATED_AVERAGE_SPEED_KT = 180
local ESTIMATED_FUEL_FLOW_KG_PER_MIN = 2.5
local DEPARTURE_FUEL_ALLOWANCE_KG = 8

-- Restrained mission-computer colours. The dark translucent panel keeps the
-- white text readable against bright clouds without obscuring the flight view.
local DISPLAY_PANEL_COLOR = { 0.03, 0.06, 0.09, 0.82 }
local DISPLAY_ACCENT_COLOR = { 0.10, 0.75, 0.90, 0.95 }
local DISPLAY_TEXT_COLOR = { 1.00, 1.00, 1.00, 1.00 }

------------------------------------------------------------
-- X-PLANE DATAREFS
------------------------------------------------------------

dataref(
    "xoof_on_ground",
    "sim/flightmodel/failures/onground_any",
    "readonly"
)

dataref(
    "xoof_groundspeed",
    "sim/flightmodel/position/groundspeed",
    "readonly"
)

dataref(
    "xoof_latitude",
    "sim/flightmodel/position/latitude",
    "readonly"
)

dataref(
    "xoof_longitude",
    "sim/flightmodel/position/longitude",
    "readonly"
)

xoof_engine_running = dataref_table(
    "sim/flightmodel/engine/ENGN_running"
)

xoof_fuel_tanks = dataref_table(
    "sim/flightmodel/weight/m_fuel"
)

------------------------------------------------------------
-- CAMPAIGN STATE
------------------------------------------------------------

local has_been_airborne = false
local current_landing_processed = false
local campaign_started = false

local departure_airport = nil
local nearest_airport = nil
local nearest_airport_name = nil
local nearest_airport_distance_km = nil

local suggested_airports = {}
local airport_fuel_allocations = {}
-- Airport identifiers confirmed as land airports. Each entry also carries
-- the longest conventional runway found in apt.dat so recommendation data
-- remains available without another file scan.
local valid_land_airports = {}
local airport_database_loaded = false

local status_message =
    "Initialising airport detection..."
local last_saved_fuel_signature = nil

------------------------------------------------------------
-- GENERAL UTILITY FUNCTIONS
------------------------------------------------------------

local function set_status(message)
    status_message = message

    logMsg(
        "[Xplane Out Of Fuel] " .. message
    )
end

local function degrees_to_radians(degrees)
    return degrees * math.pi / 180
end

local function radians_to_degrees(radians)
    return radians * 180 / math.pi
end

local function kilometres_to_nautical_miles(km)
    return km / 1.852
end

local function is_number(value)
    return type(value) == "number"
end

local function number_or_zero(value)
    if is_number(value) then
        return value
    end

    return 0
end

local function is_valid_airport_identifier(value)
    return type(value) == "string"
        and string.match(value, "^[A-Z0-9][A-Z0-9]+$") ~= nil
        and #value >= 3
        and #value <= 8
end

-- Produce a stable, airport-specific allocation rather than rolling a new
-- amount every time the suggestion list is refreshed. This guarantees that
-- the quantity advertised before departure is the quantity delivered after
-- landing, including when FlyWithLua reloads the script between those events.
local function get_airport_fuel_allocation(airport_icao)
    if not is_valid_airport_identifier(airport_icao) then
        return nil
    end

    if is_number(airport_fuel_allocations[airport_icao]) then
        return airport_fuel_allocations[airport_icao]
    end

    local minimum_fuel =
        AVERAGE_AIRPORT_FUEL_KG - AIRPORT_FUEL_VARIATION_KG
    local possible_amounts =
        (AIRPORT_FUEL_VARIATION_KG * 2) + 1
    local airport_hash = 0

    -- The simple rolling hash is deterministic in Lua 5.1 and distributes
    -- normal ICAO identifiers throughout the complete 20--160 kg range.
    for character_index = 1, #airport_icao do
        airport_hash =
            (
                airport_hash * 31
                + string.byte(airport_icao, character_index)
            ) % possible_amounts
    end

    local allocation = minimum_fuel + airport_hash
    airport_fuel_allocations[airport_icao] = allocation

    return allocation
end

------------------------------------------------------------
-- CAMPAIGN SAVE FILE
------------------------------------------------------------

-- The save file intentionally uses a small, readable key/value format. Bad or
-- incomplete values are rejected so an interrupted write cannot crash a
-- FlyWithLua callback or silently move campaign progress to another airport.
local function load_campaign_save()
    local save_file = io.open(CAMPAIGN_SAVE_PATH, "r")

    if save_file == nil then
        return nil, "missing"
    end

    local saved_values = {}

    for line in save_file:lines() do
        local key, value = string.match(line, "^([%w_]+)=(.*)$")

        if key ~= nil then
            saved_values[key] = value
        end
    end

    save_file:close()

    if tonumber(saved_values.version) ~= CAMPAIGN_SAVE_VERSION
        or saved_values.campaign_started ~= "1"
        or not is_valid_airport_identifier(
            saved_values.current_airport
        ) then

        return nil, "invalid"
    end

    local saved_fuel_tanks = {}

    for tank = 0, 8 do
        local saved_fuel = tonumber(
            saved_values["fuel_tank_" .. tostring(tank)]
        )

        if saved_fuel == nil
            or saved_fuel ~= saved_fuel
            or saved_fuel < 0
            or saved_fuel == math.huge then

            return nil, "invalid"
        end

        saved_fuel_tanks[tank] = saved_fuel
    end

    return {
        current_airport = saved_values.current_airport,
        fuel_tanks = saved_fuel_tanks
    }, nil
end

local function save_campaign_progress()
    if not campaign_started
        or not is_valid_airport_identifier(
            departure_airport
        ) then

        return false
    end

    local temporary_path = CAMPAIGN_SAVE_PATH .. ".tmp"
    local save_file = io.open(temporary_path, "w")

    if save_file == nil then
        logMsg(
            "[Xplane Out Of Fuel] Could not write campaign save: "
            .. temporary_path
        )

        return false
    end

    save_file:write(
        "version=", tostring(CAMPAIGN_SAVE_VERSION), "\n",
        "campaign_started=1\n",
        "current_airport=", departure_airport, "\n"
    )

    for tank = 0, 8 do
        save_file:write(
            "fuel_tank_", tostring(tank), "=",
            string.format("%.3f", number_or_zero(xoof_fuel_tanks[tank])),
            "\n"
        )
    end

    save_file:close()

    -- Rename only after the complete temporary file has been closed. Removing
    -- the old file first keeps replacement compatible with Windows builds.
    os.remove(CAMPAIGN_SAVE_PATH)

    local renamed, rename_error =
        os.rename(temporary_path, CAMPAIGN_SAVE_PATH)

    if not renamed then
        logMsg(
            "[Xplane Out Of Fuel] Could not finalise campaign save: "
            .. tostring(rename_error)
        )

        return false
    end


    local saved_tanks = {}
    for tank = 0, 8 do
        saved_tanks[#saved_tanks + 1] = string.format(
            "%.3f",
            number_or_zero(xoof_fuel_tanks[tank])
        )
    end

    last_saved_fuel_signature = table.concat(saved_tanks, ",")

    return true
end

-- Fuel changes continuously in flight, so arrival-only saves can restore an
-- obsolete quantity after X-Plane is closed. A compact signature prevents
-- unnecessary writes when do_often runs while the aircraft is parked.
local function save_fuel_if_changed()
    if not campaign_started then
        return
    end

    local current_tanks = {}

    for tank = 0, 8 do
        current_tanks[#current_tanks + 1] = string.format(
            "%.3f",
            number_or_zero(xoof_fuel_tanks[tank])
        )
    end

    if table.concat(current_tanks, ",") ~= last_saved_fuel_signature then
        save_campaign_progress()
    end
end

local function restore_saved_fuel(saved_fuel_tanks)
    if type(saved_fuel_tanks) ~= "table" then
        return
    end

    for tank = 0, 8 do
        local saved_fuel = saved_fuel_tanks[tank]

        if is_number(saved_fuel) and saved_fuel >= 0 then
            xoof_fuel_tanks[tank] = saved_fuel
        end
    end
end

------------------------------------------------------------
-- DISTANCE AND HEADING
------------------------------------------------------------

local function calculate_distance_km(
    lat1,
    lon1,
    lat2,
    lon2
)
    local earth_radius_km = 6371.0

    local latitude_difference =
        degrees_to_radians(lat2 - lat1)

    local longitude_difference =
        degrees_to_radians(lon2 - lon1)

    local first_latitude =
        degrees_to_radians(lat1)

    local second_latitude =
        degrees_to_radians(lat2)

    local a =
        math.sin(latitude_difference / 2) ^ 2
        +
        math.cos(first_latitude)
        *
        math.cos(second_latitude)
        *
        math.sin(longitude_difference / 2) ^ 2

    local c =
        2
        *
        math.atan2(
            math.sqrt(a),
            math.sqrt(1 - a)
        )

    return earth_radius_km * c
end

local function calculate_initial_heading(
    lat1,
    lon1,
    lat2,
    lon2
)
    local start_lat =
        degrees_to_radians(lat1)

    local destination_lat =
        degrees_to_radians(lat2)

    local longitude_difference =
        degrees_to_radians(lon2 - lon1)

    local y =
        math.sin(longitude_difference)
        *
        math.cos(destination_lat)

    local x =
        math.cos(start_lat)
        *
        math.sin(destination_lat)
        -
        math.sin(start_lat)
        *
        math.cos(destination_lat)
        *
        math.cos(longitude_difference)

    local heading =
        radians_to_degrees(math.atan2(y, x))

    heading = (heading + 360) % 360

    return heading
end

------------------------------------------------------------
-- APPROXIMATE FUEL ESTIMATE
------------------------------------------------------------

local function estimate_fuel_required(distance_nm)
    local estimated_minutes =
        (
            distance_nm
            /
            ESTIMATED_AVERAGE_SPEED_KT
        )
        *
        60

    local estimated_fuel =
        DEPARTURE_FUEL_ALLOWANCE_KG
        +
        (
            estimated_minutes
            *
            ESTIMATED_FUEL_FLOW_KG_PER_MIN
        )

    return estimated_fuel
end

------------------------------------------------------------
-- NEAREST CURRENT AIRPORT
------------------------------------------------------------

local function find_nearest_airport()
    local airport_reference = XPLMFindNavAid(
        nil,
        nil,
        xoof_latitude,
        xoof_longitude,
        nil,
        xplm_Nav_Airport
    )

    if airport_reference == nil
        or airport_reference < 0 then

        return nil, nil, nil
    end

    local airport_type
    local airport_latitude
    local airport_longitude
    local airport_height
    local airport_frequency
    local airport_heading
    local airport_icao
    local airport_name
    local airport_region

    airport_type,
    airport_latitude,
    airport_longitude,
    airport_height,
    airport_frequency,
    airport_heading,
    airport_icao,
    airport_name,
    airport_region =
        XPLMGetNavAidInfo(airport_reference)

    if airport_icao == nil
        or airport_icao == "" then

        return nil, nil, nil
    end

    local distance_km =
        calculate_distance_km(
            xoof_latitude,
            xoof_longitude,
            airport_latitude,
            airport_longitude
        )

    return airport_icao,
        airport_name,
        distance_km
end

local function update_nearest_airport()
    nearest_airport,
    nearest_airport_name,
    nearest_airport_distance_km =
        find_nearest_airport()
end

------------------------------------------------------------
-- LOAD VALID LAND AIRPORTS FROM X-PLANE
------------------------------------------------------------

local function split_words(line)
    local words = {}

    for word in string.gmatch(line, "%S+") do
        table.insert(words, word)
    end

    return words
end

local function load_valid_land_airports()
    valid_land_airports = {}
    airport_database_loaded = false

    local apt_dat_path =
        SYSTEM_DIRECTORY
        .. "Global Scenery"
        .. DIRECTORY_SEPARATOR
        .. "Global Airports"
        .. DIRECTORY_SEPARATOR
        .. "Earth nav data"
        .. DIRECTORY_SEPARATOR
        .. "apt.dat"

    local airport_file =
        io.open(apt_dat_path, "r")

    if airport_file == nil then
        set_status(
            "Could not open X-Plane airport database."
        )

        logMsg(
            "[Xplane Out Of Fuel] apt.dat not found at: "
            .. apt_dat_path
        )

        return false
    end

    local current_airport_icao = nil
    local current_airport_is_land = false
    local current_airport_has_runway = false
    local current_longest_runway_metres = nil

    local function save_current_airport()
        if current_airport_icao ~= nil
            and current_airport_is_land
            and current_airport_has_runway then

            valid_land_airports[current_airport_icao] = {
                longest_runway_metres =
                    current_longest_runway_metres
            }
        end
    end

    for line in airport_file:lines() do
        local fields = split_words(line)
        local row_code = tonumber(fields[1])

        -- A new airport facility begins.
        if row_code == 1
            or row_code == 16
            or row_code == 17 then

            save_current_airport()

            current_airport_icao = fields[5]
            current_airport_is_land =
                row_code == 1

            current_airport_has_runway = false
            current_longest_runway_metres = nil

        elseif row_code == 100
            and current_airport_is_land then

            -- Row 100 describes a conventional land runway.
            current_airport_has_runway = true

            -- apt.dat supplies the latitude and longitude of both runway
            -- ends. Incomplete or malformed coordinates are ignored rather
            -- than allowing airport data to interrupt plugin startup.
            local first_end_latitude = tonumber(fields[10])
            local first_end_longitude = tonumber(fields[11])
            local second_end_latitude = tonumber(fields[19])
            local second_end_longitude = tonumber(fields[20])

            if first_end_latitude ~= nil
                and first_end_longitude ~= nil
                and second_end_latitude ~= nil
                and second_end_longitude ~= nil then

                local runway_length_metres =
                    calculate_distance_km(
                        first_end_latitude,
                        first_end_longitude,
                        second_end_latitude,
                        second_end_longitude
                    ) * 1000

                if current_longest_runway_metres == nil
                    or runway_length_metres
                        > current_longest_runway_metres then

                    current_longest_runway_metres =
                        runway_length_metres
                end
            end
        end
    end

    -- Save the final airport in the file.
    save_current_airport()

    airport_file:close()

    airport_database_loaded = true

    local airport_count = 0

    for _ in pairs(valid_land_airports) do
        airport_count = airport_count + 1
    end

    logMsg(
        "[Xplane Out Of Fuel] Loaded "
        .. tostring(airport_count)
        .. " valid land airports."
    )

    return true
end

local function is_valid_destination_airport(icao)
    if icao == nil or icao == "" then
        return false
    end

    return valid_land_airports[icao] ~= nil
end

local function get_longest_runway_metres(icao)
    local airport_data = valid_land_airports[icao]

    if airport_data == nil
        or not is_number(
            airport_data.longest_runway_metres
        ) then

        return nil
    end

    return airport_data.longest_runway_metres
end

------------------------------------------------------------
-- NEXT-HOP AIRPORT SEARCH
------------------------------------------------------------

local function insert_airport_suggestion(candidate)
    table.insert(
        suggested_airports,
        candidate
    )

    table.sort(
        suggested_airports,
        function(first, second)
            return first.distance_nm
                < second.distance_nm
        end
    )

    while #suggested_airports > 3 do
        table.remove(
            suggested_airports,
            #suggested_airports
        )
    end
end

local function refresh_airport_suggestions()
    suggested_airports = {}

    local nav_reference =
        XPLMGetFirstNavAid()

    while nav_reference ~= nil
        and nav_reference >= 0 do

        local nav_type
        local airport_latitude
        local airport_longitude
        local airport_height
        local airport_frequency
        local airport_heading
        local airport_icao
        local airport_name
        local airport_region

        nav_type,
        airport_latitude,
        airport_longitude,
        airport_height,
        airport_frequency,
        airport_heading,
        airport_icao,
        airport_name,
        airport_region =
            XPLMGetNavAidInfo(nav_reference)

        if nav_type == xplm_Nav_Airport
            and airport_icao ~= nil
            and airport_icao ~= ""
            and airport_icao ~= departure_airport
            and is_valid_destination_airport(
                airport_icao
        ) then

            local distance_km =
                calculate_distance_km(
                    xoof_latitude,
                    xoof_longitude,
                    airport_latitude,
                    airport_longitude
                )

            local distance_nm =
                kilometres_to_nautical_miles(
                    distance_km
                )

            -- Prevent the airport at the aircraft's
            -- present position appearing as a next hop.
            if distance_nm > 1.0 then
                local heading =
                    calculate_initial_heading(
                        xoof_latitude,
                        xoof_longitude,
                        airport_latitude,
                        airport_longitude
                    )

                local required_fuel =
                    estimate_fuel_required(
                        distance_nm
                    )

                insert_airport_suggestion(
                    {
                        icao = airport_icao,
                        name = airport_name,
                        distance_nm = distance_nm,
                        heading = heading,
                        required_fuel = required_fuel,
                        runway_length_metres =
                            get_longest_runway_metres(
                                airport_icao
                            ),
                        available_fuel =
                            get_airport_fuel_allocation(
                                airport_icao
                            )
                    }
                )
            end
        end

        nav_reference =
            XPLMGetNextNavAid(
                nav_reference
            )
    end

    logMsg(
        "[Xplane Out Of Fuel] "
        .. tostring(#suggested_airports)
        .. " next-hop suggestions found."
    )
end

------------------------------------------------------------
-- FUEL FUNCTIONS
------------------------------------------------------------

local function get_total_fuel()
    local total_fuel = 0

    for tank = 0, 8 do
        total_fuel =
            total_fuel
            +
            number_or_zero(xoof_fuel_tanks[tank])
    end

    return total_fuel
end

local function add_balanced_fuel(fuel_amount_kg)
    if not is_number(fuel_amount_kg)
        or fuel_amount_kg < 0 then

        return false
    end

    local fuel_per_tank_kg = fuel_amount_kg / 2

    xoof_fuel_tanks[0] =
        number_or_zero(xoof_fuel_tanks[0])
        +
        fuel_per_tank_kg

    xoof_fuel_tanks[1] =
        number_or_zero(xoof_fuel_tanks[1])
        +
        fuel_per_tank_kg

    return true
end

-- A new campaign always begins with the same limited fuel supply, regardless
-- of the fuel quantity selected in X-Plane before the script was loaded.
local function set_initial_campaign_fuel()
    for tank = 0, 8 do
        xoof_fuel_tanks[tank] = 0
    end

    return add_balanced_fuel(INITIAL_CAMPAIGN_FUEL_KG)
end

------------------------------------------------------------
-- INITIAL AIRPORT
------------------------------------------------------------

local function initialise_departure_airport()
    update_nearest_airport()

    campaign_started = false
    departure_airport = nil

    local saved_campaign, save_error = load_campaign_save()

    if nearest_airport == nil then
        set_status(
            "Campaign unavailable. No airport could be identified."
        )

        return
    end

    if not is_number(nearest_airport_distance_km)
        or nearest_airport_distance_km
            > MAX_AIRPORT_DISTANCE_KM then

        set_status(
            "Campaign start unavailable. Position the aircraft at "
            .. CAMPAIGN_START_AIRPORT_ICAO
            .. "."
        )

        return
    end

    if save_error == "invalid" then
        set_status(
            "Campaign save is invalid. Check X-Plane Log.txt."
        )

        logMsg(
            "[Xplane Out Of Fuel] Invalid campaign save: "
            .. CAMPAIGN_SAVE_PATH
        )

        return
    end

    if saved_campaign ~= nil then
        if not is_valid_destination_airport(
            saved_campaign.current_airport
        ) then

            set_status(
                "Saved airport is unavailable in the airport database."
            )

            return
        end

        if nearest_airport ~= saved_campaign.current_airport then
            set_status(
                "Saved campaign is at "
                .. saved_campaign.current_airport
                .. ". Load the aircraft there to continue."
            )

            return
        end

        departure_airport = saved_campaign.current_airport
        campaign_started = true
        restore_saved_fuel(saved_campaign.fuel_tanks)

        set_status(
            "Campaign resumed at "
            .. departure_airport
            .. ". Select your next hop."
        )

        refresh_airport_suggestions()
        return
    end

    if nearest_airport ~= CAMPAIGN_START_AIRPORT_ICAO then
        set_status(
            "Campaign begins at "
            .. CAMPAIGN_START_AIRPORT_ICAO
            .. " ("
            .. CAMPAIGN_START_AIRPORT_NAME
            .. ")."
        )

        return
    end

    departure_airport =
        CAMPAIGN_START_AIRPORT_ICAO
    campaign_started = true

    if not set_initial_campaign_fuel() then
        campaign_started = false
        departure_airport = nil
        set_status("Campaign start fuel could not be loaded.")
        return
    end

    refresh_airport_suggestions()

    if save_campaign_progress() then
        set_status(
            "Starting airport: "
            .. departure_airport
            .. ". Select your next hop."
        )
    else
        set_status(
            "Campaign started at NZMO, but progress could not be saved."
        )
    end
end

------------------------------------------------------------
-- MAIN GAME LOGIC
------------------------------------------------------------

function xoof_update()
    -- Do not advance campaign state until a new NZMO start or a valid saved
    -- campaign at the aircraft's present airport has been established.
    if not campaign_started then
        return
    end

    -- Persist simulator or plugin fuel changes in every operating state.
    save_fuel_if_changed()

    local engine_is_running =
        xoof_engine_running[0] == 1

    if xoof_on_ground == 0 then
        if not has_been_airborne then
            has_been_airborne = true
            current_landing_processed =
                false
            -- Airport intelligence is intentionally ground-supplied. Remove
            -- the departure list rather than presenting stale airborne data.
            suggested_airports = {}

            if departure_airport ~= nil then
                set_status(
                    "Departed "
                    .. departure_airport
                    .. ". Reach another airport."
                )
            else
                set_status(
                    "Aircraft airborne. "
                    .. "Reach an airport."
                )
            end
        end

        return
    end

    if not has_been_airborne then
        return
    end

    if xoof_groundspeed
        >=
        STOPPED_SPEED_MPS then

        status_message =
            "Landed. Stop and shut down the engine."

        return
    end

    if engine_is_running then
        status_message =
            "Aircraft stopped. "
            .. "Shut down the engine."

        return
    end

    if current_landing_processed then
        return
    end

    current_landing_processed = true

    update_nearest_airport()

    if nearest_airport == nil then
        set_status(
            "No recognised airport nearby. "
            .. "No fuel delivered."
        )

        return
    end

    if not is_number(nearest_airport_distance_km)
        or nearest_airport_distance_km
            > MAX_AIRPORT_DISTANCE_KM then

        set_status(
            "Airport distance unavailable. No fuel delivered."
        )

        return
    end

    if nearest_airport
        ==
        departure_airport then

        local return_was_saved = save_campaign_progress()

        if return_was_saved then
            set_status(
                "Returned to "
                .. nearest_airport
                .. ". This airport has no new fuel."
            )
        else
            set_status(
                "Returned to "
                .. nearest_airport
                .. ". Campaign save failed."
            )
        end

        has_been_airborne = false

        refresh_airport_suggestions()

        return
    end

    local delivered_fuel_kg =
        get_airport_fuel_allocation(nearest_airport)

    if not add_balanced_fuel(delivered_fuel_kg) then
        set_status(
            "Airport fuel allocation unavailable. No fuel delivered."
        )

        return
    end

    local arrival_airport =
        nearest_airport

    departure_airport =
        arrival_airport

    if save_campaign_progress() then
        set_status(
            "Arrived "
            .. arrival_airport
            .. ". Fuel delivered: "
            .. tostring(delivered_fuel_kg)
            .. " kg. Progress saved."
        )
    else
        set_status(
            "Arrived "
            .. arrival_airport
            .. ". Fuel delivered, but campaign save failed."
        )
    end

    has_been_airborne = false

    refresh_airport_suggestions()
end


------------------------------------------------------------
-- DISPLAY
------------------------------------------------------------

local function set_display_color(color)
    graphics.set_color(
        color[1],
        color[2],
        color[3],
        color[4]
    )
end

local function draw_display_background(starting_y)
    local panel_left = 24
    local panel_right = 850
    local panel_bottom = starting_y - 260
    local panel_top = starting_y + 25

    set_display_color(DISPLAY_PANEL_COLOR)
    graphics.draw_rectangle(
        panel_left,
        panel_bottom,
        panel_right,
        panel_top
    )

    -- A narrow cyan edge identifies the campaign display without turning the
    -- restrained aviation interface into an arcade-style HUD.
    set_display_color(DISPLAY_ACCENT_COLOR)
    graphics.draw_rectangle(
        panel_left,
        panel_bottom,
        panel_left + 4,
        panel_top
    )

    -- FlyWithLua's string helpers use the active graphics colour, so restore
    -- white before any existing text is drawn.
    set_display_color(DISPLAY_TEXT_COLOR)
end

function xoof_draw()
    local starting_y =
        SCREEN_HIGHT - 60

    draw_display_background(starting_y)

    draw_string_Helvetica_18(
        40,
        starting_y,
        PLUGIN_NAME
    )

    draw_string_Helvetica_12(
        40,
        starting_y - 25,
        MISSION_BRIEFING_LINE_ONE
    )

    draw_string_Helvetica_12(
        40,
        starting_y - 45,
        MISSION_BRIEFING_LINE_TWO
    )

    draw_string_Helvetica_12(
        40,
        starting_y - 65,
        CURRENT_MISSION_STATUS
    )

    draw_string_Helvetica_12(
        40,
        starting_y - 85,
        status_message
    )

    draw_string_Helvetica_12(
        40,
        starting_y - 105,
        string.format(
            "Fuel: %.0f kg | "
            .. "Left: %.0f | Right: %.0f",
            get_total_fuel(),
            number_or_zero(xoof_fuel_tanks[0]),
            number_or_zero(xoof_fuel_tanks[1])
        )
    )

    if departure_airport ~= nil then
        draw_string_Helvetica_12(
            40,
            starting_y - 125,
            "Current airport: "
            .. departure_airport
        )
    end

    draw_string_Helvetica_18(
        40,
        starting_y - 155,
        "SUGGESTED NEXT HOPS"
    )

    for index = 1, 3 do
        local airport =
            suggested_airports[index]

        local line_y =
            starting_y
            -
            155
            -
            (index * 25)

        if airport ~= nil then
            local affordability
            local runway_length_text = "RWY UNKNOWN"

            if is_number(
                airport.runway_length_metres
            ) then

                runway_length_text = string.format(
                    "RWY %.0f M",
                    airport.runway_length_metres
                )
            end

            if not is_number(airport.required_fuel) then
                affordability = "UNKNOWN"
            elseif get_total_fuel()
                >=
                airport.required_fuel then

                affordability = "REACHABLE"
            else
                affordability = "LOW FUEL"
            end

            draw_string_Helvetica_12(
                40,
                line_y,
                string.format(
                    "%d. %s | %.0f NM | "
                    .. "HDG %03.0f | "
                    .. "EST %.0f KG | "
                    .. "%s | DEPOT %.0f KG | %s",
                    index,
                    airport.icao,
                    number_or_zero(airport.distance_nm),
                    number_or_zero(airport.heading),
                    number_or_zero(airport.required_fuel),
                    runway_length_text,
                    number_or_zero(airport.available_fuel),
                    affordability
                )
            )
        else
            draw_string_Helvetica_12(
                40,
                line_y,
                tostring(index)
                .. ". No airport found"
            )
        end
    end
end


function xoof_save_before_exit()
    save_campaign_progress()
end

------------------------------------------------------------
-- START SCRIPT
------------------------------------------------------------

do_often("xoof_update()")
do_every_draw("xoof_draw()")
do_on_exit("xoof_save_before_exit()")

if load_valid_land_airports() then
    initialise_departure_airport()
else
    set_status(
        "Airport database failed to load. "
        .. "Check X-Plane Log.txt."
    )
end

logMsg(
    "[Xplane Out Of Fuel] "
    .. "Prototype 0.4 ground information and fuel save loaded."
)
