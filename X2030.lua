-- X2030
-- Prototype 0.9
-- Airport fuel, next-hop suggestions and satellite surveillance

local PLUGIN_NAME = "X2030"
local CAMPAIGN_SUBTITLE = "THE ALIGNMENT PROTOCOL"
local TOTAL_CAMPAIGN_LEGS = 11
local TOTAL_ALIGNMENT_KEYS = 8

-- Fixed story objectives are deliberately separate from ordinary fuel hops.
-- The pilot may use any intermediate airport, but only the active objective
-- advances the campaign. All story text is data-driven so a missing entry can
-- fall back safely instead of breaking an update or draw callback.
local CAMPAIGN_LEGS = {
    {
        destination_icao = "YSNF",
        destination_name = "Norfolk Island",
        objective = "Rendezvous with the resistance fuel cell",
        arrival = "Norfolk resistance contact established. Full fuel available."
    },
    {
        destination_icao = "YLHI",
        destination_name = "Lord Howe Island",
        objective = "Rendezvous with the second resistance fuel cell",
        arrival = "Lord Howe resistance contact established. Full fuel available."
    },
    {
        destination_icao = "YBAS",
        destination_name = "Alice Springs",
        objective = "Receive Alignment Key 2 from the Pine Gap contingent",
        arrival = "Pine Gap transfer complete. Alignment Key 2 recovered.",
        key_number = 2
    },
    {
        destination_icao = "WAWD",
        destination_name = "Wakatobi",
        objective = "Recover Alignment Key 3 from the island bunker",
        arrival = "Wakatobi bunker secured. Alignment Key 3 recovered.",
        key_number = 3
    },
    {
        destination_icao = "VQPR",
        destination_name = "Paro",
        objective = "Recover Alignment Key 4 from the mountain bunker",
        arrival = "Paro bunker secured. Alignment Key 4 recovered.",
        key_number = 4
    },
    {
        destination_icao = "OMSJ",
        destination_name = "Sharjah / Khor Fakkan",
        objective = "Meet the ground team for the Khor Fakkan bunker",
        arrival = "Khor Fakkan transfer complete. Alignment Key 5 recovered.",
        key_number = 5
    },
    {
        destination_icao = "LOIJ",
        destination_name = "St. Johann",
        objective = "Recover Alignment Key 6 from the Alpine bunker",
        arrival = "Alpine bunker secured. Alignment Key 6 recovered.",
        key_number = 6
    },
    {
        destination_icao = "EGPR",
        destination_name = "Barra",
        objective = "Recover Alignment Key 7 from the island bunker",
        arrival = "Barra transfer complete. Alignment Key 7 recovered.",
        key_number = 7
    },
    {
        destination_icao = "BIAR",
        destination_name = "Akureyri",
        objective = "Recover the final alignment key",
        arrival = "Key set complete. Alignment Key 8 recovered.",
        key_number = 8
    },
    {
        destination_icao = "KBID",
        destination_name = "Block Island",
        objective = "Deliver all eight keys to the Alignment Society",
        arrival = "NYU Tandon researchers assembled the Alignment Protocol.",
        assembles_protocol = true
    },
    {
        destination_icao = "KHAF",
        destination_name = "Half Moon Bay",
        objective = "Deliver the sealed Alignment Protocol to the mainframe team",
        arrival = "Protocol accepted. Human authorization channels are responding.",
        completes_campaign = true
    }
}

-- Resistance safe havens are intentionally exceptional: after every qualified
-- arrival they fill the SF50 completely without consuming a normal depot.
local RESISTANCE_FULL_FUEL_AIRPORTS = {
    YSNF = true,
    YLHI = true
}

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
    "Once recovered, NYU Tandon specialists on Block Island must assemble them",
    "into a conservative protocol for physical delivery at Half Moon Bay.",
    "",
    "Humanity's last credible hope rests with you."
}

-- The alignment-key journey always begins at Manapouri / Te Anau Airport.
-- NZMO is the ICAO identifier used by X-Plane; TEU is its IATA code.
local CAMPAIGN_START_AIRPORT_ICAO = "NZMO"
local CAMPAIGN_START_AIRPORT_NAME = "Manapouri / Te Anau"
local REQUIRED_AIRCRAFT_ICAO = "SF50"
local REQUIRED_AIRCRAFT_NAME = "Cirrus Vision SF50"
local CAMPAIGN_SAVE_VERSION = 4
local CAMPAIGN_PREFERENCES_DIRECTORY =
    SYSTEM_DIRECTORY
    .. "Output"
    .. DIRECTORY_SEPARATOR
    .. "preferences"
    .. DIRECTORY_SEPARATOR
local CAMPAIGN_SAVE_PATH =
    CAMPAIGN_PREFERENCES_DIRECTORY .. "X2030_Campaign.txt"
local CAMPAIGN_BACKUP_PATH =
    CAMPAIGN_PREFERENCES_DIRECTORY .. "X2030_Campaign.backup.txt"
-- Existing campaigns used this filename before the main script was renamed.
-- It remains readable so upgrading does not discard a player's progress.
local LEGACY_CAMPAIGN_SAVE_PATH =
    CAMPAIGN_PREFERENCES_DIRECTORY .. "Xplane_Out_Of_Fuel_Campaign.txt"

------------------------------------------------------------
-- GAME SETTINGS
------------------------------------------------------------

local INITIAL_CAMPAIGN_FUEL_KG = 100
-- Versions 2-4 allowed pilots to choose a starting allocation. Retain these
-- bounds only so profiles created by those versions remain loadable.
local LEGACY_MINIMUM_STARTING_FUEL_KG = 20
local LEGACY_MAXIMUM_STARTING_FUEL_KG = 100
local MAX_RECENT_AIRPORT_FUEL_RECORDS = 10
local POUNDS_PER_KILOGRAM = 2.2046226218
local FUEL_SAVE_INTERVAL_SECONDS = 30

local STOPPED_SPEED_MPS = 1.0
local MAX_AIRPORT_DISTANCE_KM = 5.0
-- Suggestions require a measurable conventional runway at least as long as the
-- SF50's reported minimum takeoff distance. Pilots must still account for
-- runway condition, elevation, weather and aircraft loading.
local MINIMUM_SUGGESTED_RUNWAY_LENGTH_METRES = 650
-- Duplicate airport identifiers can exist in third-party scenery. A nav-aid
-- must therefore also be close to the runway recorded for that identifier.
local MAX_NAV_AID_TO_RUNWAY_DISTANCE_KM = 5.0

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
-- X-Plane failure datarefs use 6 for an inoperative system. Keep the value
-- named so later damage packages do not scatter an unexplained magic number.
local XPLANE_FAILURE_INOPERATIVE = 6
local METRES_PER_FOOT = 0.3048

-- FlyWithLua's script directory ends with the platform-specific separator.
-- Keep the bundled alert beside the script so the campaign remains portable
-- between X-Plane installations and operating systems.
local SATELLITE_COVERAGE_ALERT_PATH =
    SCRIPT_DIRECTORY
    .. "Sounds"
    .. DIRECTORY_SEPARATOR
    .. "Satallite_coverage_alert.wav"
