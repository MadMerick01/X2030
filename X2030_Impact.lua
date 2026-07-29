-- X2030 satellite impact impulse
--
-- This module owns the short-lived flight-model disturbance caused by a
-- successful directed-energy strike. Campaign decisions remain in X2030.lua;
-- this file only selects a virtual SF50 impact point and applies the resulting
-- additive X-Plane plugin forces and moments.

-- FlyWithLua may scan this file independently after X2030.lua has already
-- loaded it with dofile. Do not bind the datarefs or replace active state twice.
if type(X2030Impact) == "table" and X2030Impact.module_loaded then
    return X2030Impact
end

X2030Impact = {}
X2030Impact.module_loaded = true

------------------------------------------------------------
-- X-PLANE DATAREFS
------------------------------------------------------------

-- X-Plane clears the plugin-force accumulators during each flight-model cycle.
-- Add this module's contribution instead of replacing the value so it remains
-- compatible with other plugins that may contribute forces in the same frame.
dataref(
    "x2030_impact_side_force",
    "sim/flightmodel/forces/fside_plug_acf",
    "writable"
)

dataref(
    "x2030_impact_normal_force",
    "sim/flightmodel/forces/fnrml_plug_acf",
    "writable"
)

dataref(
    "x2030_impact_axial_force",
    "sim/flightmodel/forces/faxil_plug_acf",
    "writable"
)

dataref(
    "x2030_impact_roll_moment",
    "sim/flightmodel/forces/L_plug_acf",
    "writable"
)

dataref(
    "x2030_impact_pitch_moment",
    "sim/flightmodel/forces/M_plug_acf",
    "writable"
)

dataref(
    "x2030_impact_yaw_moment",
    "sim/flightmodel/forces/N_plug_acf",
    "writable"
)

dataref(
    "x2030_impact_on_ground",
    "sim/flightmodel/failures/onground_any",
    "readonly"
)

dataref(
    "x2030_impact_sim_time",
    "sim/time/total_running_time_sec",
    "readonly"
)

dataref(
    "x2030_impact_sim_paused",
    "sim/time/paused",
    "readonly"
)

------------------------------------------------------------
-- IMPACT MODEL
------------------------------------------------------------

local PULSE_DURATION_SECONDS = 0.24
local MINIMUM_DOWNWARD_FORCE_NEWTONS = 38000
local MAXIMUM_DOWNWARD_FORCE_NEWTONS = 50000
local MINIMUM_SIDE_FORCE_RATIO = 0.12
local MAXIMUM_SIDE_FORCE_RATIO = 0.28

-- A rigid point-load calculation is too severe because a real airframe also
-- distributes and absorbs impact energy. These response factors retain the
-- direction implied by the virtual hit point while keeping the SF50 normally
-- recoverable at a safe altitude.
local ROLL_RESPONSE_FACTOR = 0.16
local PITCH_RESPONSE_FACTOR = 0.10
local YAW_RESPONSE_FACTOR = 0.12
local MAXIMUM_ROLL_MOMENT_NM = 30000
local MAXIMUM_PITCH_MOMENT_NM = 18000
local MAXIMUM_YAW_MOMENT_NM = 10000

-- Coordinates are restrained virtual offsets from the centre of gravity, in
-- aircraft axes: X is positive right and Z is positive aft. Weighted zones
-- make central hits most common and avoid extreme wing-tip lever arms.
local IMPACT_ZONES = {
    {
        name = "CENTRE FUSELAGE",
        weight = 30,
        minimum_x = -0.35,
        maximum_x = 0.35,
        minimum_z = -0.50,
        maximum_z = 0.50
    },
    {
        name = "LEFT INNER WING",
        weight = 20,
        minimum_x = -3.20,
        maximum_x = -1.80,
        minimum_z = -0.50,
        maximum_z = 0.50
    },
    {
        name = "RIGHT INNER WING",
        weight = 20,
        minimum_x = 1.80,
        maximum_x = 3.20,
        minimum_z = -0.50,
        maximum_z = 0.50
    },
    {
        name = "FORWARD FUSELAGE",
        weight = 15,
        minimum_x = -0.50,
        maximum_x = 0.50,
        minimum_z = -3.00,
        maximum_z = -1.50
    },
    {
        name = "REAR FUSELAGE",
        weight = 15,
        minimum_x = -0.50,
        maximum_x = 0.50,
        minimum_z = 2.00,
        maximum_z = 4.00
    }
}

local impact_active = false
local impact_started_at = nil
local peak_side_force = 0
local peak_normal_force = 0
local peak_roll_moment = 0
local peak_pitch_moment = 0
local peak_yaw_moment = 0

