--[[
	ZENLESS — Aimbot + ESP Example Hub

	Loads the ZENLESS library from Pastebin (or local FluentGui.lua).

	Executor:
		loadstring(readfile("AimbotExample.lua"))()
	Or one-liner after hosting this file.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ZENLESS library paste (must be FluentGui.lua source — NOT a random paste)
local LIBRARY_URLS = {
	"https://raw.githubusercontent.com/andreslopezze2011-a11y/zenless-lib/refs/heads/main/FluentGui.lua",
}

-- ============ LOAD LIBRARY ============
pcall(function()
	getgenv().ZENLESS_NO_LOADER = true -- skip loader; KeySystem gates access
	getgenv().ZENLESS_DEMO = false
	if getgenv().Zenless and type(getgenv().Zenless.Unload) == "function" then
		pcall(function() getgenv().Zenless:Unload() end)
		task.wait(0.2)
	end
	getgenv().Zenless = nil
	getgenv().Fluent = nil
end)

local Zenless
do
	local errors = {}

	local function isLibrary(t)
		return type(t) == "table" and (type(t.AddTab) == "function" or type(t.Notify) == "function")
	end

	local function tryLoad(src, label)
		if type(src) ~= "string" or #src < 64 then
			error(label .. ": empty / invalid source (" .. tostring(src and #src or 0) .. " bytes)")
		end
		-- Reject HTML pages accidentally pasted as "library"
		local head = string.sub(src, 1, 200):lower()
		if string.find(head, "<!doctype") or string.find(head, "<html") then
			error(label .. ": got HTML page, not Lua library")
		end
		local fn, err = loadstring(src)
		if not fn then
			error(label .. ": compile failed — " .. tostring(err))
		end
		local lib = fn()
		if not isLibrary(lib) then
			error(label .. ": script ran but did not return ZENLESS library table")
		end
		return lib
	end

	local function httpGet(url)
		if game and game.HttpGet then
			return game:HttpGet(url)
		end
		local reqFn = (typeof(http_request) == "function" and http_request)
			or (typeof(request) == "function" and request)
			or (syn and syn.request)
		if reqFn then
			local res = reqFn({ Url = url, Method = "GET" })
			return res and (res.Body or res.body)
		end
		return nil
	end

	-- 1) Local FluentGui.lua (best — your latest UI / notifications)
	do
		local ok, result = pcall(function()
			assert(typeof(readfile) == "function", "readfile unavailable")
			local path = "FluentGui.lua"
			if typeof(isfile) == "function" and not isfile(path) then
				-- common workspace fallbacks
				for _, p in ipairs({ "FluentGui.lua", "Zenless.lua", "workspace/FluentGui.lua" }) do
					if isfile(p) then path = p; break end
				end
			end
			return tryLoad(readfile(path), "local:" .. path)
		end)
		if ok and isLibrary(result) then
			Zenless = result
		else
			table.insert(errors, "local → " .. tostring(result))
		end
	end

	-- 2) Pastebin / hosted raw URLs
	if not Zenless then
		for _, url in ipairs(LIBRARY_URLS) do
			local ok, result = pcall(function()
				local body = httpGet(url)
				assert(body, "HttpGet returned nil")
				return tryLoad(body, url)
			end)
			if ok and isLibrary(result) then
				Zenless = result
				break
			else
				table.insert(errors, url .. " → " .. tostring(result))
			end
		end
	end

	if not Zenless then
		error(
			"[AimbotExample] Failed to load ZENLESS library.\n"
				.. "Put FluentGui.lua in your executor workspace, or fix LIBRARY_URLS.\n"
				.. table.concat(errors, "\n")
		)
	end

	pcall(function()
		getgenv().Zenless = Zenless
		getgenv().Fluent = Zenless
	end)
end

-- ============ KEY SYSTEM (after library load) ============
do
	local unlocked = Zenless:KeySystem({
		Title = "ZENLESS",
		Subtitle = "Enter your key",
		Note = "", -- never show a second fake field / note box
		Key = "123456",
		SaveKey = true,
		FileName = "zenless_aimbot_key.txt",
		KeyLink = "https://discord.gg/",
	})
	if not unlocked then
		pcall(function()
			Zenless:Unload()
		end)
		return
	end
end

local function guiParent()
	local ok, h = pcall(function()
		return gethui and gethui()
	end)
	if ok and h then return h end
	return CoreGui
end

local Connections = {}
local function bind(conn)
	table.insert(Connections, conn)
	return conn
end

-- ============ SHARED SETTINGS ============
local Aim = {
	Enabled = false,
	ShowFOV = true,
	TeamCheck = false, -- off by default (Neutral teams break aimbots)
	AliveCheck = true,
	WallCheck = false,
	Prediction = true,
	PredictStrength = 0.12, -- seconds of velocity lead
	Smoothness = 0.25, -- 0 = snap, 1 = molasses
	FOV = 180,
	MaxDistance = 1200,
	TargetPart = "Head",
	AimOffset = Vector3.new(0, 0, 0),
	Mode = "Hold", -- Hold | Always
	Method = "Camera", -- Camera | Mouse
	AimKey = Enum.UserInputType.MouseButton2,
	ToggleKey = Enum.KeyCode.E,
	Sticky = true,
	StickyFOV = 280, -- wider keep radius once locked
}

local ESP = {
	Enabled = false,
	TeamCheck = true,
	Boxes = true,
	Names = true,
	Distance = true,
	Health = true,
	Tracers = false,
	Chams = true,
	MaxDistance = 1200,
	BoxColor = Color3.fromRGB(198, 198, 208),
	NameColor = Color3.fromRGB(245, 245, 248),
	TracerColor = Color3.fromRGB(198, 198, 208),
	EnemyColor = Color3.fromRGB(210, 90, 90),
	TeamColor = Color3.fromRGB(90, 200, 120),
	ChamsFill = Color3.fromRGB(198, 198, 208),
	ChamsOutline = Color3.fromRGB(255, 255, 255),
	ChamsTransparency = 0.65,
}

local Misc = {
	FullBright = false,
	NoFog = false,
}

local LockedPlayer = nil -- Player instance
local EspObjects = {} -- [player] = folder data
local AIM_BIND = "ZenlessAimbot"

-- ============ FOV RING ============
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "ZenlessFOV"
fovGui.IgnoreGuiInset = true
fovGui.ResetOnSpawn = false
fovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(fovGui) end
end)
fovGui.Parent = guiParent()

local fovRing = Instance.new("Frame")
fovRing.Name = "Ring"
fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
fovRing.BackgroundTransparency = 1
fovRing.Size = UDim2.fromOffset(Aim.FOV * 2, Aim.FOV * 2)
fovRing.Visible = false
fovRing.Parent = fovGui

Instance.new("UICorner", fovRing).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(198, 198, 208)
fovStroke.Thickness = 1.4
fovStroke.Transparency = 0.35
fovStroke.Parent = fovRing

local function updateFOVVisual()
	Camera = Workspace.CurrentCamera
	local size = math.max(8, Aim.FOV * 2)
	fovRing.Size = UDim2.fromOffset(size, size)
	fovRing.Visible = Aim.ShowFOV and Aim.Enabled
	local vp = Camera.ViewportSize
	fovRing.Position = UDim2.fromOffset(vp.X * 0.5, vp.Y * 0.5)
end

-- ============ HELPERS ============
local function getPart(character, name)
	if not character then return nil end
	local part = character:FindFirstChild(name)
	if part and part:IsA("BasePart") then return part end
	part = character:FindFirstChild("Head")
	if part and part:IsA("BasePart") then return part end
	part = character:FindFirstChild("HumanoidRootPart")
	if part and part:IsA("BasePart") then return part end
	return character:FindFirstChildWhichIsA("BasePart")
end

local function isAlive(character)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
	return true
end

local NEUTRAL_TEAMS = {
	Neutral = true,
	Spectators = true,
	Spectator = true,
	FFA = true,
}

local function sameTeam(other)
	local a, b = LocalPlayer.Team, other.Team
	if not a or not b then return false end
	if NEUTRAL_TEAMS[a.Name] or NEUTRAL_TEAMS[b.Name] then return false end
	return a == b
end

local function isEnemy(plr, teamCheck)
	if not plr or plr == LocalPlayer then return false end
	if teamCheck and sameTeam(plr) then return false end
	return true
end

local function isVisible(part, character)
	if not Aim.WallCheck then return true end
	local origin = Camera.CFrame.Position
	local target = part.Position
	local dir = target - origin
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { LocalPlayer.Character, Camera }
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, dir, params)
	if not result then return true end
	return character and result.Instance:IsDescendantOf(character)