local SATELLITE_HIT_SOUND_PATH =
    SCRIPT_DIRECTORY
    .. "Sounds"
    .. DIRECTORY_SEPARATOR
    .. "laser_hit1.wav"

-- Recording placeholders. The campaign continues with on-screen text until the
-- pilot supplies these WAV files; project_brief.md preserves the recording copy.
local MANAPOURI_MESSAGE_PATH =
    SCRIPT_DIRECTORY .. "Sounds" .. DIRECTORY_SEPARATOR
    .. "manapouri_bunker_message.wav"
local HALF_MOON_BAY_MESSAGE_PATH =
    SCRIPT_DIRECTORY .. "Sounds" .. DIRECTORY_SEPARATOR
    .. "half_moon_bay_message.wav"

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
local DISPLAY_PAGE_MAINTENANCE = "MAINTENANCE"
local DISPLAY_PAGE_KEYS = "KEYS"
local DISPLAY_TABS = {
    { page = DISPLAY_PAGE_MISSION, label = "MISSION" },
    { page = DISPLAY_PAGE_HOPS, label = "FUEL" },
    { page = DISPLAY_PAGE_SATELLITE, label = "SATELLITE" },
    { page = DISPLAY_PAGE_MAINTENANCE, label = "MAINTENANCE" },
    { page = DISPLAY_PAGE_KEYS, label = "KEYS" }
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

-- The first satellite damage package is deliberately specific to the SF50:
-- both electrical buses fail and its single engine catches fire.
dataref(
    "xoof_failure_bus_1",
    "sim/operation/failures/rel_esys",
    "writable"
)

dataref(
    "xoof_failure_bus_2",
    "sim/operation/failures/rel_esys2",
    "writable"
)

dataref(
    "xoof_failure_engine_1_fire",
    "sim/operation/failures/rel_engfir0",
    "writable"
)

------------------------------------------------------------
-- CAMPAIGN STATE
------------------------------------------------------------

local has_been_airborne = false
local current_landing_processed = false
local campaign_started = false
local show_campaign_opening_briefing = false
local profile_screen_active = true
local overwrite_confirmation_active = false
local pilot_name = nil
local campaign_starting_fuel_kg = INITIAL_CAMPAIGN_FUEL_KG
local campaign_leg = 1
local alignment_keys_recovered = 1
local alignment_protocol_assembled = false
local campaign_completed = false
local latest_story_event = "Alignment Key 1 recovered from the Manapouri bunker."
local profile_name_input = ""
local profile_status_message = "Select or create a pilot profile."
local available_saved_campaign = nil
local available_save_error = nil

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
local last_fuel_save_sim_time = nil
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
-- Test telemetry mirrors the discrete random rolls used by surveillance. It is
-- intentionally display-only: exposing these values must never alter timing,
-- probabilities or campaign state while the system is being validated.
local satellite_acquisition_check_count = 0
local satellite_last_acquisition_roll = nil
local satellite_last_hit_roll = nil
local satellite_coverage_alert_sound = nil
local satellite_hit_sound = nil
local satellite_electrical_fire_damage_active = false
local manapouri_message_sound = nil
local half_moon_bay_message_sound = nil

------------------------------------------------------------
-- GENERAL UTILITY FUNCTIONS
------------------------------------------------------------

local function set_status(message)
    status_message = message

    logMsg(
        "[X2030] " .. message
    )
end

local function campaign_sound_file_has_wav_header(sound_path)
    local sound_file = io.open(sound_path, "rb")
    if sound_file == nil then
        return false, "file is missing or unreadable"
    end

    -- OpenAL needs a real WAV container, not merely a file carrying a .wav
    -- suffix. Checking the container signature here gives a useful diagnostic
    -- before FlyWithLua reduces all load failures to buffer handle 0.
    local header = sound_file:read(12)
    sound_file:close()

    if header == nil or #header < 12
        or string.sub(header, 1, 4) ~= "RIFF"
        or string.sub(header, 9, 12) ~= "WAVE" then

        return false, "file is not a RIFF/WAVE recording"
    end

    return true, nil
end

local function load_campaign_sound(sound_path, description, optional)
    local valid_file, validation_error =
        campaign_sound_file_has_wav_header(sound_path)

    if not valid_file then
        local availability = optional and "Optional recording unavailable: "
            or "Could not load required alert: "
        logMsg(
            "[X2030 AUDIO] " .. availability .. sound_path
                .. " (" .. validation_error .. ")"
        )
        return nil
    end

    local loaded_ok, sound_handle = pcall(load_WAV_file, sound_path)
    local numeric_handle = tonumber(sound_handle)

    -- FlyWithLua/OpenAL reports a failed buffer creation as handle 0. It is
    -- not a playable sound even though it is non-nil and pcall succeeded.
    if not loaded_ok or numeric_handle == nil or numeric_handle <= 0 then
        logMsg(
            "[X2030 AUDIO] OpenAL could not create a buffer for "
                .. description .. ": " .. sound_path
                .. " (confirm uncompressed PCM WAV format)"
        )
        return nil
    end

    return sound_handle
end

local function load_campaign_sounds()
    -- Audio is supplementary: a missing or invalid WAV must never prevent the
    -- visual satellite warning or the rest of the campaign from operating.
    satellite_coverage_alert_sound = load_campaign_sound(
        SATELLITE_COVERAGE_ALERT_PATH,
        "satellite coverage alert",
        false
    )
    satellite_hit_sound = load_campaign_sound(
        SATELLITE_HIT_SOUND_PATH,
        "satellite strike impact",
        false
    )

    -- These two files are intentional placeholders. Fail quietly apart from a
    -- log entry until the recorded campaign messages are added later.
    manapouri_message_sound = load_campaign_sound(
        MANAPOURI_MESSAGE_PATH, "Manapouri bunker message", true)
    half_moon_bay_message_sound = load_campaign_sound(
        HALF_MOON_BAY_MESSAGE_PATH, "Half Moon Bay message", true)
end

local function play_optional_campaign_message(sound_handle, description)
    if sound_handle == nil then
        return false
    end

    local played_ok = pcall(play_sound, sound_handle)
    if not played_ok then
        logMsg("[X2030 AUDIO] Could not play " .. tostring(description) .. ".")
        return false
    end

    return true
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

local function play_satellite_hit_sound()
    if satellite_hit_sound == nil then
        return
    end

    local played_ok = pcall(play_sound, satellite_hit_sound)
    if not played_ok then
        logMsg("[X2030 AUDIO] Could not play satellite strike impact.")
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
        return "UNKNOWN", 44, 120, 0.25, 0.05
    elseif runway < 700 then
        return "TINY", 144, 200, 0.10, 0.10
    elseif runway < 1000 then
        return "SMALL", 112, 176, 0.15, 0.10
    elseif runway < 1500 then
        return "REGIONAL", 72, 140, 0.25, 0.05
    elseif runway < 2200 then
        return "LARGE REGIONAL", 32, 96, 0.45, 0.02
    end

    return "MAJOR", 0, 44, 0.70, 0
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
            fuel_kg = math.random(176, 224)
        else
            fuel_kg = math.random(144, 200)
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

    local save_version = tonumber(saved_values.version)
    if (save_version ~= 1 and save_version ~= 2
            and save_version ~= 3
            and save_version ~= CAMPAIGN_SAVE_VERSION)
        or saved_values.campaign_started ~= "1"
        or not is_valid_airport_identifier(
            saved_values.current_airport
        ) then

        return nil, "invalid", loaded_save_path
    end

    if save_version >= 2 then
        local saved_name = saved_values.pilot_name or ""
        local saved_starting_fuel = tonumber(saved_values.starting_fuel_kg)
        if #saved_name < 2 or #saved_name > 32
            or string.find(saved_name, "[^%w%s%-%']")
            or not is_number(saved_starting_fuel)
            or saved_starting_fuel ~= math.floor(saved_starting_fuel)
            or saved_starting_fuel < LEGACY_MINIMUM_STARTING_FUEL_KG
            or saved_starting_fuel > LEGACY_MAXIMUM_STARTING_FUEL_KG then
            return nil, "invalid", loaded_save_path
        end
    end

    local saved_campaign_leg = 1
    local saved_keys_recovered = 1
    local saved_protocol_assembled = false
    local saved_campaign_completed = false

    if save_version >= 3 then
        saved_campaign_leg = tonumber(saved_values.campaign_leg)
        saved_keys_recovered = tonumber(saved_values.keys_recovered)
        saved_protocol_assembled = saved_values.protocol_assembled == "1"
        saved_campaign_completed = saved_values.campaign_completed == "1"

        if saved_campaign_leg == nil
            or saved_campaign_leg ~= math.floor(saved_campaign_leg)
            or saved_campaign_leg < 1
            or saved_campaign_leg > TOTAL_CAMPAIGN_LEGS
            or saved_keys_recovered == nil
            or saved_keys_recovered ~= math.floor(saved_keys_recovered)
            or saved_keys_recovered < 1
            or saved_keys_recovered > TOTAL_ALIGNMENT_KEYS
            or (saved_protocol_assembled and saved_keys_recovered < 8)
            or (saved_campaign_completed and not saved_protocol_assembled) then

            return nil, "invalid", loaded_save_path
        end
    end

    local saved_fuel_tanks = {}

    -- Save versions 1-3 stored all nine generic X-Plane tank slots. Version 4
    -- stores only the two tanks used by the campaign's required SF50.
    local final_saved_tank = save_version >= 4 and 1 or 8
    for tank = 0, final_saved_tank do
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
        version = save_version,
        pilot_name = saved_values.pilot_name or "LEGACY PILOT",
        starting_fuel_kg = tonumber(saved_values.starting_fuel_kg)
            or INITIAL_CAMPAIGN_FUEL_KG,
        current_airport = saved_values.current_airport,
        campaign_leg = saved_campaign_leg,
        keys_recovered = saved_keys_recovered,
        protocol_assembled = saved_protocol_assembled,
        campaign_completed = saved_campaign_completed,
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
        "pilot_name=", tostring(pilot_name or "UNKNOWN PILOT"), "\n",
        "starting_fuel_kg=",
            tostring(campaign_starting_fuel_kg), "\n",
        "current_airport=", departure_airport, "\n",
        "campaign_leg=", tostring(campaign_leg), "\n",
        "keys_recovered=", tostring(alignment_keys_recovered), "\n",
        "protocol_assembled=",
            alignment_protocol_assembled and "1\n" or "0\n",
        "campaign_completed=", campaign_completed and "1\n" or "0\n"
    )

    for tank = 0, 1 do
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
    for tank = 0, 1 do
        saved_tanks[#saved_tanks + 1] = string.format(
            "%.3f",
            number_or_zero(xoof_fuel_tanks[tank])
        )
    end

    last_saved_fuel_signature = table.concat(saved_tanks, ",")
    last_fuel_save_sim_time = safe_number(xoof_sim_running_time, nil)

    return true
