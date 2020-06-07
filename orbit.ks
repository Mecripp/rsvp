@lazyglobal off.
runoncepath("kos-launch-window-finder/lambert.ks").

// Calculates the transfer time of an idealised Hohmann transfer between
// two planets. This only needs to be approximate in order to provide an inital
// guess when searching the porkchop plot provided by the Lambert solver.
//
// Simplifying assumptions:
// * Both planet's orbits are circular (eccentricity is ignored).
// * Transfer angle is exactly 180 degress.
//
// This implies that the idealised transfer orbit is an elliptical orbit with a
// semi-major axis equal to the average of both planet's semi-major axes.
// Time of flight can then be calculated analytically using Kepler's 3rd law
// as half of the total period.
//
// Parameters:
// focalBody [Body] Common parent of "fromBody" and "toBody".
// fromBody [Body] Departure planet that vessel will leave from.
// toBody [Body] Destination planet that vessel will arrive at.
global function tof_initial_guess {
    parameter focalBody, fromBody, toBody.

    local a is (fromBody:orbit:semimajoraxis + toBody:orbit:semimajoraxis) / 2.
    return constant:pi * sqrt(a ^ 3 / focalBody:mu).
}

// Parameters:
// focalBody [Body] Common parent of "fromBody" and "toBody".
// fromBody [Body] Departure planet that vessel will leave from.
// toBody [Body] Destination planet that vessel will arrive at.
// flip_direction [Boolean] Changes direction of the transfer from prograde to retrograde when set.
// t1 [Scalar] Departure time in seconds from epoch. 
// t2 [Scalar] Arrival time in seconds from epoch.
global function total_deltav {
    parameter focalBody, fromBody, toBody, flip_direction, t1, t2.

    local solution is transfer_deltav(focalBody, fromBody, t1, toBody, t2, flip_direction).
    local ejection is ejection_deltav(fromBody, 100000, solution:dv1).
    local insertion is insertion_deltav(toBody, 100000, solution:dv2).

    return ejection + insertion.
}

local function transfer_deltav {
    parameter focalBody, fromBody, t1, toBody, t2, flip_direction.

    // To determine the position of a planet at a specific time "t" relative to
    // its parent body using the "positionat" function, you must subtract the
    // *current* position of the parent body, not the position of the parent
    // body at time "t" as might be expected.
    local r1 is positionat(fromBody, t1) - focalBody:position.
    local r2 is positionat(toBody, t2) - focalBody:position.

    // Now that we know the positions of the planets at our departure and
    // arrival time, solve Lambert's problem to determine the velocity of the
    // transfer orbit that links the planets at both positions.
    local solution is lambert(r1, r2, t2 - t1, focalBody:mu, flip_direction).

    // "velocityat" already returns orbital velocity relative to the parent
    // body, so no adjustment is needed.
    local dv1 is solution:v1 - velocityat(fromBody, t1):orbit.
    local dv2 is solution:v2 - velocityat(toBody, t2):orbit.
    return lexicon("dv1", dv1, "dv2", dv2).
}

// Calculates the delta-v required to eject into a hyperbolic transfer orbit
// at the correct inclination from the desired altitude "r1".
// Simplifying assumptions:
// * Vessel is currently in a perfectly circular orbit at radius "r1" and
//   velocity "v1" at 0 degrees inclination.
// * The distance to the SOI edge from the center of the planet is small enough
//   (relative to the interplanetary transfer distance) that we can assume the
//   velocity at SOI edge is a close enough approximation to the calculated
//   Lambert transfer velocity.
//
// In KSP's coordinate system, the positive y axis sticks straight up from
// Kerbol's north pole. Therefore to calculate the desired angle "theta" between
// the flat circular orbit and the inclined ejection orbit, we use the handy
// built in "vectorangle" function between the original transfer velocity vector
// and the same vector with the y coordinate zeroed out.
//
// Now we have a triangle with adjacent sides "v1" and escapeV" with angle
// "theta" between them. The cosine rule gives the length of the 3rd side
// that is the magnitude of our required delta-v.
//
// See the next comment section  below for details on how "v1" and "escapev"
// are calculated.
local function ejection_deltav {
    parameter body, altitude, dv1.

    local mu is body:mu.
    local r1 is body:radius + altitude.
    local r2 is body:soiradius.

    local v1 is sqrt(mu / r1).
    local v2 is dv1:mag.
    local escapev is sqrt(v2 ^ 2 + 2 * mu * (r2 - r1) / (r1 * r2)).

    local theta is vectorangle(dv1, v(dv1:x, 0, dv1:z)).
    return sqrt(escapev ^ 2 + v1 ^ 2 - 2 * escapev * v1 * cos(theta)).
}

// Calculates the delta-v required to convert a hyperbolic intercept orbit
// into a circular orbit around the target planet at the desired altitude.
// To simplify calculations no inclination change is made, so that the delta-v
// required will simply be the difference between the hyperbolic velocity
// at "r1" and the circular orbital velocity at "r1".
// 
// For a perfectly circular orbit at radius "r1" the orbital velocity "v1" is
// straightforward to calculate using Kepler's 3rd law.
//
// Calculating the hyperbolic velocity at "r1" is more fun and can be solved by
// applying the vis-visa equation twice.
// Our velocity "v2" at the edge of the SOI (radius denoted "r2") can be
// closely approximated as the magnitude of the "dv2" vector.
//
// The vis-viva equation states that:
// [Equation 1] v2 ^ 2 = mu * (2 / r2 - 1 / a)
//
// Re-arranging gives:
// [Equation 2] -1 / a = (v2 ^ 2) / mu - 2 / r2
//
// Applying the equation again at "r1" gives:
// [Equation 3] v ^ 2 = mu * (2 / r1 - 1 / a)
//
// Substituting 2 into 3 gives:
// [Equation 4] v ^ 2 = mu * (2 / r1 + (v2 ^ 2) / mu - 2 / r2)
//
// Re-arranging slightly:
// [Equation 5] v ^ 2 = (v2 ^ 2) + 2 * mu * (r1 - r2) / (r1 * r2)
//
// Taking the square root of equation 5 then subtracting 'v1" gives the delta-v
// required to capture into a ciruclar orbit.
local function insertion_deltav {
    parameter body, altitude, dv2.

    local mu is body:mu.
    local r1 is body:radius + altitude.
    local r2 is body:soiradius.

    local v1 is sqrt(mu / r1).
    local v2 is dv2:mag.
    local escapev is sqrt(v2 ^ 2 + 2 * mu * (r2 - r1) / (r1 * r2)).

    return escapev - v1.
}