end

local function worldToScreen(pos)
	local screen, onScreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(screen.X, screen.Y), onScreen, screen.Z
end

local function getAimPoint(part)
	local pos = part.Position + Aim.AimOffset
	if Aim.Prediction and part.AssemblyLinearVelocity then
		local vel = part.AssemblyLinearVelocity
		-- ignore wild flings
		if vel.Magnitude < 250 then
			pos = pos + vel * Aim.PredictStrength
		end
	end
	return pos
end

-- ============ AIMBOT ============
local function screenCenter()
	local vp = Camera.ViewportSize
	return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
end

local function targetScore(part, center, fovLimit, myRoot)
	local aimPos = getAimPoint(part)
	local screen, _, depth = worldToScreen(aimPos)
	if depth <= 0 then return nil end -- behind camera
	local mag = (screen - center).Magnitude
	if mag > fovLimit then return nil end
	local dist3d = myRoot and (aimPos - myRoot.Position).Magnitude or depth
	if dist3d > Aim.MaxDistance then return nil end
	return mag, screen, aimPos, dist3d
end

local function validateTarget(plr, fovLimit)
	if not isEnemy(plr, Aim.TeamCheck) then return nil end
	local char = plr.Character
	if not char then return nil end
	if Aim.AliveCheck and not isAlive(char) then return nil end
	local part = getPart(char, Aim.TargetPart)
	if not part then return nil end
	if not isVisible(part, char) then return nil end
	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local mag, screen, aimPos = targetScore(part, screenCenter(), fovLimit, myRoot)
	if not mag then return nil end
	return part, mag, screen, aimPos