end

-- Preserve one known-good profile before an explicit replacement. Failure to
-- make the optional backup is reported but never removes the original save.
local function backup_existing_campaign()
    local source_file = io.open(CAMPAIGN_SAVE_PATH, "r")
    if source_file == nil then
        return true
    end

    local contents = source_file:read("*a")
    source_file:close()

    local backup_file = io.open(CAMPAIGN_BACKUP_PATH, "w")
    if backup_file == nil then
        return false
    end

    backup_file:write(contents or "")
    backup_file:close()
    return true
end

-- Fuel changes continuously in flight, so arrival-only saves can restore an
-- obsolete quantity after X-Plane is closed. Check the compact two-tank SF50
-- signature often, but limit disk writes to one every 30 seconds. Qualified
-- arrivals and simulator exit still save immediately through their own paths.
local function save_fuel_if_changed()
    if not campaign_started then
        return
    end

    local current_tanks = {}

    for tank = 0, 1 do
        current_tanks[#current_tanks + 1] = string.format(
            "%.3f",
            number_or_zero(xoof_fuel_tanks[tank])
        )
    end

    local current_signature = table.concat(current_tanks, ",")
    if current_signature == last_saved_fuel_signature then
        return
    end

    local current_sim_time = safe_number(xoof_sim_running_time, nil)
    if current_sim_time == nil then
        return
    end

    if last_fuel_save_sim_time == nil
        or current_sim_time - last_fuel_save_sim_time
            >= FUEL_SAVE_INTERVAL_SECONDS then
        save_campaign_progress()
    end
end

local function restore_saved_fuel(saved_fuel_tanks)
    if type(saved_fuel_tanks) ~= "table" then
        return
    end

    for tank = 0, 1 do
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

