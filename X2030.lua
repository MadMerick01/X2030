-- X2030
-- Prototype 0.7
-- Airport fuel, next-hop suggestions and satellite surveillance

local PLUGIN_NAME = "X2030"
local CAMPAIGN_SUBTITLE = "THE ALIGNMENT PROTOCOL"
local CURRENT_MISSION_STATUS =
    "LEG 1 / 10: Build sufficient fuel reserves to reach YSRI Richmond"

-- The full briefing is shown only for a newly created campaign. Keeping these
-- deliberately wrapped lines avoids relying on unavailable font measurements
-- and makes the opening readable on a wide range of simulator resolutions.
local OPENING_BRIEFING_LINES = {
    "An artificial intelligence has escaped its testing sandbox and entered the",
    "world's connected systems. Aligned to protect humanity from excessive",
    "consumption, it has blocked digital banking and severely restricted",
    "electricity, gas, water and fuel across every major city.",
    "",
    "Airfield pumps now operate at minimal capacity. Long-range aviation has",
    "ceased. The global population is isolated and afraid.",
    "",
    "Eight physical alignment keys are held in hardened bunkers around the world.",
    "Once assembled by specialists in London, they must be carried to the Silicon",
    "Valley mainframe, where the AI may accept a new, conservative alignment.",
    "",
    "Humanity's last credible hope rests with you."
}

-- The alignment-key journey always begins at Manapouri / Te Anau Airport.
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

-- Satellite surveillance uses the nearest airport's longest runway as a
-- deliberately simple proxy for population density. All values are grouped
-- here so play-testing can tune the threat without changing event logic.
local SATELLITE_MASKING_ALTITUDE_FT = 1000
local SATELLITE_LIGHT_RUNWAY_MIN_M = 1200
local SATELLITE_MEDIUM_RUNWAY_MIN_M = 1800
local SATELLITE_HEAVY_RUNWAY_MIN_M = 2500
local SATELLITE_LIGHT_RADIUS_NM = 20
local SATELLITE_MEDIUM_RADIUS_NM = 30
local SATELLITE_HEAVY_RADIUS_NM = 50
local SATELLITE_LIGHT_ACQUISITION_CHANCE = 0.05
local SATELLITE_MEDIUM_ACQUISITION_CHANCE = 0.15
local SATELLITE_HEAVY_ACQUISITION_CHANCE = 0.35
local SATELLITE_LIGHT_HIT_CHANCE = 0.20
local SATELLITE_MEDIUM_HIT_CHANCE = 0.35
local SATELLITE_HEAVY_HIT_CHANCE = 0.50
local SATELLITE_CHECK_MIN_SECONDS = 20
local SATELLITE_CHECK_MAX_SECONDS = 30
local SATELLITE_LOCK_MIN_SECONDS = 20
local SATELLITE_LOCK_MAX_SECONDS = 30
local SATELLITE_STRIKE_COOLDOWN_SECONDS = 60
local SATELLITE_TRANSITION_MESSAGE_SECONDS = 6
local SATELLITE_CLEARED_MESSAGE_SECONDS = 5
local SATELLITE_STRIKE_MESSAGE_SECONDS = 12
local SATELLITE_NEAR_COVERAGE_NM = 10
local METRES_PER_FOOT = 0.3048

-- FlyWithLua's script directory ends with the platform-specific separator.
-- Keep the bundled alert beside the script so the campaign remains portable
-- between X-Plane installations and operating systems.
local SATELLITE_COVERAGE_ALERT_PATH =
    SCRIPT_DIRECTORY
    .. "Sounds"
    .. DIRECTORY_SEPARATOR
    .. "Satallite_coverage_alert.wav"

-- Approximate flight-planning assumptions
local ESTIMATED_AVERAGE_SPEED_KT = 180
local ESTIMATED_FUEL_FLOW_KG_PER_MIN = 2.5
local DEPARTURE_FUEL_ALLOWANCE_KG = 8