end

local function getClosestTarget()
	Camera = Workspace.CurrentCamera
	if not Camera then return nil, nil, nil end

	-- Keep sticky lock with a wider FOV
	if Aim.Sticky and LockedPlayer and LockedPlayer.Parent then
		local part, mag, _, aimPos = validateTarget(LockedPlayer, Aim.StickyFOV)
		if part then
			return LockedPlayer, part, aimPos
		end
		LockedPlayer = nil
	else
		LockedPlayer = nil
	end

	local bestPlr, bestPart, bestAim, bestMag = nil, nil, nil, Aim.FOV
	for _, plr in ipairs(Players:GetPlayers()) do
		local part, mag, _, aimPos = validateTarget(plr, Aim.FOV)
		if part and mag < bestMag then
			bestMag = mag
			bestPlr = plr
			bestPart = part
			bestAim = aimPos
		end
	end

	if bestPlr then
		LockedPlayer = bestPlr
		return bestPlr, bestPart, bestAim
	end
	return nil, nil, nil
end

local function mouseMoveAim(screenPos, dt)
	local center = screenCenter()
	local delta = screenPos - center
	local smooth = math.clamp(Aim.Smoothness, 0, 0.95)
	local step = 1 - smooth
	step = 1 - math.pow(1 - step, math.clamp((dt or 0.016) * 60, 0.1, 3))
	local dx = delta.X * step
	local dy = delta.Y * step
	if math.abs(dx) < 0.15 and math.abs(dy) < 0.15 then return end

	if typeof(mousemoverel) == "function" then
		mousemoverel(dx, dy)
	elseif typeof(mouse1click) == "function" and typeof(Input) == "table" then
		-- no-op fallback
	else
		-- Viewport mouse delta via Camera if mouse API missing
		local cam = Camera
		local sens = 0.0022 * step
		local cf = cam.CFrame
		cam.CFrame = CFrame.Angles(0, -dx * sens, 0) * cf * CFrame.Angles(-dy * sens, 0, 0)
	end
end

local function cameraAim(aimPos, dt)
	local cam = Camera
	local origin = cam.CFrame.Position
	-- CFrame.new(pos, lookAt) is widely supported
	local goal = CFrame.new(origin, aimPos)
	local smooth = math.clamp(Aim.Smoothness, 0, 0.98)
	if smooth <= 0.01 then
		cam.CFrame = goal
		return
	end
	-- Higher smoothness = slower; frame-rate independent
	local alpha = 1 - smooth
	alpha = 1 - math.pow(1 - alpha, math.clamp((dt or 0.016) * 60, 0.1, 3))
	cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end

local function aimAt(aimPos, screenPos, dt)
	if not aimPos then return end
	if Aim.Method == "Mouse" then
		if screenPos then
			mouseMoveAim(screenPos, dt)
		else
			local screen = worldToScreen(aimPos)
			mouseMoveAim(screen, dt)
		end
	else
		cameraAim(aimPos, dt)
	end
end

local function isAimHeld()
	if Aim.Mode == "Always" then return true end
	local key = Aim.AimKey
	if typeof(key) == "EnumItem" then
		if key.EnumType == Enum.UserInputType then
			return UserInputService:IsMouseButtonPressed(key)
		elseif key.EnumType == Enum.KeyCode then
			return UserInputService:IsKeyDown(key)
		end
	end
	return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

local function runAimbot(dt)
	Camera = Workspace.CurrentCamera
	if not Camera or not Aim.Enabled then
		LockedPlayer = nil
		return
	end
	if not isAimHeld() then
		if not Aim.Sticky then LockedPlayer = nil end
		return
	end

	local _, part, aimPos = getClosestTarget()
	if not part or not aimPos then return end

	local screen = select(1, worldToScreen(aimPos))
	aimAt(aimPos, screen, dt)
