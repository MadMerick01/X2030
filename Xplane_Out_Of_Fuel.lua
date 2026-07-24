-- Xplane Out Of Fuel
-- Prototype 0.3
-- Airport-to-airport fuel system and next-hop suggestions

local PLUGIN_NAME = "Xplane Out Of Fuel"

------------------------------------------------------------
-- GAME SETTINGS
------------------------------------------------------------

local FUEL_GRANT_KG = 50
local FUEL_PER_TANK_KG = FUEL_GRANT_KG / 2

local STOPPED_SPEED_MPS = 1.0
local MAX_AIRPORT_DISTANCE_KM = 5.0

-- Approximate flight-planning assumptions
local ESTIMATED_AVERAGE_SPEED_KT = 180
local ESTIMATED_FUEL_FLOW_KG_PER_MIN = 2.5
local DEPARTURE_FUEL_ALLOWANCE_KG = 8

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

local departure_airport = nil
local nearest_airport = nil
local nearest_airport_name = nil
local nearest_airport_distance_km = nil

local suggested_airports = {}
-- Airport identifiers confirmed as land airports
-- with at least one conventional runway.
local valid_land_airports = {}
local airport_database_loaded = false

local status_message =
    "Initialising airport detection..."

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

    local function save_current_airport()
        if current_airport_icao ~= nil
            and current_airport_is_land
            and current_airport_has_runway then

            valid_land_airports[
                current_airport_icao
            ] = true
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

        elseif row_code == 100
            and current_airport_is_land then

            -- Row 100 describes a conventional land runway.
            current_airport_has_runway = true
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

    return valid_land_airports[icao] == true
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
                        available_fuel =
                            FUEL_GRANT_KG
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
        if xoof_fuel_tanks[tank] ~= nil then
            total_fuel =
                total_fuel
                +
                xoof_fuel_tanks[tank]
        end
    end

    return total_fuel
end

local function add_balanced_fuel()
    xoof_fuel_tanks[0] =
        xoof_fuel_tanks[0]
        +
        FUEL_PER_TANK_KG

    xoof_fuel_tanks[1] =
        xoof_fuel_tanks[1]
        +
        FUEL_PER_TANK_KG
end

------------------------------------------------------------
-- INITIAL AIRPORT
------------------------------------------------------------

local function initialise_departure_airport()
    update_nearest_airport()

    if nearest_airport == nil then
        set_status(
            "No airport could be identified."
        )

        return
    end

    if nearest_airport_distance_km
        >
        MAX_AIRPORT_DISTANCE_KM then

        set_status(
            string.format(
                "Nearest airport is %s, "
                .. "but it is %.1f km away.",
                nearest_airport,
                nearest_airport_distance_km
            )
        )

        return
    end

    departure_airport =
        nearest_airport

    set_status(
        string.format(
            "Starting airport: %s. "
            .. "Select your next hop.",
            departure_airport
        )
    )

    refresh_airport_suggestions()
end

------------------------------------------------------------
-- MAIN GAME LOGIC
------------------------------------------------------------

function xoof_update()
    local engine_is_running =
        xoof_engine_running[0] == 1

    if xoof_on_ground == 0 then
        if not has_been_airborne then
            has_been_airborne = true
            current_landing_processed =
                false

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

    if nearest_airport_distance_km
        >
        MAX_AIRPORT_DISTANCE_KM then

        set_status(
            string.format(
                "%s is %.1f km away. "
                .. "No fuel delivered.",
                nearest_airport,
                nearest_airport_distance_km
            )
        )

        return
    end

    if nearest_airport
        ==
        departure_airport then

        set_status(
            "Returned to "
            .. nearest_airport
            .. ". This airport has no new fuel."
        )

        has_been_airborne = false

        refresh_airport_suggestions()

        return
    end

    add_balanced_fuel()

    local arrival_airport =
        nearest_airport

    set_status(
        string.format(
            "Arrived %s. "
            .. "Fuel delivered: 25 kg per tank.",
            arrival_airport
        )
    )

    departure_airport =
        arrival_airport

    has_been_airborne = false

    refresh_airport_suggestions()
end

------------------------------------------------------------
-- DISPLAY
------------------------------------------------------------

function xoof_draw()
    local starting_y =
        SCREEN_HIGHT - 60

    draw_string_Helvetica_18(
        40,
        starting_y,
        PLUGIN_NAME
    )

    draw_string_Helvetica_12(
        40,
        starting_y - 25,
        status_message
    )

    draw_string_Helvetica_12(
        40,
        starting_y - 45,
        string.format(
            "Fuel: %.0f kg | "
            .. "Left: %.0f | Right: %.0f",
            get_total_fuel(),
            xoof_fuel_tanks[0],
            xoof_fuel_tanks[1]
        )
    )

    if departure_airport ~= nil then
        draw_string_Helvetica_12(
            40,
            starting_y - 65,
            "Current airport: "
            .. departure_airport
        )
    end

    draw_string_Helvetica_18(
        40,
        starting_y - 100,
        "SUGGESTED NEXT HOPS"
    )

    for index = 1, 3 do
        local airport =
            suggested_airports[index]

        local line_y =
            starting_y
            -
            100
            -
            (index * 25)

        if airport ~= nil then
            local affordability

            if get_total_fuel()
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
                    .. "DEPOT 50 KG | %s",
                    index,
                    airport.icao,
                    airport.distance_nm,
                    airport.heading,
                    airport.required_fuel,
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

------------------------------------------------------------
-- START SCRIPT
------------------------------------------------------------

do_often("xoof_update()")
do_every_draw("xoof_draw()")

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
    .. "Prototype 0.3 airport filter loaded."
)