local function is_valid_suggested_airport(icao, latitude, longitude)
    if not is_valid_destination_airport(icao) then
        return false
    end

    local airport_data = valid_land_airports[icao]
    if airport_data == nil then
        return false
    end

    local runway_length = safe_number(
        airport_data.longest_runway_metres, nil)
    if runway_length == nil
        or runway_length < MINIMUM_SUGGESTED_RUNWAY_LENGTH_METRES then

        return false
    end

    -- When coordinates are supplied by the nav database, make sure this is
    -- the same facility as the conventional runway found in apt.dat. This
    -- prevents a heliport sharing an identifier with an airfield from being
    -- offered at the heliport's position. Missing coordinates fail safely.
    local nav_latitude = safe_number(latitude, nil)
    local nav_longitude = safe_number(longitude, nil)
    local runway_latitude = safe_number(airport_data.latitude, nil)
    local runway_longitude = safe_number(airport_data.longitude, nil)

    if nav_latitude == nil or nav_longitude == nil
        or runway_latitude == nil or runway_longitude == nil then

        return false
    end

    local nav_aid_distance_km = calculate_distance_km(
        nav_latitude,
        nav_longitude,
        runway_latitude,
        runway_longitude
    )

    if not is_number(nav_aid_distance_km)
        or nav_aid_distance_km > MAX_NAV_AID_TO_RUNWAY_DISTANCE_KM then

        return false
    end

    return true
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
    local safe_minimum = safe_number(minimum_seconds, nil)
    local safe_maximum = safe_number(maximum_seconds, nil)

    if safe_minimum == nil or safe_maximum == nil
        or safe_minimum < 0 or safe_maximum < safe_minimum then

        logMsg("[X2030 SATELLITE] Invalid event-delay range; tracking reset.")
        return nil
    end

    return math.random(safe_minimum, safe_maximum)
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

    -- A nil duration deliberately means that an alert remains visible until
    -- tracking state replaces or clears it. Lua's common "a and b or c"
    -- idiom cannot represent that nil result: it falls through to c and was
    -- the source of the duration_seconds arithmetic crash.
    if duration_seconds == nil then
        satellite_alert_expires_at = nil
    else
        local valid_duration = safe_number(duration_seconds, nil)
        if valid_duration ~= nil and valid_duration > 0 then
            satellite_alert_expires_at = satellite_event_time + valid_duration
        else
            -- Invalid timing must not dismiss the warning immediately. Treat
            -- it as persistent and leave a diagnostic for script authors.
            satellite_alert_expires_at = nil
            logMsg(
                "[X2030 SATELLITE] Invalid alert duration; alert will remain "
                    .. "visible until its tracking state changes."
            )
        end
    end

    logMsg("[X2030 SATELLITE] " .. title .. " | " .. detail)
end

local function satellite_deadline_reached(deadline)
    local valid_deadline = safe_number(deadline, nil)
    return valid_deadline ~= nil and satellite_event_time >= valid_deadline
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
    satellite_acquisition_check_count = 0
    satellite_last_acquisition_roll = nil
    satellite_last_hit_roll = nil

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
    local acquisition_delay = random_satellite_delay(
        SATELLITE_CHECK_MIN_SECONDS,
        SATELLITE_CHECK_MAX_SECONDS
    )
    if acquisition_delay == nil then
        reset_satellite_tracking(false)
        return false
    end

    satellite_next_event_time = satellite_event_time + acquisition_delay
    return true
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

