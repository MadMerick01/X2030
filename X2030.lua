-- X2030
-- Prototype 0.5
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
local REQUIRED_AIRCRAFT_ICAO = "SF50"
local REQUIRED_AIRCRAFT_NAME = "Cirrus Vision SF50"
local CAMPAIGN_SAVE_VERSION = 1
local CAMPAIGN_PREFERENCES_DIRECTORY =
    SYSTEM_DIRECTORY
    .. "Output"
    .. DIRECTORY_SEPARATOR
    .. "preferences"
    .. DIRECTORY_SEPARATOR
local CAMPAIGN_SAVE_PATH =
    CAMPAIGN_PREFERENCES_DIRECTORY .. "X2030_Campaign.txt"
-- Existing campaigns used this filename before the main script was renamed.
-- It remains readable so upgrading does not discard a player's progress.
local LEGACY_CAMPAIGN_SAVE_PATH =
    CAMPAIGN_PREFERENCES_DIRECTORY .. "Xplane_Out_Of_Fuel_Campaign.txt"

------------------------------------------------------------
-- GAME SETTINGS
------------------------------------------------------------

local INITIAL_CAMPAIGN_FUEL_KG = 40
local MAX_RECENT_AIRPORT_FUEL_RECORDS = 10
local POUNDS_PER_KILOGRAM = 2.2046226218

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

-- X-Plane exposes the aircraft ICAO designator entered by its author. The
-- bundled Cirrus Vision Jet uses SF50, giving the campaign a stable check that
-- does not depend on a localised UI name or installation path.
dataref(
    "xoof_aircraft_icao",
    "sim/aircraft/view/acf_ICAO",
    "readonly"
)

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

