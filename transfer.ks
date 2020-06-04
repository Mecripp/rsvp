runoncepath("kos-launch-window-finder/lambert.ks").

// Default is 250, increase speed 8x
set config:ipu to 2000.

//test1().
//test2().
//test3().
//test4().

// TODO:
// Free arctan angle based on gradient?
// Multiple starting points


//gradientDescent(sun, kerbin, duna).
//gradientDescent(sun, kerbin, moho).
gradientDescent(sun, kerbin, eeloo).

function gradientDescent {
	parameter focalBody, fromBody, toBody.

	local stepSize is kerbinTimeToSeconds(1, 9, 0, 0, 0).
	local threshold is kerbinTimeToSeconds(1, 1, 1, 0, 0).

	local t1 is 40 * stepSize.
	local t2 is t1 + tofInitialGuess(focalBody, fromBody, toBody).

	local progradeDeltaV is totalDeltaV(focalBody, fromBody, toBody, false, t1, t2).
	local retrogradeDeltaV is totalDeltaV(focalBody, fromBody, toBody, true, t1, t2).
	local flipDirection is retrogradeDeltaV < progradeDeltaV.

	local cost is totalDeltaV@:bind(focalBody, fromBody, toBody, flipDirection).
	local current is choose retrogradeDeltaV if flipDirection else progradeDeltaV.
	local dx is 0.
	local dy is 0.

	until stepSize < threshold {
		print "-------".
		print secondsToKerbinTime(t1).
		print secondsToKerbinTime(t2).

		local minX is 0.
		local minY is 0.

		if dx = 0 and dy = 0 {
			local north is cost(t1, t2 + stepSize).
			local south is cost(t1, t2 - stepSize).
			local east is cost(t1 + stepSize, t2 + stepSize).
			local west is cost(t1 - stepSize, t2 - stepSize).

			if north < south {
				set minY to north.
				set dy to stepSize.
			} else {
				set minY to south.
				set dy to -stepSize.
			}

			if east < west {
				set minX to east.
				set dx to stepSize.
			} else {
				set minX to west.
				set dx to -stepSize.
			}
		} else {
			set minX to cost(t1 + dx, t2 + dx).
			set minY to cost(t1, t2 + dy).
		}

		if current < minX and current < minY {
			set dx to 0.
			set dy to 0.
			set stepSize to stepSize / 2.
		} else if minX < minY {
			set current to minX.
			set t1 to t1 + dx.
			set t2 to t2 + dx.
		} else {
			set current to minY.
			set t2 to t2 + dy.
		}
	}

	print round(current).
	print secondsToKerbinTime(t1).
	print secondsToKerbinTime(t2).
}

local function test1 {
	local t1 is kerbinTimeToSeconds(1, 236, 4, 19, 12).
	local t2 is kerbinTimeToSeconds(2, 69, 2, 36, 0).
	transferDetails(sun, kerbin, t1, duna, t2, false).
}

local function test2 {
	local t1 is kerbinTimeToSeconds(2, 256, 3, 36, 0).
	local t2 is kerbinTimeToSeconds(7, 19, 5, 31, 12).
	transferDetails(sun, kerbin, t1, eeloo, t2, true).
}

local function test3 {
	local t1 is kerbinTimeToSeconds(1, 269, 1, 12, 0).
	local t2 is kerbinTimeToSeconds(1, 405, 2, 327, 36).
	transferDetails(sun, kerbin, t1, moho, t2, true).
}

local function test4 {
	local t1 is kerbinTimeToSeconds(1, 3, 3, 36, 0).
	local t2 is kerbinTimeToSeconds(1, 6, 1, 38, 31).
	transferDetails(jool, laythe, t1, tylo, t2, false).
}

local function tofInitialGuess {
	parameter focalBody, fromBody, toBody.

	// Return the time of half a Hohmann transfer between the two bodies
	local a is (fromBody:orbit:semimajoraxis + toBody:orbit:semimajoraxis) / 2.
	return constant:pi * sqrt(a ^ 3 / focalBody:mu).
}

local function transferDetails {
	parameter focalBody, fromBody, t1, toBody, t2, flip_direction.

	local solution is transferDeltaV(focalBody, fromBody, t1, toBody, t2, flip_direction).
	local ejection is ejectionDeltaV(fromBody, 100000, solution:dv1).
	local insertion is insertionDeltaV(toBody, 100000, solution:dv2).

	print "-----------------------------".
	print fromBody:name + " => " + toBody:name.
	print "Ejection: " + round(ejection).
	print "Insertion: " + round(insertion).
	print "Total: " + round(ejection + insertion).
}

local function totalDeltaV {
	parameter focalBody, fromBody, toBody, flip_direction, t1, t2.

	local solution is transferDeltaV(focalBody, fromBody, t1, toBody, t2, flip_direction).
	local ejection is ejectionDeltaV(fromBody, 100000, solution:dv1).
	local insertion is insertionDeltaV(toBody, 100000, solution:dv2).

	return ejection + insertion.
}

local function transferDeltaV {
	parameter focalBody, fromBody, t1, toBody, t2, flip_direction.

	local r1 is positionat(fromBody, t1) - focalBody:position.
	local r2 is positionat(toBody, t2) - focalBody:position.
	local solution is lambert(r1, r2, t2 - t1, focalBody:mu, flip_direction).

	local dv1 is solution:v1 - velocityat(fromBody, t1):orbit.
	local dv2 is solution:v2 - velocityat(toBody, t2):orbit.
	return lexicon("dv1", dv1, "dv2", dv2).
}

function ejectionDeltaV {
	parameter body, altitude, dv1.

	local r1 is body:radius + altitude.
	local r2 is body:soiradius.

	local mu is body:mu.
	local v1 is sqrt(mu / r1).
	local v2 is dv1:mag.

	local theta is vang(dv1, v(dv1:x, 0, dv1:z)).
	local escapeV is sqrt(v2 ^ 2 - 2 * mu * (r1 - r2) / (r1 * r2)).

	return sqrt(escapeV ^ 2 + v1 ^ 2 - 2 * escapeV * v1 * cos(theta)).
}

function insertionDeltaV {
	parameter body, altitude, dv2.

	local r1 is body:radius + altitude.
	local r2 is body:soiradius.

	local mu is body:mu.
	local v1 is sqrt(mu / r1).
	local v2 is dv2:mag.

	return sqrt(v2 ^ 2 - 2 * mu * (r1 - r2) / (r1 * r2)) - v1.
}

function kerbinTimeToSeconds {
	parameter years, days, hours, minutes, seconds.

	local _minutes is 60.
	local _hours is 60 * _minutes.
	local _days is 6 * _hours.
	local _years is 426 * _days.

	return _years * (years - 1) + _days * (days - 1) + _hours * hours + _minutes * minutes + seconds.
}

function secondsToKerbinTime {
	parameter seconds.

	local timespan is time(seconds).
	return timespan:calendar + " " + timespan:clock.
}