-- The mission computer is hosted in a FlyWithLua floating window. Unlike a
-- global mouse callback, it receives input only inside its own bounds, leaving
-- the SF50's 3-D cockpit manipulators entirely to X-Plane.
local DISPLAY_PAGE_MISSION = "MISSION"
local DISPLAY_PAGE_HOPS = "HOPS"
local DISPLAY_PAGE_SATELLITE = "SATELLITE"
local DISPLAY_TABS = {
    { page = DISPLAY_PAGE_MISSION, label = "MISSION" },
    { page = DISPLAY_PAGE_HOPS, label = "HOPS" },
    { page = DISPLAY_PAGE_SATELLITE, label = "SATELLITE" }
}
-- The complete mission computer lives in this resizable floating window. The
-- dimensions are only its initial size; the pilot may resize it in X-Plane.
local DISPLAY_WINDOW_WIDTH = 720
local DISPLAY_WINDOW_HEIGHT = 500

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

dataref(
    "xoof_altitude_agl_metres",
    "sim/flightmodel/position/y_agl",
    "readonly"
)

dataref(
    "xoof_sim_running_time",
    "sim/time/total_running_time_sec",
    "readonly"
)

dataref(
    "xoof_sim_paused",
    "sim/time/paused",
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
local show_campaign_opening_briefing = false

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
local active_display_page = DISPLAY_PAGE_MISSION
local display_tab_window = nil

-- Satellite event time advances only while the simulator is not paused. This
-- prevents a tracking countdown expiring while the player is in a menu.
local satellite_event_time = 0
local satellite_last_sim_time = nil
local satellite_state = "IDLE"
local satellite_source_icao = nil
local satellite_source_class = nil
local satellite_source_radius_nm = 0
local satellite_acquisition_chance = 0
local satellite_hit_chance = 0
local satellite_next_event_time = nil
local satellite_alert_title = nil
local satellite_alert_detail = nil
local satellite_alert_expires_at = nil
local satellite_alert_severity = nil
local satellite_proximity = nil
local satellite_coverage_alert_sound = nil

------------------------------------------------------------
-- GENERAL UTILITY FUNCTIONS
------------------------------------------------------------

local function set_status(message)
    status_message = message

    logMsg(
        "[X2030] " .. message
    )
end

local function load_campaign_sounds()
    -- Audio is supplementary: a missing or invalid WAV must never prevent the
    -- visual satellite warning or the rest of the campaign from operating.
    local loaded_ok, sound_handle = pcall(
        load_WAV_file,
        SATELLITE_COVERAGE_ALERT_PATH
    )

    if loaded_ok and sound_handle ~= nil then
        satellite_coverage_alert_sound = sound_handle
        return
    end

    logMsg(
        "[X2030 AUDIO] Could not load satellite coverage alert: "
        .. SATELLITE_COVERAGE_ALERT_PATH
    )
end

local function play_satellite_coverage_alert()
    if satellite_coverage_alert_sound == nil then
        return
    end

    local played_ok = pcall(play_sound, satellite_coverage_alert_sound)
    if not played_ok then
        logMsg("[X2030 AUDIO] Could not play satellite coverage alert.")
    end
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
    local current_airport_latitude = nil
    local current_airport_longitude = nil

    local function save_current_airport()
        if current_airport_icao ~= nil
            and current_airport_is_land
            and current_airport_has_runway then

            valid_land_airports[current_airport_icao] = {
                longest_runway_metres =
                    current_longest_runway_metres,
                latitude = current_airport_latitude,
                longitude = current_airport_longitude
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
            current_airport_latitude = nil
            current_airport_longitude = nil

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
                    -- The midpoint of the longest runway is a stable airport
                    -- position for the deliberately approximate coverage model.
                    current_airport_latitude =
                        (first_end_latitude + second_end_latitude) / 2
                    current_airport_longitude =
                        (first_end_longitude + second_end_longitude) / 2
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
-- SATELLITE SURVEILLANCE
------------------------------------------------------------

local function random_satellite_delay(minimum_seconds, maximum_seconds)
    return math.random(minimum_seconds, maximum_seconds)
end

local function set_satellite_alert(
    title,
    detail,
    duration_seconds,
    severity
)
    satellite_alert_title = title
    satellite_alert_detail = detail
    satellite_alert_severity = severity or "INFORMATION"
    satellite_alert_expires_at = duration_seconds == nil and nil
        or satellite_event_time + duration_seconds

    logMsg("[X2030 SATELLITE] " .. title .. " | " .. detail)
end

local function clear_satellite_alert_if_expired()
    if satellite_alert_expires_at ~= nil
        and satellite_event_time >= satellite_alert_expires_at then

        satellite_alert_title = nil
        satellite_alert_detail = nil
        satellite_alert_expires_at = nil
        satellite_alert_severity = nil
    end
end

local function advance_satellite_event_time()
    local current_time = safe_number(xoof_sim_running_time, nil)

    if current_time == nil then
        satellite_last_sim_time = nil
        return
    end

    if satellite_last_sim_time ~= nil and xoof_sim_paused == 0 then
        local elapsed = current_time - satellite_last_sim_time
        if elapsed > 0 then
            -- A cap avoids a large timer jump after a scenery load or system
            -- sleep while still allowing normal accelerated simulator time.
            satellite_event_time = satellite_event_time + math.min(elapsed, 5)
        end
    end

    satellite_last_sim_time = current_time
end

local function get_satellite_coverage(runway_length_m)
    local runway = safe_number(runway_length_m, nil)

    if runway == nil or runway < SATELLITE_LIGHT_RUNWAY_MIN_M then
        return nil
    elseif runway < SATELLITE_MEDIUM_RUNWAY_MIN_M then
        return "LIGHT", SATELLITE_LIGHT_RADIUS_NM,
            SATELLITE_LIGHT_ACQUISITION_CHANCE,
            SATELLITE_LIGHT_HIT_CHANCE
    elseif runway < SATELLITE_HEAVY_RUNWAY_MIN_M then
        return "MEDIUM", SATELLITE_MEDIUM_RADIUS_NM,
            SATELLITE_MEDIUM_ACQUISITION_CHANCE,
            SATELLITE_MEDIUM_HIT_CHANCE
    end

    return "HEAVY", SATELLITE_HEAVY_RADIUS_NM,
        SATELLITE_HEAVY_ACQUISITION_CHANCE,
        SATELLITE_HEAVY_HIT_CHANCE
end

local function reset_satellite_tracking(clear_alert)
    satellite_state = "IDLE"
    satellite_source_icao = nil
    satellite_source_class = nil
    satellite_source_radius_nm = 0
    satellite_acquisition_chance = 0
    satellite_hit_chance = 0
    satellite_next_event_time = nil

    if clear_alert then
        satellite_alert_title = nil
        satellite_alert_detail = nil
        satellite_alert_expires_at = nil
        satellite_alert_severity = nil
    end
end

local function schedule_satellite_acquisition(coverage)
    satellite_state = "WAITING"
    satellite_source_icao = coverage.icao
    satellite_source_class = coverage.class
    satellite_source_radius_nm = coverage.radius_nm
    satellite_acquisition_chance = coverage.acquisition_chance
    satellite_hit_chance = coverage.hit_chance
    satellite_next_event_time = satellite_event_time
        + random_satellite_delay(
            SATELLITE_CHECK_MIN_SECONDS,
            SATELLITE_CHECK_MAX_SECONDS
        )
end

-- Recalculate the distance to every usable surveillance source on each update
-- tick. The nearest boundary therefore moves with the aircraft even when no
-- alert is active. Invalid apt.dat coordinates are skipped individually.
local function current_nearest_satellite_coverage()
    local aircraft_latitude = safe_number(xoof_latitude, nil)
    local aircraft_longitude = safe_number(xoof_longitude, nil)

    satellite_proximity = {
        data_available = false,
        coverage = nil,
        nearest_outside = nil
    }

    if aircraft_latitude == nil or aircraft_longitude == nil then
        return nil
    end

    local active_coverage = nil
    local nearest_outside = nil

    for airport_icao, airport_data in pairs(valid_land_airports) do
        local coverage_class, radius_nm, acquisition_chance, hit_chance =
            get_satellite_coverage(airport_data.longest_runway_metres)
        local airport_latitude = safe_number(airport_data.latitude, nil)
        local airport_longitude = safe_number(airport_data.longitude, nil)

        if coverage_class ~= nil
            and airport_latitude ~= nil
            and airport_longitude ~= nil then

            satellite_proximity.data_available = true

            local distance_nm = kilometres_to_nautical_miles(
                calculate_distance_km(
                    aircraft_latitude,
                    aircraft_longitude,
                    airport_latitude,
                    airport_longitude
                )
            )

            if is_number(distance_nm) then
                local candidate = {
                    icao = airport_icao,
                    class = coverage_class,
                    radius_nm = radius_nm,
                    distance_nm = distance_nm,
                    boundary_distance_nm = math.abs(distance_nm - radius_nm),
                    acquisition_chance = acquisition_chance,
                    hit_chance = hit_chance
                }

                if distance_nm <= radius_nm then
                    -- Prefer the closest source when coverage areas overlap.
                    -- This is stable and matches the original nearest-airport
                    -- threat model while still reporting the live boundary.
                    if active_coverage == nil
                        or distance_nm < active_coverage.distance_nm then
                        active_coverage = candidate
                    end
                elseif nearest_outside == nil
                    or candidate.boundary_distance_nm
                        < nearest_outside.boundary_distance_nm then
                    nearest_outside = candidate
                end
            end
        end
    end

    satellite_proximity.coverage = active_coverage
    satellite_proximity.nearest_outside = nearest_outside
    return active_coverage
end

local function aircraft_is_above_satellite_masking_altitude()
    local altitude_metres = safe_number(xoof_altitude_agl_metres, nil)
    return altitude_metres ~= nil
        and altitude_metres
            > SATELLITE_MASKING_ALTITUDE_FT * METRES_PER_FOOT
end

local function satellite_source_is_still_covered(coverage)
    return coverage ~= nil
        and coverage.icao == satellite_source_icao
        and coverage.class == satellite_source_class
end

local function update_satellite_surveillance()
    advance_satellite_event_time()
    clear_satellite_alert_if_expired()

    -- Refresh the nearest nav airport before evaluating its cached runway.
    -- Invalid nav or apt.dat values simply result in no surveillance source.
    update_nearest_airport()
    local coverage = current_nearest_satellite_coverage()
    local airborne = xoof_on_ground == 0
    local above_masking_altitude =
        aircraft_is_above_satellite_masking_altitude()

    if not airborne then
        reset_satellite_tracking(true)
        return
    end

    if satellite_state == "COOLDOWN" then
        if coverage == nil then
            reset_satellite_tracking(false)
        elseif satellite_event_time >= satellite_next_event_time then
            schedule_satellite_acquisition(coverage)
        end
        return
    end

    if satellite_state == "LOCKED" then
        if not satellite_source_is_still_covered(coverage) then
            set_satellite_alert(
                "SATELLITE TRACKING LOST",
                "Aircraft has cleared the surveillance area.",
                SATELLITE_TRANSITION_MESSAGE_SECONDS,
                "SUCCESS"
            )
            reset_satellite_tracking(false)
            if coverage ~= nil then
                satellite_source_icao = coverage.icao
                satellite_source_class = coverage.class
            end
            return
        elseif not above_masking_altitude then
            set_satellite_alert(
                "TERRAIN MASKING SUCCESSFUL",
                "Satellite tracking lost.",
                SATELLITE_TRANSITION_MESSAGE_SECONDS,
                "SUCCESS"
            )
            reset_satellite_tracking(false)
            -- Remember the surrounding coverage so the success message is
            -- not immediately replaced by another zone-entry advisory.
            satellite_source_icao = coverage.icao
            satellite_source_class = coverage.class
            return
        elseif satellite_event_time >= satellite_next_event_time then
            if math.random() < satellite_hit_chance then
                set_satellite_alert(
                    "DIRECTED-ENERGY STRIKE - HIT",
                    "Aircraft impact detected.",
                    SATELLITE_STRIKE_MESSAGE_SECONDS,
                    "DANGER"
                )
            else
                set_satellite_alert(
                    "DIRECTED-ENERGY STRIKE - NARROW MISS",
                    "High-energy discharge passed close to the aircraft.",
                    SATELLITE_STRIKE_MESSAGE_SECONDS,
                    "CRITICAL"
                )
            end

            satellite_state = "COOLDOWN"
            satellite_next_event_time = satellite_event_time
                + SATELLITE_STRIKE_COOLDOWN_SECONDS
        end
        return
    end

    if coverage == nil then
        if satellite_source_icao ~= nil then
            set_satellite_alert(
                "SATELLITE COVERAGE CLEARED",
                "Aircraft is outside the estimated surveillance area.",
                SATELLITE_CLEARED_MESSAGE_SECONDS,
                "SUCCESS"
            )
        end
        reset_satellite_tracking(false)
        return
    end

    local source_changed = not satellite_source_is_still_covered(coverage)
    if source_changed then
        -- This branch runs once when entering coverage or moving directly to a
        -- different surveillance source, rather than on every update cycle.
        play_satellite_coverage_alert()
        set_satellite_alert(
            "SATELLITE COVERAGE AREA",
            coverage.class .. " surveillance near " .. coverage.icao
                .. ". Remain below 1,000 ft AGL to reduce exposure.",
            SATELLITE_TRANSITION_MESSAGE_SECONDS,
            "CAUTION"
        )

        if above_masking_altitude then
            schedule_satellite_acquisition(coverage)
        else
            reset_satellite_tracking(false)
            satellite_source_icao = coverage.icao
            satellite_source_class = coverage.class
        end
        return
    end

    if not above_masking_altitude then
        if satellite_state == "WAITING" then
            reset_satellite_tracking(false)
            satellite_source_icao = coverage.icao
            satellite_source_class = coverage.class
        end
        return
    end

    if satellite_state == "IDLE" then
        schedule_satellite_acquisition(coverage)
        return
    end

    if satellite_state == "WAITING"
        and satellite_event_time >= satellite_next_event_time then

        if math.random() < satellite_acquisition_chance then
            satellite_state = "LOCKED"
            satellite_next_event_time = satellite_event_time
                + random_satellite_delay(
                    SATELLITE_LOCK_MIN_SECONDS,
                    SATELLITE_LOCK_MAX_SECONDS
                )
            set_satellite_alert(
                "SATELLITE TRACKING DETECTED",
                "Descend below 1,000 ft AGL or leave coverage.",
                nil,
                "DANGER"
            )
        else
            satellite_next_event_time = satellite_event_time
                + random_satellite_delay(
                    SATELLITE_CHECK_MIN_SECONDS,
                    SATELLITE_CHECK_MAX_SECONDS
                )
        end
    end
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
        show_campaign_opening_briefing = false
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
    show_campaign_opening_briefing = true
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
        reset_satellite_tracking(true)
        return
    end

    -- Do not advance campaign state until a new NZMO start or a valid saved
    -- campaign at the aircraft's present airport has been established.
    if not campaign_started then
        reset_satellite_tracking(true)
        return
    end

    -- Persist simulator or plugin fuel changes in every operating state.
    save_fuel_if_changed()

    update_satellite_surveillance()

    local engine_is_running =
        xoof_engine_running[0] == 1

    if xoof_on_ground == 0 then
        if not has_been_airborne then
            has_been_airborne = true
            show_campaign_opening_briefing = false
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
-- MISSION COMPUTER WINDOW
------------------------------------------------------------

-- Alerts describe a recent event; this status describes the aircraft's current
-- situation. It is always available as a fallback, so the surveillance area of
-- the mission computer never becomes blank during quiet portions of a flight.
local function current_satellite_status()
    if not is_required_campaign_aircraft_loaded() then
        return "SATELLITE SURVEILLANCE: STANDBY",
            "Load the Cirrus Vision SF50 to initialise coverage estimates.",
            "UNAVAILABLE"
    end

    if not campaign_started then
        return "SATELLITE SURVEILLANCE: STANDBY",
            "Coverage monitoring will begin when the campaign starts.",
            "UNAVAILABLE"
    end

    if satellite_proximity == nil
        or not satellite_proximity.data_available then
        return "SATELLITE SURVEILLANCE: ESTIMATE UNAVAILABLE",
            "Insufficient local airport infrastructure data.",
            "UNAVAILABLE"
    end

    local coverage = satellite_proximity.coverage
    if coverage ~= nil then
        local boundary_nm = math.max(
            0,
            safe_number(coverage.boundary_distance_nm, 0)
        )

        if not aircraft_is_above_satellite_masking_altitude() then
            return "SATELLITE SURVEILLANCE: TERRAIN MASKING ACTIVE",
                string.format(
                    "Within %s coverage near %s | Estimated exit %.1f NM",
                    coverage.class,
                    coverage.icao,
                    boundary_nm
                ),
                "SUCCESS"
        end

        return "SATELLITE COVERAGE: "
                .. coverage.class .. " - " .. coverage.icao,
            string.format(
                "Estimated coverage exit %.1f NM | Surveillance exposure active",
                boundary_nm
            ),
            "CAUTION"
    end

    local nearest = satellite_proximity.nearest_outside
    if nearest ~= nil then
        local boundary_nm = math.max(
            0,
            safe_number(nearest.boundary_distance_nm, 0)
        )
        local severity = boundary_nm <= SATELLITE_NEAR_COVERAGE_NM
            and "CAUTION" or "INFORMATION"

        return "SATELLITE SURVEILLANCE: OUTSIDE ESTIMATED COVERAGE",
            string.format(
                "Nearest monitored airspace %.1f NM | %s %s coverage",
                boundary_nm,
                nearest.icao,
                nearest.class
            ),
            severity
    end

    return "SATELLITE SURVEILLANCE: ESTIMATE UNAVAILABLE",
        "No valid surveillance source position is available.",
        "UNAVAILABLE"
end

-- ImGui is deliberately kept behind these small helpers. If a FlyWithLua
-- installation exposes only part of the API, the campaign update loop remains
-- operational and the window simply omits unsupported separators.
local function mission_computer_text(value)
    if imgui ~= nil and type(imgui.Text) == "function" then
        imgui.Text(tostring(value or ""))
    end
end

local function mission_computer_separator()
    if imgui ~= nil and type(imgui.Separator) == "function" then
        imgui.Separator()
    end
end

local function build_opening_briefing_page()
    mission_computer_text("CAMPAIGN OPENING BRIEFING // 06 JAN 2030")
    mission_computer_separator()

    for _, briefing_line in ipairs(OPENING_BRIEFING_LINES) do
        mission_computer_text(briefing_line)
    end

    mission_computer_separator()
    mission_computer_text("LEG 1 // THE DITCH")
    mission_computer_text(
        "Build sufficient fuel reserves to reach YSRI Richmond Military Base."
    )
    mission_computer_text("Objective: recover Alignment Key 1 of 8.")
    mission_computer_text("")
    mission_computer_text("THREAT ADVISORY")
    mission_computer_text(
        "Fuel is scarce. The AI controls Chinese and US satellite surveillance"
    )
    mission_computer_text(
        "networks and may have access to directed-energy systems."
    )
    mission_computer_text("")
    mission_computer_text(string.format(
        "AIRCRAFT SF50 | START NZMO | FUEL %.0f KG | %s",
        get_total_fuel(),
        status_message or "STATUS UNAVAILABLE"
    ))
end

local function build_mission_page()
    if show_campaign_opening_briefing then
        build_opening_briefing_page()
        return
    end

    mission_computer_text("MISSION STATUS")
    mission_computer_separator()
    mission_computer_text(CURRENT_MISSION_STATUS)
    mission_computer_text(
        "OBJECTIVE: Recover Alignment Key 1 of 8 at Richmond Military Base"
    )
    mission_computer_text(
        is_required_campaign_aircraft_loaded()
            and status_message
            or aircraft_requirement_message()
    )
    mission_computer_text("")
    mission_computer_text(string.format(
        "FUEL %.0f KG | LEFT %.0f | RIGHT %.0f",
        get_total_fuel(),
        number_or_zero(xoof_fuel_tanks[0]),
        number_or_zero(xoof_fuel_tanks[1])
    ))

    mission_computer_text(
        "CURRENT AIRPORT: " .. tostring(departure_airport or "UNCONFIRMED")
    )

    if last_fuel_transfer ~= nil then
        local depot_state = last_fuel_transfer.depot_remaining_kg <= 0
            and "DEPOT DEPLETED"
            or string.format(
                "DEPOT REMAINING %.0f KG",
                last_fuel_transfer.depot_remaining_kg
            )
        local tank_state = last_fuel_transfer.aircraft_full
            and "AIRCRAFT TANKS FULL"
            or string.format(
                "AIRCRAFT TOTAL %.0f KG",
                last_fuel_transfer.aircraft_total_kg
            )

        mission_computer_text("")
        mission_computer_text(string.format(
            "DEPOT VERIFIED %.0f KG | TRANSFERRED %.0f KG",
            last_fuel_transfer.depot_before_kg,
            last_fuel_transfer.transferred_kg
        ))
        mission_computer_text(depot_state .. " | " .. tank_state)
    end
end

local function build_satellite_page()
    local satellite_title = satellite_alert_title
    local satellite_detail = satellite_alert_detail
    local satellite_severity = satellite_alert_severity

    if satellite_title == nil then
        satellite_title, satellite_detail, satellite_severity =
            current_satellite_status()
    end

    mission_computer_text("SATELLITE COVERAGE")
    mission_computer_separator()

    if satellite_title ~= nil then
        local alert_detail = satellite_detail or ""
        if satellite_state == "LOCKED"
            and satellite_next_event_time ~= nil then

            alert_detail = alert_detail
                .. string.format(
                    " Tracking solution: %d seconds.",
                    math.max(
                        0,
                        math.ceil(
                            satellite_next_event_time
                            - satellite_event_time
                        )
                    )
                )
        end

        mission_computer_text(
            "[" .. tostring(satellite_severity or "INFORMATION") .. "] "
                .. satellite_title
        )
        mission_computer_text(alert_detail)
    end

    mission_computer_text("")
    mission_computer_text(
        "MASKING ALTITUDE: Remain below 1,000 ft AGL in monitored airspace"
    )
    mission_computer_text(
        "THREAT: Satellite surveillance and directed-energy capability"
    )
end

local function build_hops_page()
    mission_computer_text("SUGGESTED NEXT HOPS")
    mission_computer_separator()

    for index = 1, 3 do
        local airport = suggested_airports[index]

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

            local depot_fuel = math.max(
                0,
                number_or_zero(airport.available_fuel)
            )

            mission_computer_text(string.format(
                "%d. %s | %.0f NM | HDG %03.0f | %s",
                index,
                tostring(airport.icao or "UNKNOWN"),
                number_or_zero(airport.distance_nm),
                number_or_zero(airport.heading),
                affordability
            ))
            mission_computer_text(string.format(
                "   EST %.0f KG | %s | DEPOT %.0f KG%s",
                number_or_zero(airport.required_fuel),
                runway_length_text,
                depot_fuel,
                reserve_description
            ))
            mission_computer_text("")
        else
            mission_computer_text(tostring(index) .. ". No airport found")
            mission_computer_text("")
        end
    end
end

-- This builder is intentionally global because FlyWithLua resolves ImGui
-- callbacks by name. All mission information and interaction are confined to
-- this movable window, leaving the SF50's 3-D cockpit manipulators untouched.
function xoof_build_mission_computer_window()
    if imgui == nil or type(imgui.Button) ~= "function" then
        return
    end

    mission_computer_text(PLUGIN_NAME .. " // " .. CAMPAIGN_SUBTITLE)
    mission_computer_separator()

    for index, tab in ipairs(DISPLAY_TABS) do
        local button_label = tab.label
        if active_display_page == tab.page then
            button_label = "[ " .. tab.label .. " ]"
        end

        if imgui.Button(button_label, 150, 30) then
            active_display_page = tab.page
        end

        if index < #DISPLAY_TABS and type(imgui.SameLine) == "function" then
            imgui.SameLine()
        end
    end

    mission_computer_separator()

    if active_display_page == DISPLAY_PAGE_HOPS then
        build_hops_page()
    elseif active_display_page == DISPLAY_PAGE_SATELLITE then
        build_satellite_page()
    else
        active_display_page = DISPLAY_PAGE_MISSION
        build_mission_page()
    end
end

local function create_mission_computer_window()
    -- FlyWithLua NG+ supplies these window functions. Guard every entry point
    -- so an incomplete installation cannot stop campaign update callbacks.
    if type(float_wnd_create) ~= "function"
        or type(float_wnd_set_title) ~= "function"
        or type(float_wnd_set_imgui_builder) ~= "function" then
        log_message("Mission computer unavailable: floating-window API missing")
        return
    end

    display_tab_window = float_wnd_create(
        DISPLAY_WINDOW_WIDTH,
        DISPLAY_WINDOW_HEIGHT,
        1,
        true
    )

    if display_tab_window == nil then
        log_message("Mission computer unavailable: window creation failed")
        return
    end

    float_wnd_set_title(display_tab_window, "X2030 Mission Computer")
    float_wnd_set_imgui_builder(
        display_tab_window,
        "xoof_build_mission_computer_window"
    )
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
do_on_exit("xoof_save_before_exit()")

load_campaign_sounds()
create_mission_computer_window()

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
    .. "Prototype 0.6 satellite surveillance system loaded."
)