local function is_finite_number(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function finite_number_or_zero(value)
    if is_finite_number(value) then
        return value
    end

    return 0
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function random_between(minimum, maximum)
    return minimum + ((maximum - minimum) * math.random())
end

local function choose_impact_zone()
    local total_weight = 0
    for _, zone in ipairs(IMPACT_ZONES) do
        total_weight = total_weight + zone.weight
    end

    local selection = math.random() * total_weight
    local accumulated_weight = 0
    for _, zone in ipairs(IMPACT_ZONES) do
        accumulated_weight = accumulated_weight + zone.weight
        if selection < accumulated_weight then
            return zone
        end
    end

    -- Floating-point rounding should never reach this fallback, but returning
    -- a valid central zone keeps a future malformed weight table harmless.
    return IMPACT_ZONES[1]
end

local function clear_impact_state()
    impact_active = false
    impact_started_at = nil
    peak_side_force = 0
    peak_normal_force = 0
    peak_roll_moment = 0
    peak_pitch_moment = 0
    peak_yaw_moment = 0
end

local function add_force_or_moment(current_value, contribution)
    if not is_finite_number(contribution) then
        return finite_number_or_zero(current_value)
    end

    return finite_number_or_zero(current_value) + contribution
end

-- A half-sine envelope starts and ends at zero without spreading the impact
-- over a frame-count-dependent duration.
local function pulse_envelope(elapsed_seconds)
    local progress = clamp(elapsed_seconds / PULSE_DURATION_SECONDS, 0, 1)
    return math.sin(math.pi * progress)
end

function X2030Impact.start()
    local start_time = tonumber(x2030_impact_sim_time)
    if not is_finite_number(start_time)
        or finite_number_or_zero(x2030_impact_on_ground) ~= 0
        or finite_number_or_zero(x2030_impact_sim_paused) ~= 0 then
        return false
    end

    local zone = choose_impact_zone()
    local hit_x = random_between(zone.minimum_x, zone.maximum_x)
    local hit_z = random_between(zone.minimum_z, zone.maximum_z)
    local downward_force = random_between(
        MINIMUM_DOWNWARD_FORCE_NEWTONS,
        MAXIMUM_DOWNWARD_FORCE_NEWTONS
    )
    local side_direction = math.random() < 0.5 and -1 or 1

    peak_normal_force = -downward_force
    peak_side_force = side_direction
        * downward_force
        * random_between(MINIMUM_SIDE_FORCE_RATIO, MAXIMUM_SIDE_FORCE_RATIO)

    -- With X positive right and Z positive aft, a downward strike on the right
    -- wing rolls right; a tail strike pitches up. A lateral tail shove yaws the
    -- nose in the opposite direction. Clamp every result independently.
    peak_roll_moment = clamp(
        -hit_x * peak_normal_force * ROLL_RESPONSE_FACTOR,
        -MAXIMUM_ROLL_MOMENT_NM,
        MAXIMUM_ROLL_MOMENT_NM
    )
    peak_pitch_moment = clamp(
        -hit_z * peak_normal_force * PITCH_RESPONSE_FACTOR,
        -MAXIMUM_PITCH_MOMENT_NM,
        MAXIMUM_PITCH_MOMENT_NM
    )
    peak_yaw_moment = clamp(
        -hit_z * peak_side_force * YAW_RESPONSE_FACTOR,
        -MAXIMUM_YAW_MOMENT_NM,
        MAXIMUM_YAW_MOMENT_NM
    )

    impact_started_at = start_time
    impact_active = true

    if type(logMsg) == "function" then
        logMsg(string.format(
            "[X2030 IMPACT] %s at X %.2f m / Z %.2f m; "
                .. "peak force side %.0f N / down %.0f N; "
                .. "moment roll %.0f / pitch %.0f / yaw %.0f Nm.",
            zone.name,
            hit_x,
            hit_z,
            peak_side_force,
            peak_normal_force,
            peak_roll_moment,
            peak_pitch_moment,
            peak_yaw_moment
        ))
    end

    return true
end

function X2030Impact.update()
    if not impact_active then
        return
    end

    local current_time = tonumber(x2030_impact_sim_time)
    if not is_finite_number(current_time)
        or not is_finite_number(impact_started_at)
        or finite_number_or_zero(x2030_impact_on_ground) ~= 0 then
        clear_impact_state()
        return
    end

    -- Cancel rather than preserving a sub-quarter-second force across a menu
    -- pause. This prevents a stale impulse resuming unexpectedly later.
    if finite_number_or_zero(x2030_impact_sim_paused) ~= 0 then
        clear_impact_state()
        return
    end

    local elapsed_seconds = current_time - impact_started_at
    if elapsed_seconds < 0 or elapsed_seconds >= PULSE_DURATION_SECONDS then
        clear_impact_state()
        return
    end

    local envelope = pulse_envelope(elapsed_seconds)
    x2030_impact_side_force = add_force_or_moment(
        x2030_impact_side_force,
        peak_side_force * envelope
    )
    x2030_impact_normal_force = add_force_or_moment(
        x2030_impact_normal_force,
        peak_normal_force * envelope
    )
    -- No axial pulse is currently intended. Retaining the bound dataref keeps
    -- the three-axis interface explicit for later flight testing.
    x2030_impact_axial_force = add_force_or_moment(
        x2030_impact_axial_force,
        0
    )
    x2030_impact_roll_moment = add_force_or_moment(
        x2030_impact_roll_moment,
        peak_roll_moment * envelope
    )
    x2030_impact_pitch_moment = add_force_or_moment(
        x2030_impact_pitch_moment,
        peak_pitch_moment * envelope
    )
    x2030_impact_yaw_moment = add_force_or_moment(
        x2030_impact_yaw_moment,
        peak_yaw_moment * envelope
    )
end

function X2030Impact.cancel()
    clear_impact_state()
end

function X2030Impact.is_active()
    return impact_active
end

return X2030Impact