end

-- ============ ESP ============
local espGui = Instance.new("ScreenGui")
espGui.Name = "ZenlessESP"
espGui.IgnoreGuiInset = true
espGui.ResetOnSpawn = false
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
	if syn and syn.protect_gui then syn.protect_gui(espGui) end
end)
espGui.Parent = guiParent()

local HasDrawing = typeof(Drawing) == "table"

local function makeDraw(class)
	if not HasDrawing then return nil end
	local ok, obj = pcall(function()
		return Drawing.new(class)
	end)
	return ok and obj or nil
end

local function destroyEsp(plr)
	local data = EspObjects[plr]
	if not data then return end
	if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
	if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
	if data.Box then pcall(function() data.Box:Remove() end) end
	if data.Tracer then pcall(function() data.Tracer:Remove() end) end
	if data.HealthBar then pcall(function() data.HealthBar:Remove() end) end
	if data.HealthOutline then pcall(function() data.HealthOutline:Remove() end) end
	EspObjects[plr] = nil
end

local function ensureEsp(plr)
	if EspObjects[plr] then return EspObjects[plr] end
	local data = {}

	-- Chams via Highlight
	local hl = Instance.new("Highlight")
	hl.Name = "ZenlessChams"
	hl.FillColor = ESP.ChamsFill
	hl.OutlineColor = ESP.ChamsOutline
	hl.FillTransparency = ESP.ChamsTransparency
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = false
	hl.Parent = espGui
	data.Highlight = hl

	-- Name / distance billboard
	local bb = Instance.new("BillboardGui")
	bb.Name = "ZenlessTag"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(160, 40)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.Enabled = false
	bb.Parent = espGui

	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.new(1, 0, 0.55, 0)
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 13
	nameLbl.TextColor3 = ESP.NameColor
	nameLbl.TextStrokeTransparency = 0.5
	nameLbl.Text = plr.Name
	nameLbl.Parent = bb
	data.NameLabel = nameLbl

	local infoLbl = Instance.new("TextLabel")
	infoLbl.BackgroundTransparency = 1
	infoLbl.Size = UDim2.new(1, 0, 0.45, 0)
	infoLbl.Position = UDim2.fromScale(0, 0.55)
	infoLbl.Font = Enum.Font.Gotham
	infoLbl.TextSize = 11
	infoLbl.TextColor3 = Color3.fromRGB(190, 190, 198)
	infoLbl.TextStrokeTransparency = 0.55
	infoLbl.Text = ""
	infoLbl.Parent = bb
	data.InfoLabel = infoLbl
	data.Billboard = bb

	-- Drawing box / tracer / health (if available)
	if HasDrawing then
		local box = makeDraw("Square")
		if box then
			box.Filled = false
			box.Thickness = 1
			box.Color = ESP.BoxColor
			box.Visible = false
			data.Box = box
		end
		local tracer = makeDraw("Line")
		if tracer then
			tracer.Thickness = 1
			tracer.Color = ESP.TracerColor
			tracer.Visible = false
			data.Tracer = tracer
		end
		local hOut = makeDraw("Square")
		if hOut then
			hOut.Filled = false
			hOut.Thickness = 1
			hOut.Color = Color3.new(0, 0, 0)
			hOut.Visible = false
			data.HealthOutline = hOut
		end
		local hBar = makeDraw("Square")
		if hBar then
			hBar.Filled = true
			hBar.Thickness = 1
			hBar.Color = Color3.fromRGB(90, 200, 120)
			hBar.Visible = false
			data.HealthBar = hBar
		end
	end

	EspObjects[plr] = data
	return data
end

local function hideEspVisuals(data)
	if data.Highlight then data.Highlight.Enabled = false; data.Highlight.Adornee = nil end
	if data.Billboard then data.Billboard.Enabled = false; data.Billboard.Adornee = nil end
	if data.Box then data.Box.Visible = false end
	if data.Tracer then data.Tracer.Visible = false end
	if data.HealthBar then data.HealthBar.Visible = false end
	if data.HealthOutline then data.HealthOutline.Visible = false end
end