-- Apply the first strike outcome exactly once. Advancing the satellite state
-- immediately after this call prevents the frequently-running update callback
-- from repeatedly writing failures or replaying the impact sound.
local function apply_satellite_electrical_fire_damage()
    xoof_failure_bus_1 = XPLANE_FAILURE_INOPERATIVE
    xoof_failure_bus_2 = XPLANE_FAILURE_INOPERATIVE
    xoof_failure_engine_1_fire = XPLANE_FAILURE_INOPERATIVE
    satellite_electrical_fire_damage_active = true
    play_satellite_hit_sound()

    logMsg(
        "[X2030 SATELLITE] Damage applied: electrical buses 1 and 2 "
            .. "inoperative; engine 1 fire."
    )
    return true
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
        elseif satellite_deadline_reached(satellite_next_event_time) then
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
        elseif satellite_deadline_reached(satellite_next_event_time) then
            satellite_last_hit_roll = math.random()
            if satellite_last_hit_roll < satellite_hit_chance then
                apply_satellite_electrical_fire_damage()
                set_satellite_alert(
                    "DIRECTED-ENERGY STRIKE - HIT",
                    "Bus 1 and Bus 2 offline. Engine fire detected.",
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
        and satellite_deadline_reached(satellite_next_event_time) then

        satellite_acquisition_check_count =
            satellite_acquisition_check_count + 1
        satellite_last_acquisition_roll = math.random()

        if satellite_last_acquisition_roll < satellite_acquisition_chance then
            satellite_state = "LOCKED"
            local strike_delay = random_satellite_delay(
                SATELLITE_LOCK_MIN_SECONDS,
                SATELLITE_LOCK_MAX_SECONDS
            )
            if strike_delay == nil then
                reset_satellite_tracking(false)
                return
            end
            satellite_next_event_time = satellite_event_time + strike_delay
            set_satellite_alert(
                "SATELLITE TRACKING DETECTED",
                "Descend below 1,000 ft AGL or leave coverage.",
                nil,
                "DANGER"
            )
        else
            local retry_delay = random_satellite_delay(
                SATELLITE_CHECK_MIN_SECONDS,
                SATELLITE_CHECK_MAX_SECONDS
            )
            if retry_delay == nil then
                reset_satellite_tracking(false)
                return
            end
            satellite_next_event_time = satellite_event_time + retry_delay
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
            and is_valid_suggested_airport(
                airport_icao,
                airport_latitude,
                airport_longitude
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

    for tank = 0, 1 do
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

-- Resistance fuel is an unlimited strategic service rather than an airport
-- depot. It may be used on every return to Norfolk or Lord Howe, but only after
-- the same stopped-and-shut-down arrival checks used by ordinary refuelling.
local function fill_aircraft_from_resistance(airport_icao)
    if not RESISTANCE_FULL_FUEL_AIRPORTS[airport_icao] then
        return nil
    end

    local remaining_capacity, capacity_kg =
        get_aircraft_remaining_fuel_capacity_kg()
    if remaining_capacity == nil or capacity_kg == nil then
        return nil
    end

    if remaining_capacity > 0 and not add_balanced_fuel(remaining_capacity) then
        return nil
    end

    logMsg(string.format(
        "[X2030 FUEL] Resistance at %s filled aircraft to %.0f kg",
        airport_icao, capacity_kg))

    return {
        icao = airport_icao,
        depot_before_kg = remaining_capacity,
        transferred_kg = remaining_capacity,
        depot_remaining_kg = capacity_kg,
        aircraft_total_kg = get_total_fuel(),
        aircraft_full = true,
        resistance_service = true
    }
end

local function get_active_campaign_leg()
    if campaign_completed then
        return CAMPAIGN_LEGS[TOTAL_CAMPAIGN_LEGS]
    end

    local safe_leg = safe_number(campaign_leg, nil)
    if safe_leg == nil or safe_leg ~= math.floor(safe_leg)
        or safe_leg < 1 or safe_leg > TOTAL_CAMPAIGN_LEGS then
        return nil
    end

    return CAMPAIGN_LEGS[safe_leg]
end

-- Advance only when the active fixed objective is reached in sequence. Landing
-- at a future story airport early remains a normal fuel stop and grants no key.
local function process_story_arrival(arrival_icao)
    if campaign_completed or not is_valid_airport_identifier(arrival_icao) then
        return nil
    end

    local active_leg = get_active_campaign_leg()
    if active_leg == nil or arrival_icao ~= active_leg.destination_icao then
        return nil
    end

    if active_leg.key_number ~= nil then
        alignment_keys_recovered = math.max(
            alignment_keys_recovered,
            clamp(active_leg.key_number, 1, TOTAL_ALIGNMENT_KEYS))
    end

    if active_leg.assembles_protocol then
        -- A corrupt or manually edited save must never assemble an incomplete
        -- protocol simply because the aircraft arrived at Block Island.
        if alignment_keys_recovered < TOTAL_ALIGNMENT_KEYS then
            latest_story_event =
                "Protocol assembly refused: the complete key set is required."
            return latest_story_event
        end
        alignment_protocol_assembled = true
    end

    if active_leg.completes_campaign then
        if not alignment_protocol_assembled then
            latest_story_event =
                "Final transfer refused: the Alignment Protocol is not assembled."
            return latest_story_event
        end
        campaign_completed = true
        play_optional_campaign_message(
            half_moon_bay_message_sound, "Half Moon Bay message")
    else
        campaign_leg = math.min(TOTAL_CAMPAIGN_LEGS, campaign_leg + 1)
    end

    latest_story_event = active_leg.arrival or
        ("Objective completed at " .. arrival_icao .. ".")
    return latest_story_event
end

-- A new campaign begins with an exact, deliberately scarce fuel load. Clear
-- every simulator tank first so fuel configured in X-Plane cannot carry into
-- the campaign, then balance the starting load across the SF50's two tanks.
local function set_initial_campaign_fuel()
    for tank = 0, 1 do
        xoof_fuel_tanks[tank] = 0
    end

    return add_balanced_fuel(INITIAL_CAMPAIGN_FUEL_KG)
end

------------------------------------------------------------
-- INITIAL AIRPORT
------------------------------------------------------------

local function inspect_available_profile()
    campaign_started = false
    departure_airport = nil
    profile_screen_active = true
    overwrite_confirmation_active = false
    suggested_airports = {}

    available_saved_campaign, available_save_error = load_campaign_save()

    if available_save_error == "invalid" then
        profile_status_message =
            "Saved profile data is invalid. Check X-Plane Log.txt."
    elseif available_saved_campaign ~= nil then
        profile_status_message = "Existing pilot profile detected."
    else
        profile_status_message = "No existing profile detected."
    end
end

-- Leave the active profile without deleting it. Saving first ensures the start
-- page immediately offers the latest campaign state for a later resume. If the
-- save cannot be written, keep the profile open rather than implying that the
-- logout completed safely.
local function return_to_profile_screen()
    if not save_campaign_progress() then
        set_status("Could not save profile. Logout cancelled.")
        return false
    end

    has_been_airborne = false
    current_landing_processed = false
    show_campaign_opening_briefing = false
    active_display_page = DISPLAY_PAGE_MISSION
    reset_satellite_tracking(true)
    inspect_available_profile()
    profile_status_message = "Profile saved. Select a pilot profile to continue."
    return true
end

local function validate_new_profile()
    local cleaned_name = string.match(
        tostring(profile_name_input or ""), "^%s*(.-)%s*$") or ""

    if #cleaned_name < 2 or #cleaned_name > 32
        or string.find(cleaned_name, "[^%w%s%-%']") then
        return nil,
            "Enter a name of 2-32 letters, numbers, spaces, hyphens or apostrophes."
    end

    if not is_required_campaign_aircraft_loaded() then
        return nil, aircraft_requirement_message()
    end

    update_nearest_airport()
    if nearest_airport ~= CAMPAIGN_START_AIRPORT_ICAO
        or not is_number(nearest_airport_distance_km)
        or nearest_airport_distance_km > MAX_AIRPORT_DISTANCE_KM then
        return nil,
            "Load the Cirrus Vision SF50 at NZMO - Manapouri / Te Anau "
            .. "to create a profile."
    end

    local _, aircraft_capacity_kg =
        get_aircraft_remaining_fuel_capacity_kg()
    if aircraft_capacity_kg == nil
        or INITIAL_CAMPAIGN_FUEL_KG > aircraft_capacity_kg then
        return nil, "Starting fuel exceeds the loaded aircraft capacity."
    end

    return { name = cleaned_name }
end

local function create_new_profile()
    local new_profile, validation_error = validate_new_profile()
    if new_profile == nil then
        profile_status_message = validation_error
        return false
    end

    if (available_saved_campaign ~= nil or available_save_error == "invalid")
        and not backup_existing_campaign() then
        profile_status_message =
            "Existing profile backup could not be written. Profile unchanged."
        return false
    end

    pilot_name = new_profile.name
    campaign_starting_fuel_kg = INITIAL_CAMPAIGN_FUEL_KG
    departure_airport = CAMPAIGN_START_AIRPORT_ICAO
    campaign_started = true
    campaign_leg = 1
    alignment_keys_recovered = 1
    alignment_protocol_assembled = false
    campaign_completed = false
    latest_story_event =
        "Alignment Key 1 recovered from the Manapouri bunker."
    show_campaign_opening_briefing = true
    set_initial_campaign_fuel()
    get_or_create_airport_fuel(
        departure_airport, get_longest_runway_metres(departure_airport))

    if not save_campaign_progress() then
        campaign_started = false
        departure_airport = nil
        profile_status_message = "Profile could not be saved. Check X-Plane Log.txt."
        return false
    end

    available_saved_campaign = nil
    available_save_error = nil
    profile_screen_active = false
    overwrite_confirmation_active = false
    refresh_airport_suggestions()
    set_status("Starting airport: NZMO. Select your next hop.")
    play_optional_campaign_message(
        manapouri_message_sound, "Manapouri bunker message")
    return true
end

local function request_new_profile_creation()
    local new_profile, validation_error = validate_new_profile()
    if new_profile == nil then
        profile_status_message = validation_error
        return
    end

    if available_saved_campaign ~= nil or available_save_error == "invalid" then
        overwrite_confirmation_active = true
        profile_status_message = "Confirm replacement of the existing profile."
        return
    end

    create_new_profile()
end

local function load_existing_profile()
    if available_saved_campaign == nil then
        profile_status_message = available_save_error == "invalid"
            and "Saved profile data is invalid. Check X-Plane Log.txt."
            or "No existing profile is available."
        return false
    end

    if not is_required_campaign_aircraft_loaded() then
        profile_status_message = aircraft_requirement_message()
        return false
    end

    update_nearest_airport()
    if nearest_airport ~= available_saved_campaign.current_airport
        or not is_number(nearest_airport_distance_km)
        or nearest_airport_distance_km > MAX_AIRPORT_DISTANCE_KM then
        profile_status_message = "Load the Cirrus Vision SF50 at "
            .. available_saved_campaign.current_airport
            .. " to resume this profile."
        return false
    end

    if not is_valid_destination_airport(
        available_saved_campaign.current_airport) then
        profile_status_message = "Saved airport is unavailable in the airport database."
        return false
    end

    departure_airport = available_saved_campaign.current_airport
    pilot_name = available_saved_campaign.pilot_name
    campaign_starting_fuel_kg = available_saved_campaign.starting_fuel_kg
    campaign_leg = available_saved_campaign.campaign_leg or 1
    alignment_keys_recovered = available_saved_campaign.keys_recovered or 1
    alignment_protocol_assembled =
        available_saved_campaign.protocol_assembled == true
    campaign_completed = available_saved_campaign.campaign_completed == true
    latest_story_event = campaign_completed
        and "Mission complete. Human authorization channels are responding."
        or "Campaign progress restored."
    campaign_started = true
    show_campaign_opening_briefing = false
    restore_saved_fuel(available_saved_campaign.fuel_tanks)
    get_or_create_airport_fuel(
        departure_airport, get_longest_runway_metres(departure_airport))
    profile_screen_active = false
    refresh_airport_suggestions()
    set_status("Campaign resumed at " .. departure_airport
        .. ". Select your next hop.")
    return true
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

            -- Keep the last verified suggestions available after takeoff. The
            -- pilot can request a fresh nearest-airport scan from the fuel
            -- page as the flight progresses, rather than losing useful
            -- diversion information at the moment it is needed most.

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

    local arrival_airport = nearest_airport
    local returned_to_departure = arrival_airport == departure_airport
    local transfer_result

    if RESISTANCE_FULL_FUEL_AIRPORTS[arrival_airport] then
        transfer_result = fill_aircraft_from_resistance(arrival_airport)
    elseif returned_to_departure then
        -- Ordinary depots issue fuel once on first arrival. A local circuit must
        -- not reset or replenish their finite stock.
        touch_airport_fuel_record(arrival_airport)
        transfer_result = {
            icao = arrival_airport,
            depot_before_kg = 0,
            transferred_kg = 0,
            depot_remaining_kg = 0,
            aircraft_total_kg = get_total_fuel(),
            aircraft_full = false,
            return_without_service = true
        }
    else
        transfer_result = transfer_airport_fuel_to_aircraft(arrival_airport)
    end

    if transfer_result == nil then
        local active_leg = get_active_campaign_leg()
        if active_leg == nil
            or active_leg.destination_icao ~= arrival_airport then
            set_status(
                "Airport depot or aircraft capacity unavailable. No fuel delivered."
            )
            return
        end

        -- Story qualification depends on a verified safe arrival, not on depot
        -- metadata. Preserve progression if fuel capacity or depot data happens
        -- to be unavailable, while explicitly reporting that no fuel moved.
        transfer_result = {
            icao = arrival_airport,
            depot_before_kg = 0,
            transferred_kg = 0,
            depot_remaining_kg = 0,
            aircraft_total_kg = get_total_fuel(),
            aircraft_full = false,
            fuel_data_unavailable = true
        }
    end

    last_fuel_transfer = transfer_result

    departure_airport = arrival_airport
    local story_event = process_story_arrival(arrival_airport)

    if save_campaign_progress() then
        if story_event ~= nil then
            if transfer_result.fuel_data_unavailable then
                set_status(story_event .. " Fuel service unavailable; progress saved.")
            elseif transfer_result.resistance_service then
                set_status(story_event .. " Resistance tanks filled the SF50.")
            else
                set_status(story_event .. " Progress saved.")
            end
        elseif transfer_result.resistance_service then
            set_status(string.format(
                "Resistance service at %s. SF50 filled to %.0f kg.",
                arrival_airport, transfer_result.aircraft_total_kg))
        elseif transfer_result.return_without_service then
            set_status("Returned to " .. arrival_airport
                .. ". This airport has no new fuel.")
        elseif transfer_result.depot_before_kg <= 0 then
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

-- FlyWithLua's ImGui binding exposes plain labels as TextUnformatted. Prefer
-- that function so percent signs and other mission text are never interpreted
-- as formatting tokens. The Text fallback keeps compatibility with bindings
-- that expose only the upstream ImGui name.
local function mission_computer_text(value)
    if imgui == nil then
        return
    end

    local resolved_text = tostring(value or "")
    if type(imgui.TextUnformatted) == "function" then
        imgui.TextUnformatted(resolved_text)
    elseif type(imgui.Text) == "function" then
        imgui.Text(resolved_text)
    end
end

-- Important access-screen information uses restrained semantic colours:
-- green confirms a usable state, amber identifies a required pilot action and
-- red reports a fault which prevents the requested operation. Fall back to
-- ordinary text when an older ImGui binding does not expose TextColored.
local function mission_computer_colored_text(value, red, green, blue)
    if imgui ~= nil and type(imgui.TextColored) == "function" then
        imgui.TextColored(
            safe_number(red, 1.0),
            safe_number(green, 1.0),
            safe_number(blue, 1.0),
            1.0,
            tostring(value or "")
        )
        return
    end

    mission_computer_text(value)
end

local function profile_status_text(value)
    local resolved_text = tostring(value or "")
    local is_fault = string.find(resolved_text, "invalid", 1, true) ~= nil
        or string.find(resolved_text, "unavailable", 1, true) ~= nil
        or string.find(resolved_text, "could not", 1, true) ~= nil
        or string.find(resolved_text, "Load the ", 1, true) == 1
        or string.find(resolved_text, "Position the aircraft", 1, true) == 1
    local is_confirmation = string.find(
        resolved_text, "Existing pilot profile detected.", 1, true) ~= nil
        or string.find(resolved_text, "Profile saved.", 1, true) ~= nil

    if is_fault then
        mission_computer_colored_text(resolved_text, 1.0, 0.15, 0.15)
        return
    end

    if is_confirmation then
        mission_computer_colored_text(resolved_text, 0.20, 0.90, 0.42)
        return
    end

    mission_computer_text(resolved_text)
end

local function mission_computer_separator()
    if imgui ~= nil and type(imgui.Separator) == "function" then
        imgui.Separator()
    end
end

local function mission_emergency_text(value)
    local resolved_text = tostring(value or "")
    if imgui ~= nil and type(imgui.TextColored) == "function" then
        imgui.TextColored(1.0, 0.18, 0.12, 1.0, resolved_text)
        return
    end

    mission_computer_text(resolved_text)
end

-- Time-critical tracking information is mirrored on the main page so the
-- pilot is never required to discover a lock by changing tabs. Aircraft
-- damage takes priority and remains visible after the short impact alert ends.
local function build_mission_satellite_emergency()
    if satellite_electrical_fire_damage_active then
        mission_emergency_text("[EMERGENCY] ACTIVE AIRCRAFT DAMAGE")
        mission_emergency_text(
            "ENGINE FIRE | ELECTRICAL BUS 1 OFFLINE | BUS 2 OFFLINE"
        )
        mission_emergency_text("LAND AT THE NEAREST SUITABLE AIRFIELD")
        mission_computer_separator()
        return
    end

    if satellite_state ~= "LOCKED" then
        return
    end

    local seconds_remaining = 0
    if satellite_next_event_time ~= nil then
        seconds_remaining = math.max(
            0,
            math.ceil(satellite_next_event_time - satellite_event_time)
        )
    end

    mission_emergency_text("[DANGER] DIRECTED-ENERGY TRACKING LOCK")
    mission_emergency_text(string.format(
        "STRIKE SOLUTION FORMING | IMPACT WINDOW %d SEC",
        seconds_remaining
    ))
    mission_emergency_text(
        "DESCEND BELOW 1,000 FT AGL OR LEAVE COVERAGE"
    )
    mission_computer_separator()
end

local function build_opening_briefing_page()
    mission_computer_text("CAMPAIGN OPENING BRIEFING // 06 JAN 2030")
    mission_computer_separator()

    for _, briefing_line in ipairs(OPENING_BRIEFING_LINES) do
        mission_computer_text(briefing_line)
    end

    mission_computer_separator()
    mission_computer_text("PROLOGUE // THE MANAPOURI BUNKER")
    mission_computer_text("Alignment Key 1 recovered from the shielded case.")
    mission_computer_text("Recorded-message placeholder: manapouri_bunker_message.wav")
    mission_computer_text("")
    mission_computer_text("LEG 1 / 11 // THE DITCH")
    mission_computer_text(
        "Fly from NZMO to YSNF Norfolk Island Airport."
    )
    mission_computer_text(
        "Resistance ground crew at YSNF guarantee full fuel on every visit."
    )
    mission_computer_text(
        "The second resistance fuel cell is waiting at YLHI Lord Howe Island."
    )
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

    build_mission_satellite_emergency()
    mission_computer_text("MISSION STATUS")
    mission_computer_separator()
    if campaign_completed then
        mission_computer_text("THE ALIGNMENT PROTOCOL // COMPLETE")
        mission_computer_text("FINAL LOCATION: KHAF Half Moon Bay")
        mission_computer_text("Autonomous infrastructure authority suspended.")
        mission_computer_text("Human authorization channels are responding.")
    else
        local active_leg = get_active_campaign_leg()
        if active_leg ~= nil then
            mission_computer_text(string.format(
                "LEG %d / %d: %s - %s",
                campaign_leg, TOTAL_CAMPAIGN_LEGS,
                active_leg.destination_icao, active_leg.destination_name))
            mission_computer_text("OBJECTIVE: " .. active_leg.objective)
            if RESISTANCE_FULL_FUEL_AIRPORTS[active_leg.destination_icao] then
                mission_computer_text(
                    "FUEL ASSURANCE: Full resistance refuel available on every visit")
            end
        else
            mission_computer_text("CAMPAIGN OBJECTIVE UNAVAILABLE")
        end
    end
    mission_computer_text("KEYS RECOVERED: "
        .. tostring(alignment_keys_recovered) .. " / "
        .. tostring(TOTAL_ALIGNMENT_KEYS))
    mission_computer_text("LATEST: " .. tostring(latest_story_event))
    mission_computer_text(
        is_required_campaign_aircraft_loaded()
            and status_message
            or aircraft_requirement_message()
    )
    mission_computer_text(
        "CURRENT AIRPORT: " .. tostring(departure_airport or "UNCONFIRMED")
    )
end

-- Keep all operational fuel information together on the fuel page. This
-- leaves the mission page focused on the current story objective while pilots
-- can review tank balance, the latest depot transfer and possible next hops in
-- one place.
local function build_fuel_status()
    mission_computer_text("FUEL STATUS")
    mission_computer_separator()
    mission_computer_text(string.format(
        "TOTAL %.0f KG | LEFT %.0f KG | RIGHT %.0f KG",
        get_total_fuel(),
        number_or_zero(xoof_fuel_tanks[0]),
        number_or_zero(xoof_fuel_tanks[1])
    ))
    mission_computer_text(
        "CURRENT AIRPORT: " .. tostring(departure_airport or "UNCONFIRMED")
    )

    if last_fuel_transfer ~= nil then
        if last_fuel_transfer.resistance_service then
            mission_computer_text("")
            mission_computer_text(string.format(
                "RESISTANCE SERVICE %s | TRANSFERRED %.0f KG",
                tostring(last_fuel_transfer.icao or "UNKNOWN"),
                number_or_zero(last_fuel_transfer.transferred_kg)))
            mission_computer_text("UNLIMITED SAFE-HAVEN SUPPLY | AIRCRAFT TANKS FULL")
            return
        end
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

    -- The threat model uses independent rolls at discrete deadlines rather
    -- than a continuously increasing danger meter. Showing the live state,
    -- deadline and most recent rolls makes that behaviour reproducible during
    -- play-testing without presenting a misleading accumulated percentage.
    mission_computer_text("")
    mission_computer_separator()
    mission_computer_text("TEST TELEMETRY")
    mission_computer_text("State: " .. tostring(satellite_state or "UNKNOWN"))

    if satellite_source_icao ~= nil then
        mission_computer_text(string.format(
            "Source: %s / %s",
            tostring(satellite_source_icao),
            tostring(satellite_source_class or "UNKNOWN")
        ))
    else
        mission_computer_text("Source: NONE")
    end

    mission_computer_text(string.format(
        "Acquisition chance: %.0f%% per check | Checks: %d",
        math.max(0, safe_number(satellite_acquisition_chance, 0)) * 100,
        math.max(0, safe_number(satellite_acquisition_check_count, 0))
    ))
    mission_computer_text(string.format(
        "Hit chance after lock: %.0f%%",
        math.max(0, safe_number(satellite_hit_chance, 0)) * 100
    ))

    if satellite_next_event_time ~= nil then
        local remaining_seconds = math.max(
            0,
            math.ceil(
                safe_number(satellite_next_event_time, satellite_event_time)
                    - safe_number(satellite_event_time, 0)
            )
        )
        local deadline_label = "Next event"
        if satellite_state == "WAITING" then
            deadline_label = "Next acquisition check"
        elseif satellite_state == "LOCKED" then
            deadline_label = "Strike solution"
        elseif satellite_state == "COOLDOWN" then
            deadline_label = "Cooldown remaining"
        end
        mission_computer_text(string.format(
            "%s: %d seconds",
            deadline_label,
            remaining_seconds
        ))
    else
        mission_computer_text("Next event: NOT SCHEDULED")
    end

    local masking_status = aircraft_is_above_satellite_masking_altitude()
        and "EXPOSED" or "ACTIVE"
    mission_computer_text("Terrain masking: " .. masking_status)

    if satellite_last_acquisition_roll ~= nil then
        local acquisition_result = satellite_last_acquisition_roll
                < satellite_acquisition_chance
            and "ACQUIRED" or "NOT ACQUIRED"
        mission_computer_text(string.format(
            "Last acquisition roll: %.3f / below %.3f - %s",
            satellite_last_acquisition_roll,
            satellite_acquisition_chance,
            acquisition_result
        ))
    else
        mission_computer_text("Last acquisition roll: NONE")
    end

    if satellite_last_hit_roll ~= nil then
        local hit_result = satellite_last_hit_roll < satellite_hit_chance
            and "HIT" or "MISS"
        mission_computer_text(string.format(
            "Last hit roll: %.3f / below %.3f - %s",
            satellite_last_hit_roll,
            satellite_hit_chance,
            hit_result
        ))
    else
        mission_computer_text("Last hit roll: NONE")
    end
end

local function build_hops_page()
    mission_computer_text("SUGGESTED NEXT HOPS")
    mission_computer_separator()

    -- A full X-Plane nav-aid scan is deliberately pilot-initiated in flight:
    -- it avoids repeatedly performing an expensive search in the update loop,
    -- while allowing the displayed three airports to follow the aircraft.
    if imgui ~= nil
        and type(imgui.Button) == "function"
        and imgui.Button("UPDATE NEAREST 3", 190, 30) then
        refresh_airport_suggestions()
    end
    mission_computer_text(
        xoof_on_ground == 0
            and "IN-FLIGHT LIST RETAINED // Update on demand as position changes."
            or "Update on demand to recalculate from the present position."
    )
    mission_computer_text("")

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

local function build_fuel_page()
    build_fuel_status()
    mission_computer_text("")
    build_hops_page()
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

    if profile_screen_active then
        mission_computer_text("MISSION COMPUTER ACCESS")
        profile_status_text(profile_status_message)
        mission_computer_separator()

        mission_computer_text("CREATE NEW PILOT PROFILE")
        mission_computer_colored_text(
            "FLIGHT SETUP REQUIRED", 1.0, 0.72, 0.20)
        mission_computer_colored_text(
            "Load the Cirrus Vision SF50 at NZMO - Manapouri / Te Anau,",
            1.0, 0.72, 0.20)
        mission_computer_colored_text(
            "New Zealand, before creating a pilot profile.",
            1.0, 0.72, 0.20)
        mission_computer_text("")
        if type(imgui.InputText) == "function" then
            local first_value, second_value = imgui.InputText(
                "NAME", profile_name_input, 33)
            if type(first_value) == "string" then
                profile_name_input = first_value
            elseif type(second_value) == "string" then
                profile_name_input = second_value
            end
        else
            mission_computer_text("Name entry unavailable: ImGui InputText missing.")
        end

        mission_computer_text("AIRCRAFT: CIRRUS VISION SF50")
        mission_computer_text(string.format(
            "INITIAL FUEL: %d KG", INITIAL_CAMPAIGN_FUEL_KG))

        if overwrite_confirmation_active then
            mission_computer_text("")
            mission_computer_text("AN EXISTING PROFILE WILL BE REPLACED")
            if imgui.Button("CANCEL", 150, 30) then
                overwrite_confirmation_active = false
                profile_status_message = "Profile replacement cancelled."
            end
            if type(imgui.SameLine) == "function" then imgui.SameLine() end
            if imgui.Button("REPLACE PROFILE", 190, 30) then
                create_new_profile()
            end
        elseif imgui.Button("CREATE PILOT", 190, 30) then
            request_new_profile_creation()
        end

        mission_computer_separator()
        mission_computer_text("LOAD EXISTING PROFILE")
        if available_saved_campaign ~= nil then
            local saved_fuel_total = 0
            for tank = 0, 1 do
                saved_fuel_total = saved_fuel_total
                    + number_or_zero(available_saved_campaign.fuel_tanks[tank])
            end
            mission_computer_text("PILOT: "
                .. tostring(available_saved_campaign.pilot_name))
            mission_computer_colored_text(string.format(
                "RESUME LOCATION REQUIRED: %s",
                available_saved_campaign.current_airport),
                1.0, 0.72, 0.20)
            mission_computer_colored_text(
                "Load the Cirrus Vision SF50 there before loading this profile.",
                1.0, 0.72, 0.20)
            mission_computer_text(string.format(
                "SAVED FUEL: %.0f KG", saved_fuel_total))
            if imgui.Button("LOAD PROFILE", 190, 30) then
                load_existing_profile()
            end
        else
            mission_computer_text(available_save_error == "invalid"
                and "PROFILE DATA COULD NOT BE VERIFIED"
                or "NO EXISTING PROFILE DETECTED")
        end
        return
    end

    mission_computer_text("PILOT: " .. tostring(pilot_name or "UNKNOWN PILOT")
        .. " | PROFILE ACTIVE")
    if imgui.Button("LOG OUT", 125, 30) then
        return_to_profile_screen()
        return
    end
    mission_computer_text("Saves progress and returns to mission computer access.")
    mission_computer_separator()

    for index, tab in ipairs(DISPLAY_TABS) do
        local button_label = tab.label
        if active_display_page == tab.page then
            button_label = "[ " .. tab.label .. " ]"
        end

        -- Five restrained navigation buttons fit on the initial 720 px panel.
        if imgui.Button(button_label, 125, 30) then
            active_display_page = tab.page
        end

        if index < #DISPLAY_TABS and type(imgui.SameLine) == "function" then
            imgui.SameLine()
        end
    end

    mission_computer_separator()

    if active_display_page == DISPLAY_PAGE_HOPS then
        build_fuel_page()
    elseif active_display_page == DISPLAY_PAGE_SATELLITE then
        build_satellite_page()
    elseif active_display_page == DISPLAY_PAGE_MAINTENANCE then
        mission_computer_text("MAINTENANCE")
        mission_computer_separator()
        mission_computer_text("Aircraft condition data is not yet available.")
    elseif active_display_page == DISPLAY_PAGE_KEYS then
        mission_computer_text("ALIGNMENT KEYS")
        mission_computer_separator()
        mission_computer_text("RECOVERED: "
            .. tostring(alignment_keys_recovered) .. " / "
            .. tostring(TOTAL_ALIGNMENT_KEYS))
        for key_number = 1, TOTAL_ALIGNMENT_KEYS do
            local key_status = key_number <= alignment_keys_recovered
                and "RECOVERED" or "OUTSTANDING"
            mission_computer_text(string.format(
                "KEY %d // %s", key_number, key_status))
        end
        mission_computer_text("")
        mission_computer_text("ALIGNMENT PROTOCOL: "
            .. (alignment_protocol_assembled and "ASSEMBLED" or "NOT ASSEMBLED"))
        mission_computer_text("FINAL TRANSFER: "
            .. (campaign_completed and "ACCEPTED" or "PENDING"))
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
        logMsg("[X2030] Mission computer unavailable: floating-window API missing")
        return
    end

    display_tab_window = float_wnd_create(
        DISPLAY_WINDOW_WIDTH,
        DISPLAY_WINDOW_HEIGHT,
        1,
        true
    )

    if display_tab_window == nil then
        logMsg("[X2030] Mission computer unavailable: window creation failed")
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
    inspect_available_profile()
else
    set_status(
        "Airport database failed to load. "
        .. "Check X-Plane Log.txt."
    )
end

logMsg(
    "[X2030] "
    .. "Prototype 0.9 satellite strike damage system loaded."
)
