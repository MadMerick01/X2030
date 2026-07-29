-- X2030 downward-only satellite impact impulse
--
-- This deliberately small module applies one short downward force to the SF50.
-- Campaign decisions, aircraft eligibility and damage remain in X2030.lua.

-- FlyWithLua may scan this file independently after X2030.lua has loaded it
-- with dofile. Do not bind the datarefs or replace active state twice.
if type(X2030Impact) == "table"
    and X2030Impact.module_name == "downward_only" then
    return X2030Impact
end

X2030Impact = {}
X2030Impact.module_loaded = true
X2030Impact.module_name = "downward_only"

------------------------------------------------------------
-- X-PLANE DATAREFS
------------------------------------------------------------

-- X-Plane clears this additive accumulator during each flight-model cycle.
-- Add our contribution rather than replacing it so other plugins remain free
-- to contribute their own normal forces during the same frame.
dataref(
    "x2030_downward_impact_normal_force",
    "sim/flightmodel/forces/fnrml_plug_acf",
    "writable"
)

dataref(
    "x2030_downward_impact_on_ground",
    "sim/flightmodel/failures/onground_any",
    "readonly"
)

dataref(
    "x2030_downward_impact_sim_time",
    "sim/time/total_running_time_sec",
    "readonly"
)

dataref(
    "x2030_downward_impact_sim_paused",
    "sim/time/paused",
    "readonly"
)

------------------------------------------------------------
-- DOWNWARD PULSE
------------------------------------------------------------

-- Keep the first diagnostic version deterministic. A fixed force makes flight
-- tests repeatable while the multi-monitor mouse-input issue is investigated.
local PULSE_DURATION_SECONDS = 0.24
local PEAK_DOWNWARD_FORCE_NEWTONS = 44000

local impact_active = false
local impact_started_at = nil

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

local function clear_impact_state()
    impact_active = false
    impact_started_at = nil
end

-- A half-sine envelope makes the short shove begin and end at zero. Its timing
-- is based on simulator time rather than frame count, so frame rate does not
-- change the intended pulse duration.
local function pulse_envelope(elapsed_seconds)
    local progress = clamp(elapsed_seconds / PULSE_DURATION_SECONDS, 0, 1)
    return math.sin(math.pi * progress)
end

function X2030Impact.start()
    local start_time = tonumber(x2030_downward_impact_sim_time)
    if not is_finite_number(start_time)
        or finite_number_or_zero(x2030_downward_impact_on_ground) ~= 0
        or finite_number_or_zero(x2030_downward_impact_sim_paused) ~= 0 then
        return false
    end

    impact_started_at = start_time
    impact_active = true

    if type(logMsg) == "function" then
        logMsg(string.format(
            "[X2030 IMPACT] Downward-only pulse started; peak %.0f N for %.2f sec.",
            PEAK_DOWNWARD_FORCE_NEWTONS,
            PULSE_DURATION_SECONDS
        ))
    end

    return true
end

function X2030Impact.update()
    if not impact_active then
        return
    end

    local current_time = tonumber(x2030_downward_impact_sim_time)
    if not is_finite_number(current_time)
        or not is_finite_number(impact_started_at)
        or finite_number_or_zero(x2030_downward_impact_on_ground) ~= 0
        or finite_number_or_zero(x2030_downward_impact_sim_paused) ~= 0 then
        clear_impact_state()
        return
    end

    local elapsed_seconds = current_time - impact_started_at
    if elapsed_seconds < 0 or elapsed_seconds >= PULSE_DURATION_SECONDS then
        clear_impact_state()
        return
    end

    local downward_contribution = -PEAK_DOWNWARD_FORCE_NEWTONS
        * pulse_envelope(elapsed_seconds)
    x2030_downward_impact_normal_force =
        finite_number_or_zero(x2030_downward_impact_normal_force)
        + downward_contribution
end

function X2030Impact.cancel()
    clear_impact_state()
end

function X2030Impact.is_active()
    return impact_active
end

return X2030Impact