local function updateEspPlayer(plr)
	local data = ensureEsp(plr)
	if not ESP.Enabled or not isEnemy(plr, ESP.TeamCheck) then
		hideEspVisuals(data)
		return
	end

	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local head = char and char:FindFirstChild("Head")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		hideEspVisuals(data)
		return
	end

	local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
	if dist > ESP.MaxDistance then
		hideEspVisuals(data)
		return
	end

	local color = sameTeam(plr) and ESP.TeamColor or ESP.EnemyColor

	-- Chams
	if ESP.Chams then
		data.Highlight.Adornee = char
		data.Highlight.FillColor = ESP.ChamsFill
		data.Highlight.OutlineColor = ESP.ChamsOutline
		data.Highlight.FillTransparency = ESP.ChamsTransparency
		data.Highlight.Enabled = true
	else
		data.Highlight.Enabled = false
		data.Highlight.Adornee = nil
	end

	-- Name / distance
	if ESP.Names or ESP.Distance or ESP.Health then
		data.Billboard.Adornee = head or root
		data.Billboard.Enabled = true
		data.NameLabel.Visible = ESP.Names
		data.NameLabel.Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
		data.NameLabel.TextColor3 = ESP.NameColor

		local bits = {}
		if ESP.Distance then table.insert(bits, string.format("%dm", math.floor(dist))) end
		if ESP.Health then table.insert(bits, string.format("%d/%d HP", math.floor(hum.Health), math.floor(hum.MaxHealth))) end
		data.InfoLabel.Text = table.concat(bits, "  ·  ")
		data.InfoLabel.Visible = #bits > 0
	else
		data.Billboard.Enabled = false
	end

	-- 2D box / tracer / health (Drawing)
	local topPos = (head and head.Position or root.Position) + Vector3.new(0, 0.8, 0)
	local bottomPos = root.Position - Vector3.new(0, 3, 0)
	local top, on1, z1 = worldToScreen(topPos)
	local bottom, on2, z2 = worldToScreen(bottomPos)
	local mid, on3 = worldToScreen(root.Position)

	if data.Box then
		if ESP.Boxes and on1 and on2 and z1 > 0 and z2 > 0 then
			local h = math.abs(bottom.Y - top.Y)
			local w = h * 0.65
			data.Box.Size = Vector2.new(w, h)
			data.Box.Position = Vector2.new(top.X - w * 0.5, top.Y)
			data.Box.Color = color
			data.Box.Visible = true
		else
			data.Box.Visible = false
		end
	end

	if data.Tracer then
		if ESP.Tracers and on3 and mid then
			local vp = Camera.ViewportSize
			data.Tracer.From = Vector2.new(vp.X * 0.5, vp.Y)
			data.Tracer.To = mid
			data.Tracer.Color = ESP.TracerColor
			data.Tracer.Visible = true
		else
			data.Tracer.Visible = false
		end
	end

	if data.HealthBar and data.HealthOutline then
		if ESP.Health and data.Box and data.Box.Visible then
			local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			local boxPos = data.Box.Position
			local boxSize = data.Box.Size
			local barW = 3
			local x = boxPos.X - barW - 3
			data.HealthOutline.Size = Vector2.new(barW, boxSize.Y)
			data.HealthOutline.Position = Vector2.new(x, boxPos.Y)
			data.HealthOutline.Visible = true
			local filled = boxSize.Y * ratio
			data.HealthBar.Size = Vector2.new(barW - 1, filled)
			data.HealthBar.Position = Vector2.new(x + 0.5, boxPos.Y + (boxSize.Y - filled))
			data.HealthBar.Color = Color3.fromRGB(90, 200, 120):Lerp(Color3.fromRGB(210, 70, 70), 1 - ratio)
			data.HealthBar.Visible = true
		else
			data.HealthBar.Visible = false
			data.HealthOutline.Visible = false
		end
	end
end

local function refreshAllEsp()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			updateEspPlayer(plr)
		end
	end
end

local function clearAllEsp()
	for plr in pairs(EspObjects) do
		destroyEsp(plr)
	end
end

bind(Players.PlayerRemoving:Connect(function(plr)
	destroyEsp(plr)
	if LockedPlayer == plr then LockedPlayer = nil end
end))

bind(Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.2)
		if ESP.Enabled then updateEspPlayer(plr) end
	end)
end))

for _, plr in ipairs(Players:GetPlayers()) do
	if plr ~= LocalPlayer then
		plr.CharacterAdded:Connect(function()
			task.wait(0.2)
			if ESP.Enabled then updateEspPlayer(plr) end
		end)
	end
end

-- ============ MISC ============
local savedLighting = {
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows,
	Ambient = Lighting.Ambient,
}

local function applyFullBright(on)
	Misc.FullBright = on
	if on then
		Lighting.Brightness = 2.5
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(180, 180, 180)
	else
		Lighting.Brightness = savedLighting.Brightness
		Lighting.ClockTime = savedLighting.ClockTime
		Lighting.GlobalShadows = savedLighting.GlobalShadows
		Lighting.Ambient = savedLighting.Ambient
	end
end

local function applyNoFog(on)
	Misc.NoFog = on
	if on then
		Lighting.FogEnd = 100000
	else
		Lighting.FogEnd = savedLighting.FogEnd
	end
end