-- X-Plane publishes the configured aircraft fuel capacity in pounds.
dataref(
    "xoof_aircraft_fuel_capacity_lb",
    "sim/aircraft/weight/acf_m_fuel_tot",
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
local airport_fuel_records = {}
local airport_fuel_access_counter = 0
-- Airport identifiers confirmed as land airports. Each entry also carries
-- the longest conventional runway found in apt.dat so recommendation data
-- remains available without another file scan.
local valid_land_airports = {}
local airport_database_loaded = false

local status_message =
    "Initialising airport detection..."
local last_saved_fuel_signature = nil
local last_fuel_transfer = nil

------------------------------------------------------------
-- GENERAL UTILITY FUNCTIONS
------------------------------------------------------------

local function set_status(message)
    status_message = message

    logMsg(
        "[X2030] " .. message
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
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function number_or_zero(value)
    if is_number(value) then
        return value
    end

    return 0
end

local function safe_number(value, fallback)
    local converted = tonumber(value)

    if converted == nil
        or converted ~= converted
        or converted == math.huge
        or converted == -math.huge then

        return fallback
    end

    return converted
end

local function clamp(value, minimum, maximum)
    local safe_value = safe_number(value, minimum)
    return math.max(minimum, math.min(maximum, safe_value))
end

local function is_required_campaign_aircraft_loaded()
    if type(xoof_aircraft_icao) ~= "string" then
        return false
    end

    local normalised_aircraft_icao = string.upper(
        string.match(xoof_aircraft_icao, "^%s*(.-)%s*$") or ""
    )

    return normalised_aircraft_icao == REQUIRED_AIRCRAFT_ICAO
end

local function aircraft_requirement_message()
    return "Load the "
        .. REQUIRED_AIRCRAFT_NAME
        .. " to continue the campaign."
end

local function is_valid_airport_identifier(value)
    return type(value) == "string"
        and string.match(value, "^[A-Z0-9][A-Z0-9]+$") ~= nil
        and #value >= 3
        and #value <= 8
end

------------------------------------------------------------
-- RECENT AIRPORT FUEL MEMORY
------------------------------------------------------------

local function get_airport_fuel_record(airport_icao)
    if not is_valid_airport_identifier(airport_icao) then
        return nil
    end

    return airport_fuel_records[airport_icao]
end

local function touch_airport_fuel_record(airport_icao)
    local record = get_airport_fuel_record(airport_icao)
    if record == nil then
        return nil
    end

    airport_fuel_access_counter = airport_fuel_access_counter + 1
    record.last_access = airport_fuel_access_counter
    return record
end

local function build_protected_airport_set()
    local protected_icaos = {}

    if is_valid_airport_identifier(departure_airport) then
        protected_icaos[departure_airport] = true
    end

    for index = 1, 3 do
        local suggestion = suggested_airports[index]
        if suggestion ~= nil
            and is_valid_airport_identifier(suggestion.icao) then
            protected_icaos[suggestion.icao] = true
        end
    end

    return protected_icaos
end


local function remove_oldest_airport_fuel_record(protected_icaos)
    protected_icaos = type(protected_icaos) == "table"
        and protected_icaos or {}

    local oldest_icao = nil
    local oldest_access = math.huge

    local function consider_record(icao, record, allow_protected)
        local is_current = icao == departure_airport
        if is_current or (not allow_protected and protected_icaos[icao]) then
            return
        end

        local access = safe_number(record.last_access, -1)
        if access < oldest_access then
            oldest_icao = icao
            oldest_access = access
        end
    end

    for icao, record in pairs(airport_fuel_records) do
        consider_record(icao, record, false)
    end

    -- If suggestions occupy every eligible slot, preserve the current airport
    -- but permit the oldest suggestion to be forgotten.
    if oldest_icao == nil then
        for icao, record in pairs(airport_fuel_records) do
            consider_record(icao, record, true)
        end
    end

    if oldest_icao ~= nil then
        airport_fuel_records[oldest_icao] = nil
        logMsg("[X2030 FUEL] Removed old record " .. oldest_icao)
        return true
    end

    return false
end

local function classify_airport_by_runway(runway_length_m)
    local runway = safe_number(runway_length_m, nil)

    if runway == nil or runway <= 0 then
        return "UNKNOWN", 55, 150, 0.25, 0.05
    elseif runway < 700 then
        return "TINY", 180, 250, 0.10, 0.10
    elseif runway < 1000 then
        return "SMALL", 140, 220, 0.15, 0.10
    elseif runway < 1500 then
        return "REGIONAL", 90, 175, 0.25, 0.05
    elseif runway < 2200 then
        return "LARGE REGIONAL", 40, 120, 0.45, 0.02
    end

    return "MAJOR", 0, 55, 0.70, 0
end


local function generate_initial_airport_fuel(airport_icao, runway_length_m)
    local size_class, normal_minimum, normal_maximum,
        depleted_chance, high_reserve_chance =
        classify_airport_by_runway(runway_length_m)

    local fuel_kg
    if math.random() < depleted_chance then
        fuel_kg = 0
    elseif math.random() < high_reserve_chance then
        if size_class == "TINY" then
            fuel_kg = math.random(220, 280)
        else
            fuel_kg = math.random(180, 250)
        end
    else
        fuel_kg = math.random(normal_minimum, normal_maximum)
    end

    return fuel_kg, size_class
end

local function get_or_create_airport_fuel(airport_icao, runway_length_m)
    if not is_valid_airport_identifier(airport_icao) then
        logMsg("[X2030 FUEL] Invalid airport identifier; fuel unavailable")
        return nil
    end

    local existing = get_airport_fuel_record(airport_icao)
    if existing ~= nil then
        local stored_fuel = safe_number(existing.fuel_kg, nil)
        if stored_fuel == nil or stored_fuel < 0 then
            logMsg("[X2030 FUEL] Invalid stored fuel for "
                .. airport_icao .. "; using 0 kg")
            stored_fuel = 0
        end

        local initial_fuel = safe_number(
            existing.initial_fuel_kg, stored_fuel)
        initial_fuel = math.max(stored_fuel, initial_fuel, 0)
        existing.initial_fuel_kg = initial_fuel
        existing.fuel_kg = clamp(stored_fuel, 0, initial_fuel)
        touch_airport_fuel_record(airport_icao)
        return existing
    end

    local record_count = 0
    for _ in pairs(airport_fuel_records) do
        record_count = record_count + 1
    end

    while record_count >= MAX_RECENT_AIRPORT_FUEL_RECORDS do
        if not remove_oldest_airport_fuel_record(
            build_protected_airport_set()) then
            return nil
        end
        record_count = record_count - 1
    end

    local fuel_kg, size_class = generate_initial_airport_fuel(
        airport_icao, runway_length_m)
    airport_fuel_access_counter = airport_fuel_access_counter + 1

    local record = {
        icao = airport_icao,
        fuel_kg = fuel_kg,
        initial_fuel_kg = fuel_kg,
        runway_length_m = safe_number(runway_length_m, nil),
        size_class = size_class,
        last_access = airport_fuel_access_counter
    }
    airport_fuel_records[airport_icao] = record

    local runway_text = record.runway_length_m == nil and "unknown"
        or string.format("%.0f", record.runway_length_m)
    logMsg(string.format(
        "[X2030 FUEL] Initialised %s: %s, runway %s m, fuel %d kg",
        airport_icao, size_class, runway_text, fuel_kg))

    return record
end

------------------------------------------------------------
-- CAMPAIGN SAVE FILE
------------------------------------------------------------

-- The save file intentionally uses a small, readable key/value format. Bad or
-- incomplete values are rejected so an interrupted write cannot crash a
-- FlyWithLua callback or silently move campaign progress to another airport.
local function load_campaign_save()
    local loaded_save_path = CAMPAIGN_SAVE_PATH
    local save_file = io.open(loaded_save_path, "r")

    if save_file == nil then
        loaded_save_path = LEGACY_CAMPAIGN_SAVE_PATH
        save_file = io.open(loaded_save_path, "r")
    end

    if save_file == nil then
        return nil, "missing", CAMPAIGN_SAVE_PATH
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

        return nil, "invalid", loaded_save_path
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

            return nil, "invalid", loaded_save_path
        end

        saved_fuel_tanks[tank] = saved_fuel
    end

    return {
        current_airport = saved_values.current_airport,
        fuel_tanks = saved_fuel_tanks
    }, nil, loaded_save_path
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
            "[X2030] Could not write campaign save: "
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
            "[X2030] Could not finalise campaign save: "
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
            "[X2030] apt.dat not found at: "
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
        "[X2030] Loaded "
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

    -- Only the final three candidates enter recent-airport memory. Creating
    -- records during the full nav-aid scan would evict useful airports before
    -- the player ever saw them.
    for index = 1, #suggested_airports do
        local airport = suggested_airports[index]
        local record = get_or_create_airport_fuel(
            airport.icao, airport.runway_length_metres)
        airport.available_fuel = record ~= nil
            and safe_number(record.fuel_kg, 0) or 0
        airport.size_class = record ~= nil
            and record.size_class or "UNKNOWN"
    end

    logMsg(
        "[X2030] "
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

local function get_aircraft_remaining_fuel_capacity_kg()
    local capacity_lb = safe_number(xoof_aircraft_fuel_capacity_lb, nil)
    local current_fuel = math.max(0, safe_number(get_total_fuel(), 0))

    if capacity_lb == nil or capacity_lb <= 0 then
        logMsg("[X2030 FUEL] Aircraft fuel capacity unavailable")
        return nil
    end

    local capacity_kg = capacity_lb / POUNDS_PER_KILOGRAM
    return math.max(0, capacity_kg - current_fuel), capacity_kg
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

local function transfer_airport_fuel_to_aircraft(airport_icao)
    local record = get_or_create_airport_fuel(
        airport_icao, get_longest_runway_metres(airport_icao))
    if record == nil then
        return nil
    end

    touch_airport_fuel_record(airport_icao)
    local airport_fuel_before = math.max(0,
        safe_number(record.fuel_kg, 0))
    local remaining_capacity = get_aircraft_remaining_fuel_capacity_kg()

    if remaining_capacity == nil then
        return nil
    end

    local transferred = clamp(
        math.min(airport_fuel_before, remaining_capacity),
        0, remaining_capacity)

    if transferred > 0 and not add_balanced_fuel(transferred) then
        return nil
    end

    record.fuel_kg = math.max(0, airport_fuel_before - transferred)
    touch_airport_fuel_record(airport_icao)

    if transferred > 0 then
        logMsg(string.format("[X2030 FUEL] Transferred %.0f kg from %s",
            transferred, airport_icao))
        logMsg(string.format("[X2030 FUEL] %s remaining fuel: %.0f kg",
            airport_icao, record.fuel_kg))
    elseif airport_fuel_before <= 0 then
        logMsg("[X2030 FUEL] No fuel available at " .. airport_icao)
    end

    return {
        icao = airport_icao,
        depot_before_kg = airport_fuel_before,
        transferred_kg = transferred,
        depot_remaining_kg = record.fuel_kg,
        aircraft_total_kg = get_total_fuel(),
        aircraft_full = remaining_capacity <= transferred + 0.01
    }
end

-- A new campaign begins with an exact, deliberately scarce fuel load. Clear
-- every simulator tank first so fuel configured in X-Plane cannot carry into
-- the campaign, then balance the starting load across the SF50's two tanks.
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
    campaign_started = false
    departure_airport = nil

    -- Never initialise or restore campaign fuel in another aircraft. This also
    -- leaves the save untouched until the player reloads the required SF50.
    if not is_required_campaign_aircraft_loaded() then
        suggested_airports = {}
        set_status(aircraft_requirement_message())
        return
    end

    update_nearest_airport()

    local saved_campaign, save_error, loaded_save_path =
        load_campaign_save()

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
            "[X2030] Invalid campaign save: "
            .. loaded_save_path
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
        get_or_create_airport_fuel(
            departure_airport,
            get_longest_runway_metres(departure_airport)
        )

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
    set_initial_campaign_fuel()
    get_or_create_airport_fuel(
        departure_airport,
        get_longest_runway_metres(departure_airport)
    )

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
    -- Aircraft changes normally reload FlyWithLua scripts, but retain this guard
    -- so a mid-session change can never save fuel or advance the SF50 campaign.
    if not is_required_campaign_aircraft_loaded() then
        suggested_airports = {}
        return
    end

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

        touch_airport_fuel_record(nearest_airport)

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

    local transfer_result =
        transfer_airport_fuel_to_aircraft(nearest_airport)

    if transfer_result == nil then
        set_status(
            "Airport depot or aircraft capacity unavailable. No fuel delivered."
        )

        return
    end

    last_fuel_transfer = transfer_result

    local arrival_airport =
        nearest_airport

    departure_airport =
        arrival_airport

    if save_campaign_progress() then
        if transfer_result.depot_before_kg <= 0 then
            set_status("Arrived " .. arrival_airport
                .. ". DEPOT DEPLETED. NO TRANSFER AVAILABLE.")
        elseif transfer_result.transferred_kg <= 0 then
            set_status("Arrived " .. arrival_airport
                .. ". Aircraft tanks full. Depot unchanged.")
        else
            set_status(string.format(
                "Arrived %s. Transferred %.0f kg; depot %.0f kg. Progress saved.",
                arrival_airport, transfer_result.transferred_kg,
                transfer_result.depot_remaining_kg))
        end
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

    if last_fuel_transfer ~= nil then
        local depot_state = last_fuel_transfer.depot_remaining_kg <= 0
            and "DEPOT DEPLETED"
            or string.format("DEPOT REMAINING %.0f KG",
                last_fuel_transfer.depot_remaining_kg)
        local tank_state = last_fuel_transfer.aircraft_full
            and "AIRCRAFT TANKS FULL"
            or string.format("AIRCRAFT TOTAL %.0f KG",
                last_fuel_transfer.aircraft_total_kg)

        draw_string_Helvetica_12(
            430,
            starting_y - 125,
            string.format(
                "DEPOT VERIFIED %.0f KG | TRANSFERRED %.0f KG | %s | %s",
                last_fuel_transfer.depot_before_kg,
                last_fuel_transfer.transferred_kg,
                depot_state,
                tank_state
            )
        )
    end

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
        is_required_campaign_aircraft_loaded()
            and status_message
            or aircraft_requirement_message()
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

            local reserve_description = ""
            if airport.size_class == "MAJOR"
                and number_or_zero(airport.available_fuel) < 55 then
                reserve_description = " | LONG RUNWAY / LOW RESERVE"
            elseif airport.size_class == "TINY"
                and number_or_zero(airport.available_fuel) >= 180 then
                reserve_description = " | SHORT RUNWAY / HIGH RESERVE"
            end

            local depot_fuel = math.max(0,
                number_or_zero(airport.available_fuel))
            if depot_fuel == 0 then
                set_display_color({ 0.95, 0.25, 0.20, 1.00 })
            elseif depot_fuel < 120 then
                set_display_color({ 1.00, 0.70, 0.18, 1.00 })
            elseif depot_fuel < 180 then
                set_display_color({ 0.35, 0.90, 0.45, 1.00 })
            else
                set_display_color(DISPLAY_ACCENT_COLOR)
            end

            draw_string_Helvetica_12(
                40,
                line_y,
                string.format(
                    "%d. %s | %.0f NM | "
                    .. "HDG %03.0f | "
                    .. "EST %.0f KG | "
                    .. "%s | DEPOT %.0f KG | %s%s",
                    index,
                    airport.icao,
                    number_or_zero(airport.distance_nm),
                    number_or_zero(airport.heading),
                    number_or_zero(airport.required_fuel),
                    runway_length_text,
                    depot_fuel,
                    affordability,
                    reserve_description
                )
            )
            set_display_color(DISPLAY_TEXT_COLOR)
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
    if is_required_campaign_aircraft_loaded() then
        save_campaign_progress()
    end
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
    "[X2030] "
    .. "Prototype 0.5 dynamic airport fuel system loaded."
)
