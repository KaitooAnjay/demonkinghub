local BallPredictor = {}

local Workspace = game:GetService("Workspace")
local GRAVITY = Vector3.new(0, -Workspace.Gravity, 0)
local BOUNCE_DAMPING = 0.7

-- Quadratic fit untuk sumbu (x/y/z)
local function quadraticFit(timeArray, valueArray)
	local n = #timeArray
	local sumT, sumT2, sumT3, sumT4 = 0, 0, 0, 0
	local sumV, sumTV, sumT2V = 0, 0, 0

	for i = 1, n do
		local t = timeArray[i]
		local v = valueArray[i]
		sumT += t
		sumT2 += t^2
		sumT3 += t^3
		sumT4 += t^4
		sumV += v
		sumTV += t * v
		sumT2V += t^2 * v
	end

	local det = n * (sumT2 * sumT4 - sumT3^2)
	          - sumT * (sumT * sumT4 - sumT2 * sumT3)
	          + sumT2 * (sumT * sumT3 - sumT2^2)

	if det == 0 then
		return 0, 0, valueArray[#valueArray]
	end

	local A = {
		(sumV * (sumT2 * sumT4 - sumT3^2) - sumT * (sumTV * sumT4 - sumT3 * sumT2V) + sumT2 * (sumTV * sumT3 - sumT2 * sumT2V)) / det,
		(n * (sumTV * sumT4 - sumT3 * sumT2V) - sumV * (sumT * sumT4 - sumT2 * sumT3) + sumT2 * (sumT * sumT2V - sumTV * sumT2)) / det,
		(n * (sumT2 * sumT2V - sumTV * sumT3) - sumT * (sumT * sumT2V - sumTV * sumT2) + sumV * (sumT * sumT3 - sumT2^2)) / det,
	}

	return A[3], A[2], A[1] -- a, b, c
end

-- Prediksi posisi akhir setelah durasi tertentu, dengan bounce
-- @param samples: { time = number, pos = Vector3 }[]
-- @param predictTime: waktu ke depan (dalam detik)
-- @param timestep: simulasi per langkah (default 0.03)
-- @param maxBounce: maksimal jumlah pantulan (default 3)
function BallPredictor.Predict(samples, predictTime, timestep, maxBounce, RaycastParam)
	timestep = timestep or 0.03
	maxBounce = maxBounce or 3

	local n = #samples
	if n < 3 then
		warn("Minimal 3 data posisi diperlukan.")
		return samples[n] and samples[n].pos or Vector3.zero
	end

	local lastTime = samples[n].time
	local timeArray, xVals, yVals, zVals = {}, {}, {}, {}

	for i = 1, n do
		local t = samples[i].time - lastTime
		table.insert(timeArray, t)
		table.insert(xVals, samples[i].pos.X)
		table.insert(yVals, samples[i].pos.Y)
		table.insert(zVals, samples[i].pos.Z)
	end

	local ax, bx, cx = quadraticFit(timeArray, xVals)
	local ay, by, cy = quadraticFit(timeArray, yVals)
	local az, bz, cz = quadraticFit(timeArray, zVals)

	-- Ambil posisi dan velocity awal
	local currentPos = Vector3.new(cx, cy, cz)
	local currentVel = Vector3.new(
		2 * ax * 0 + bx,
		2 * ay * 0 + by,
		2 * az * 0 + bz
	)

	local elapsed = 0
	local bounces = 0

	while elapsed < predictTime do
		currentVel += GRAVITY * timestep
		local nextPos = currentPos + currentVel * timestep

		local direction = nextPos - currentPos
		local ray = Workspace:Raycast(currentPos, direction, RaycastParam or RaycastParams.new())

		if ray then
			-- Bounce!
			if bounces >= maxBounce then
				break
			end

			local normal = ray.Normal
			currentPos = ray.Position
			currentVel = currentVel - 2 * currentVel:Dot(normal) * normal
			currentVel *= BOUNCE_DAMPING
			bounces += 1
		else
			currentPos = nextPos
		end

		elapsed += timestep
	end

	return currentPos
end

return BallPredictor