-- ============ LOOPS / INPUT ============
bind(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Aim.ToggleKey then
		Aim.Enabled = not Aim.Enabled
		if not Aim.Enabled then LockedPlayer = nil end
		updateFOVVisual()
		Zenless:Notify({
			Title = "Aimbot",
			Content = Aim.Enabled and ("On — " .. Aim.Mode) or "Disabled",
			Type = Aim.Enabled and "success" or "info",
			Duration = 1.5,
		})
	end
end))

-- ESP + FOV visual (normal render step)
bind(RunService.RenderStepped:Connect(function()
	Camera = Workspace.CurrentCamera
	updateFOVVisual()
	if ESP.Enabled then
		refreshAllEsp()
	end
end))

-- Aim AFTER camera scripts so the lock actually sticks
pcall(function()
	RunService:UnbindFromRenderStep(AIM_BIND)
end)
RunService:BindToRenderStep(AIM_BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
	runAimbot(dt)
end)
table.insert(Connections, {
	Disconnect = function()
		pcall(function()
			RunService:UnbindFromRenderStep(AIM_BIND)
		end)
	end,
})

local function unloadAll()
	pcall(function()
		RunService:UnbindFromRenderStep(AIM_BIND)
	end)
	for _, c in ipairs(Connections) do
		pcall(function() c:Disconnect() end)
	end
	clearAllEsp()
	pcall(function() fovGui:Destroy() end)
	pcall(function() espGui:Destroy() end)
	if Misc.FullBright then applyFullBright(false) end
	if Misc.NoFog then applyNoFog(false) end
	Zenless:Unload()
end

bind(Zenless.ScreenGui.AncestryChanged:Connect(function(_, parent)
	if parent then return end
	pcall(function()
		RunService:UnbindFromRenderStep(AIM_BIND)
	end)
	for _, c in ipairs(Connections) do
		pcall(function() c:Disconnect() end)
	end
	clearAllEsp()
	pcall(function() fovGui:Destroy() end)
	pcall(function() espGui:Destroy() end)
end))

-- ============ BUILD UI ============
local Window = Zenless:CreateWindow({
	Title = "ZENLESS",
	MinimizeKey = Enum.KeyCode.RightShift,
})

local combat = Zenless:AddTab({ Title = "Combat", Icon = "target", Description = "Aimbot", Color = Color3.fromRGB(210, 90, 90) })
local espTab = Zenless:AddTab({ Title = "ESP", Icon = "eye", Description = "Visuals", Color = Color3.fromRGB(120, 180, 220) })
local visuals = Zenless:AddTab({ Title = "World", Icon = "world", Description = "Misc", Color = Color3.fromRGB(198, 198, 208) })
local playerTab = Zenless:AddTab({ Title = "Player", Icon = "user", Description = "Local", Color = Color3.fromRGB(170, 170, 180) })
local settingsTab = Zenless:AddTab({ Title = "Settings", Icon = "settings", Description = "Hub", Color = Color3.fromRGB(140, 140, 150) })

-- Combat
combat:AddSection("AIMBOT")
combat:AddParagraph("How to use",
	"1) Enable aimbot  2) Mode Hold = hold RMB, Always = locks while enabled  3) If it feels weak, set Smoothness lower or Method to Camera.")

combat:AddToggle({
	Title = "Enable aimbot",
	Default = Aim.Enabled,
	Callback = function(on)
		Aim.Enabled = on
		if not on then LockedPlayer = nil end
		updateFOVVisual()
		Zenless:Notify({
			Title = "Aimbot",
			Content = on and ("Ready — " .. Aim.Mode) or "Off",
			Type = on and "success" or "info",
			Duration = 1.8,
		})
	end,
})

combat:AddDropdown({
	Title = "Aim mode",
	Values = { "Hold", "Always" },
	Default = Aim.Mode,
	Callback = function(opt)
		Aim.Mode = opt
		Zenless:Notify({ Title = "Aimbot", Content = "Mode: " .. opt, Type = "info", Duration = 1.4 })
	end,
})

combat:AddDropdown({
	Title = "Aim method",
	Values = { "Camera", "Mouse" },
	Default = Aim.Method,
	Callback = function(opt) Aim.Method = opt end,
})

combat:AddToggle({ Title = "Team check", Default = Aim.TeamCheck, Callback = function(on) Aim.TeamCheck = on end })
combat:AddToggle({ Title = "Alive check", Default = Aim.AliveCheck, Callback = function(on) Aim.AliveCheck = on end })
combat:AddToggle({ Title = "Wall check", Default = Aim.WallCheck, Callback = function(on) Aim.WallCheck = on end })
combat:AddToggle({ Title = "Prediction", Default = Aim.Prediction, Callback = function(on) Aim.Prediction = on end })
combat:AddToggle({ Title = "Sticky target", Default = Aim.Sticky, Callback = function(on) Aim.Sticky = on end })

combat:AddSlider({
	Title = "FOV", Min = 40, Max = 500, Default = Aim.FOV,
	Callback = function(v) Aim.FOV = v; Aim.StickyFOV = math.max(v + 80, v * 1.35); updateFOVVisual() end,
})
combat:AddSlider({
	Title = "Smoothness", Min = 0, Max = 90, Default = math.floor(Aim.Smoothness * 100),
	Callback = function(v) Aim.Smoothness = v / 100 end,
})
combat:AddSlider({
	Title = "Prediction", Min = 0, Max = 40, Default = math.floor(Aim.PredictStrength * 100),
	Callback = function(v) Aim.PredictStrength = v / 100 end,
})
combat:AddSlider({
	Title = "Max distance", Min = 50, Max = 2500, Default = Aim.MaxDistance,
	Callback = function(v) Aim.MaxDistance = v end,
})
combat:AddDropdown({
	Title = "Target part",
	Values = { "Head", "HumanoidRootPart", "UpperTorso", "Torso" },
	Default = Aim.TargetPart,
	Callback = function(opt) Aim.TargetPart = opt end,
})
combat:AddKeybind({
	Title = "Toggle key",
	Default = Aim.ToggleKey,
	Callback = function(k)
		Aim.ToggleKey = k
		Zenless:Notify({ Title = "Aimbot", Content = "Toggle → " .. k.Name, Type = "info", Duration = 1.5 })
	end,
})
combat:AddToggle({
	Title = "Show FOV circle",
	Default = Aim.ShowFOV,
	Callback = function(on) Aim.ShowFOV = on; updateFOVVisual() end,
})
combat:AddColorpicker({
	Title = "FOV color",
	Default = Color3.fromRGB(198, 198, 208),
	Callback = function(c) fovStroke.Color = c end,
})
combat:AddHotkeyHint({ "RMB" }, "Hold to aim (Hold mode)")
combat:AddHotkeyHint({ "E" }, "Toggle aimbot master")
combat:AddButton({
	Title = "Quick: Always + Snap",
	Primary = true,
	Callback = function()
		Aim.Enabled = true
		Aim.Mode = "Always"
		Aim.Smoothness = 0.05
		Aim.FOV = 320
		Aim.StickyFOV = 420
		Aim.TeamCheck = false
		updateFOVVisual()
		Zenless:Notify({ Title = "Aimbot", Content = "Always-on snap preset applied.", Type = "success", Duration = 2 })
	end,
})

-- ESP
espTab:AddSection("PLAYER ESP")
espTab:AddParagraph("ESP", HasDrawing
	and "Boxes / tracers use Drawing API. Names + chams always available."
	or "Drawing API missing — boxes/tracers disabled. Names + chams still work.")

espTab:AddToggle({
	Title = "Enable ESP",
	Default = ESP.Enabled,
	Callback = function(on)
		ESP.Enabled = on
		if not on then
			for _, data in pairs(EspObjects) do hideEspVisuals(data) end
		end
		Zenless:Notify({ Title = "ESP", Content = on and "Enabled" or "Disabled", Type = on and "success" or "info", Duration = 1.5 })
	end,
})
espTab:AddToggle({ Title = "Team check", Default = ESP.TeamCheck, Callback = function(on) ESP.TeamCheck = on end })
espTab:AddToggle({ Title = "Boxes", Default = ESP.Boxes, Callback = function(on) ESP.Boxes = on end })
espTab:AddToggle({ Title = "Names", Default = ESP.Names, Callback = function(on) ESP.Names = on end })
espTab:AddToggle({ Title = "Distance", Default = ESP.Distance, Callback = function(on) ESP.Distance = on end })
espTab:AddToggle({ Title = "Health", Default = ESP.Health, Callback = function(on) ESP.Health = on end })
espTab:AddToggle({ Title = "Tracers", Default = ESP.Tracers, Callback = function(on) ESP.Tracers = on end })
espTab:AddToggle({ Title = "Chams (Highlight)", Default = ESP.Chams, Callback = function(on) ESP.Chams = on end })
espTab:AddSlider({
	Title = "Max distance", Min = 100, Max = 3000, Default = ESP.MaxDistance,
	Callback = function(v) ESP.MaxDistance = v end,
})
espTab:AddSlider({
	Title = "Chams transparency", Min = 0, Max = 90, Default = math.floor(ESP.ChamsTransparency * 100),
	Callback = function(v) ESP.ChamsTransparency = v / 100 end,
})

espTab:AddSection("COLORS")
espTab:AddColorpicker({ Title = "Enemy color", Default = ESP.EnemyColor, Callback = function(c) ESP.EnemyColor = c end })
espTab:AddColorpicker({ Title = "Name color", Default = ESP.NameColor, Callback = function(c) ESP.NameColor = c end })
espTab:AddColorpicker({ Title = "Chams fill", Default = ESP.ChamsFill, Callback = function(c) ESP.ChamsFill = c end })
espTab:AddColorpicker({ Title = "Tracer color", Default = ESP.TracerColor, Callback = function(c) ESP.TracerColor = c end })

-- World / misc
visuals:AddSection("WORLD")
visuals:AddToggle({
	Title = "Full bright",
	Default = false,
	Callback = function(on) applyFullBright(on) end,
})
visuals:AddToggle({
	Title = "No fog",
	Default = false,
	Callback = function(on) applyNoFog(on) end,
})
visuals:AddSlider({
	Title = "Camera FOV", Min = 40, Max = 120, Default = 70,
	Callback = function(v) Workspace.CurrentCamera.FieldOfView = v end,
})
visuals:AddDropdown({
	Title = "Time of day",
	Values = { "Morning", "Noon", "Evening", "Night" },
	Default = "Noon",
	Callback = function(opt)
		local times = { Morning = 8, Noon = 14, Evening = 18, Night = 0 }
		Lighting.ClockTime = times[opt] or 14
	end,
})

-- Player
playerTab:AddSection("MOVEMENT")
playerTab:AddSlider({
	Title = "Walk speed", Min = 8, Max = 200, Default = 16,
	Callback = function(v)
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = v end
	end,
})
playerTab:AddSlider({
	Title = "Jump power", Min = 20, Max = 250, Default = 50,
	Callback = function(v)
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = v
		end
	end,
})
playerTab:AddButton({
	Title = "Respawn",
	Callback = function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
			Zenless:Notify({ Title = "Player", Content = "Respawning…", Type = "warning", Duration = 2 })
		end
	end,
})

-- Settings
settingsTab:AddSection("INTERFACE")
settingsTab:AddKeybind({
	Title = "Hide / show UI",
	Default = Enum.KeyCode.RightShift,
	Callback = function(k) Window.SetToggleKey(k) end,
})
settingsTab:AddDropdown({
	Title = "Window size",
	Values = { "Compact", "Normal", "Wide" },
	Default = "Normal",
	Callback = function(v)
		if Window.SetSizePreset then Window.SetSizePreset(v) end
	end,
})
settingsTab:AddSlider({
	Title = "Unfocused opacity",
	Min = 0,
	Max = 70,
	Default = 0,
	Step = 5,
	Flag = "unfocusedOpacity",
	Callback = function(v)
		if Zenless.SetFlag then Zenless:SetFlag("UnfocusedOpacity", v / 100) end
		if Window.SetUnfocusedOpacity then Window.SetUnfocusedOpacity(v / 100) end
	end,
})
settingsTab:AddToggle({
	Title = "Pin window (top-most)",
	Default = false,
	Flag = "pinWindow",
	Callback = function(on)
		if Window.SetPinned then Window.SetPinned(on) end
	end,
})
settingsTab:AddToggle({
	Title = "Auto-collapse sidebar",
	Default = true,
	Callback = function(on)
		if Window.SetAutoCollapseSidebar then
			Window.SetAutoCollapseSidebar(on)
		elseif Window.SetSidebarCollapsed then
			Window.SetSidebarCollapsed(on)
		end
	end,
})
settingsTab:AddThemePresets()
settingsTab:AddColorpicker({
	Title = "Accent color",
	Default = Zenless.Theme.Accent,
	Callback = function(c) Zenless:SetAccent(c) end,
})
settingsTab:AddInfoGrid({
	{ label = "Library", value = "Local/URL" },
	{ label = "Drawing", value = HasDrawing and "Yes" or "No" },
	{ label = "Version", value = tostring(Zenless.Version or "?") },
	{ label = "Brand", value = "ZENLESS" },
})
settingsTab:AddDivider()
settingsTab:AddSection("SESSION")
settingsTab:AddButton({
	Title = "Unload hub",
	Primary = true,
	Confirm = { Title = "Unload?", Text = "Destroy the hub UI?" },
	Callback = unloadAll,
})
pcall(function()
	if combat.SetBadge then combat:SetBadge("AIM") end
end)

Zenless:SelectTab(combat)
Zenless:Notify({
	Title = "ZENLESS",
	Content = "Aimbot + ESP loaded from library. Enable features in tabs.",
	Type = "success",
	Duration = 3.2,
})

print("[ZENLESS] AimbotExample ready — library v" .. tostring(Zenless.Version or "?"))
