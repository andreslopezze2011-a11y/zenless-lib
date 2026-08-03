-- Milky Hub - Volleyball Legends
-- Key: milky.orender.com online verify (custom UI). Temp offline key: owner (trim, case-insensitive).
-- Discord (secondary): https://discord.gg/Mp3dmkhJ76
-- Prefer local MilkyHub.lua / FluentGui.lua; else fetch LIBRARY_URL.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local ACCENT = Color3.fromRGB(255, 120, 160)
local ACCENT_SOFT = Color3.fromRGB(255, 170, 200)
local KEY_FILE = "milky_hub_key.txt"
-- Temp local bypass (documented as "owner"); matched trim + case-insensitive
local TEMP_OWNER_KEY = "owner"
local ORENDER_BASE = "https://milky.orender.com"
local ORENDER_LIST_URLS = {
	ORENDER_BASE .. "/keys.txt",
	ORENDER_BASE .. "/raw",
	ORENDER_BASE .. "/keys",
	ORENDER_BASE .. "/raw/keys",
}
local ORENDER_VERIFY_FMT = ORENDER_BASE .. "/api/verify?key=%s"
local GET_KEY_URL = ORENDER_BASE
local DISCORD_LINK = "https://discord.gg/Mp3dmkhJ76"
local HTTP_TIMEOUT = 6
local LicenseTier = "none"
local UsedOwnerKey = false

local function trimKey(s)
	s = tostring(s or "")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	return s
end

local function normalizeKey(s)
	s = trimKey(s)
	s = string.gsub(s, "%s+", "")
	return string.upper(s)
end

local function isOwnerKey(raw)
	return string.lower(trimKey(raw)) == TEMP_OWNER_KEY
end

local function httpGet(url)
	if type(url) ~= "string" or url == "" then
		return nil, "empty url"
	end
	local done, body, err = false, nil, nil
	task.spawn(function()
		local ok, res = pcall(function()
			local reqFn = (typeof(http_request) == "function" and http_request)
				or (typeof(request) == "function" and request)
				or (syn and syn.request)
			if reqFn then
				local resp = reqFn({
					Url = url,
					Method = "GET",
					Headers = { ["User-Agent"] = "Mozilla/5.0", ["Accept"] = "*/*" },
				})
				if type(resp) == "table" then
					return resp.Body or resp.body
				end
				return resp
			end
			if game and game.HttpGet then
				return game:HttpGet(url)
			end
			error("no http function")
		end)
		if ok then
			body = res
		else
			err = res
		end
		done = true
	end)
	local t0 = os.clock()
	while not done and (os.clock() - t0) < HTTP_TIMEOUT do
		task.wait(0.05)
	end
	if not done then
		return nil, "timed out (" .. tostring(HTTP_TIMEOUT) .. "s)"
	end
	if type(body) ~= "string" or body == "" then
		return nil, tostring(err or "empty response")
	end
	return body, nil
end

local function isHtml(body)
	local head = string.sub(string.lower(body or ""), 1, 200)
	return string.find(head, "<!doctype", 1, true)
		or string.find(head, "<html", 1, true)
		or string.find(head, "<script", 1, true)
end

local function responseSaysValid(body)
	if type(body) ~= "string" or isHtml(body) then
		return false
	end
	local low = string.lower(body)
	if string.find(low, '"valid"%s*:%s*true') or string.find(low, '"success"%s*:%s*true') then
		return true
	end
	if string.find(low, "whitelisted", 1, true) or string.find(low, "authorized", 1, true) then
		return true
	end
	local trimmed = trimKey(body)
	local tlow = string.lower(trimmed)
	return tlow == "1"
		or tlow == "true"
		or tlow == "valid"
		or tlow == "success"
		or tlow == "ok"
		or tlow == "yes"
end

local function parseKeyList(body)
	local keys = {}
	if type(body) ~= "string" or isHtml(body) then
		return keys
	end
	for line in string.gmatch(body, "[^\r\n]+") do
		local trimmed = trimKey(line)
		if trimmed ~= "" and not string.find(trimmed, "^#") and not string.find(trimmed, "^%-%-") then
			keys[normalizeKey(trimmed)] = true
		end
	end
	return keys
end

local function validateWithORender(raw)
	local key = trimKey(raw)
	local n = normalizeKey(key)
	if n == "" then
		return false, nil, "Enter a license key."
	end

	local verifyUrl = string.format(ORENDER_VERIFY_FMT, key)
	local body = httpGet(verifyUrl)
	if body and responseSaysValid(body) then
		local prem = string.find(string.lower(body), "premium", 1, true)
		return true, prem and "premium" or "standard", nil
	end

	local sawRealList = false
	for _, url in ipairs(ORENDER_LIST_URLS) do
		local listBody = httpGet(url)
		if listBody and not isHtml(listBody) then
			local keys = parseKeyList(listBody)
			if keys[n] then
				local prem = string.find(n, "PREMIUM", 1, true) or string.find(n, "VIP", 1, true)
				return true, prem and "premium" or "standard", nil
			end
			if next(keys) ~= nil then
				sawRealList = true
			end
		end
	end
	if sawRealList then
		return false, nil, "Invalid key."
	end
	return false, nil, "Key server unreachable."
end

-- owner always unlocks offline; all other keys go through ORender
local function validateKey(raw)
	if isOwnerKey(raw) then
		return true, "owner", nil
	end
	return validateWithORender(raw)
end

local function loadSavedKey()
	if typeof(readfile) ~= "function" then
		return nil
	end
	local ok, data = pcall(function()
		if typeof(isfile) == "function" and not isfile(KEY_FILE) then
			return nil
		end
		return readfile(KEY_FILE)
	end)
	if not ok or type(data) ~= "string" then
		return nil
	end
	return string.match(data, "^([^\r\n]+)") or data
end

local function saveAcceptedKey(raw, tier)
	pcall(function()
		if typeof(writefile) == "function" then
			writefile(KEY_FILE, tostring(trimKey(raw)) .. "\n" .. tostring(tier or "standard"))
		end
	end)
end

local function protectGui(gui)
	pcall(function()
		if syn and syn.protect_gui then
			syn.protect_gui(gui)
		end
	end)
	local ok = pcall(function()
		gui.Parent = game:GetService("CoreGui")
	end)
	if not ok then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function runCustomKeyGate()
	local saved = loadSavedKey()
	if saved and trimKey(saved) ~= "" then
		local ok, tier = validateKey(saved)
		if ok then
			LicenseTier = tier or "standard"
			UsedOwnerKey = (tier == "owner") or isOwnerKey(saved)
			return true
		end
	end

	local unlocked = false
	local done = false
	local anim = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local animFast = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local gui = Instance.new("ScreenGui")
	gui.Name = "MilkyORenderKeyGate"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	protectGui(gui)

	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.fromRGB(6, 3, 8)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 28)
	card.Size = UDim2.fromOffset(400, 340)
	card.BackgroundColor3 = Color3.fromRGB(22, 12, 18)
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Parent = gui
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 18)

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = ACCENT
	cardStroke.Thickness = 1
	cardStroke.Transparency = 0.55
	cardStroke.Parent = card

	local topSheen = Instance.new("Frame")
	topSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	topSheen.BackgroundTransparency = 0.94
	topSheen.BorderSizePixel = 0
	topSheen.Size = UDim2.new(1, 0, 0, 56)
	topSheen.Parent = card
	Instance.new("UICorner", topSheen).CornerRadius = UDim.new(0, 18)

	local accentLine = Instance.new("Frame")
	accentLine.BackgroundColor3 = ACCENT
	accentLine.BackgroundTransparency = 0.25
	accentLine.BorderSizePixel = 0
	accentLine.Position = UDim2.fromOffset(28, 0)
	accentLine.Size = UDim2.new(0, 36, 0, 3)
	accentLine.Parent = card

	local brand = Instance.new("TextLabel")
	brand.BackgroundTransparency = 1
	brand.Position = UDim2.fromOffset(28, 28)
	brand.Size = UDim2.new(1, -56, 0, 30)
	brand.Font = Enum.Font.GothamBlack
	brand.Text = "MILKY"
	brand.TextSize = 26
	brand.TextColor3 = Color3.fromRGB(255, 236, 244)
	brand.TextXAlignment = Enum.TextXAlignment.Left
	brand.Parent = card

	local brandHub = Instance.new("TextLabel")
	brandHub.BackgroundTransparency = 1
	brandHub.Position = UDim2.fromOffset(118, 32)
	brandHub.Size = UDim2.fromOffset(80, 26)
	brandHub.Font = Enum.Font.GothamBold
	brandHub.Text = "HUB"
	brandHub.TextSize = 22
	brandHub.TextColor3 = ACCENT
	brandHub.TextXAlignment = Enum.TextXAlignment.Left
	brandHub.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(28, 62)
	subtitle.Size = UDim2.new(1, -56, 0, 18)
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "Volleyball Legends"
	subtitle.TextSize = 13
	subtitle.TextColor3 = ACCENT_SOFT
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = card

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Position = UDim2.fromOffset(28, 96)
	note.Size = UDim2.new(1, -56, 0, 36)
	note.Font = Enum.Font.Gotham
	note.Text = "Enter your license key to continue.\nOnline keys are checked through milky.orender.com."
	note.TextSize = 12
	note.TextColor3 = Color3.fromRGB(176, 156, 166)
	note.TextWrapped = true
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.Parent = card

	local inputHost = Instance.new("Frame")
	inputHost.Position = UDim2.fromOffset(28, 148)
	inputHost.Size = UDim2.new(1, -56, 0, 44)
	inputHost.BackgroundColor3 = Color3.fromRGB(14, 8, 12)
	inputHost.BackgroundTransparency = 0.12
	inputHost.BorderSizePixel = 0
	inputHost.Parent = card
	Instance.new("UICorner", inputHost).CornerRadius = UDim.new(0, 12)
	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = Color3.fromRGB(255, 150, 185)
	inputStroke.Transparency = 0.72
	inputStroke.Thickness = 1
	inputStroke.Parent = inputHost

	local box = Instance.new("TextBox")
	box.BackgroundTransparency = 1
	box.Position = UDim2.fromOffset(14, 0)
	box.Size = UDim2.new(1, -28, 1, 0)
	box.Font = Enum.Font.GothamMedium
	box.PlaceholderText = "License key"
	box.PlaceholderColor3 = Color3.fromRGB(120, 100, 110)
	box.Text = saved and tostring(saved) or ""
	box.TextSize = 15
	box.TextColor3 = Color3.fromRGB(255, 242, 248)
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = inputHost

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(28, 200)
	status.Size = UDim2.new(1, -56, 0, 18)
	status.Font = Enum.Font.GothamMedium
	status.Text = ""
	status.TextSize = 12
	status.TextColor3 = Color3.fromRGB(180, 160, 170)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = card

	local unlockBtn = Instance.new("TextButton")
	unlockBtn.AutoButtonColor = false
	unlockBtn.Position = UDim2.fromOffset(28, 232)
	unlockBtn.Size = UDim2.new(1, -56, 0, 44)
	unlockBtn.BackgroundColor3 = ACCENT
	unlockBtn.BackgroundTransparency = 0.08
	unlockBtn.BorderSizePixel = 0
	unlockBtn.Font = Enum.Font.GothamBold
	unlockBtn.Text = "Unlock"
	unlockBtn.TextSize = 15
	unlockBtn.TextColor3 = Color3.fromRGB(36, 10, 22)
	unlockBtn.Parent = card
	Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 12)

	local getKeyBtn = Instance.new("TextButton")
	getKeyBtn.AutoButtonColor = false
	getKeyBtn.BackgroundTransparency = 1
	getKeyBtn.Position = UDim2.fromOffset(28, 286)
	getKeyBtn.Size = UDim2.new(1, -56, 0, 28)
	getKeyBtn.Font = Enum.Font.GothamMedium
	getKeyBtn.Text = "Get Key"
	getKeyBtn.TextSize = 13
	getKeyBtn.TextColor3 = ACCENT_SOFT
	getKeyBtn.Parent = card

	local busy = false

	local function setStatus(msg, color)
		status.Text = tostring(msg or "")
		status.TextColor3 = color or Color3.fromRGB(180, 160, 170)
	end

	unlockBtn.MouseEnter:Connect(function()
		if busy then
			return
		end
		TweenService:Create(unlockBtn, animFast, { BackgroundTransparency = 0 }):Play()
	end)
	unlockBtn.MouseLeave:Connect(function()
		TweenService:Create(unlockBtn, animFast, { BackgroundTransparency = 0.08 }):Play()
	end)
	getKeyBtn.MouseEnter:Connect(function()
		getKeyBtn.TextColor3 = Color3.fromRGB(255, 220, 235)
	end)
	getKeyBtn.MouseLeave:Connect(function()
		getKeyBtn.TextColor3 = ACCENT_SOFT
	end)

	local function closeGate(ok)
		unlocked = ok and true or false
		done = true
		TweenService:Create(card, animFast, {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.5, 40),
		}):Play()
		TweenService:Create(dim, animFast, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardStroke, animFast, { Transparency = 1 }):Play()
		task.delay(0.22, function()
			pcall(function()
				gui:Destroy()
			end)
		end)
	end

	local function tryUnlock()
		if busy then
			return
		end
		busy = true
		local raw = box.Text
		local offlineOwner = isOwnerKey(raw)
		if offlineOwner then
			setStatus("Checking key...", Color3.fromRGB(210, 190, 200))
		else
			setStatus("Checking with milky.orender.com...", Color3.fromRGB(210, 190, 200))
		end
		unlockBtn.Text = "Checking..."
		TweenService:Create(inputStroke, animFast, {
			Color = ACCENT_SOFT,
			Transparency = 0.45,
		}):Play()

		task.spawn(function()
			local ok, tier, err = validateKey(raw)
			if ok then
				LicenseTier = tier or "standard"
				UsedOwnerKey = (tier == "owner") or isOwnerKey(raw)
				saveAcceptedKey(raw, LicenseTier)
				setStatus("Access granted", Color3.fromRGB(130, 230, 170))
				unlockBtn.Text = "Unlocked"
				TweenService:Create(inputStroke, animFast, {
					Color = Color3.fromRGB(120, 220, 160),
					Transparency = 0.35,
				}):Play()
				task.wait(0.28)
				closeGate(true)
			else
				setStatus(err or "Invalid key.", Color3.fromRGB(255, 120, 140))
				unlockBtn.Text = "Unlock"
				TweenService:Create(inputStroke, animFast, {
					Color = Color3.fromRGB(255, 110, 130),
					Transparency = 0.35,
				}):Play()
				local base = card.Position
				for i = 1, 4 do
					card.Position = UDim2.new(base.X.Scale, ((i % 2 == 0) and 5 or -5), base.Y.Scale, base.Y.Offset)
					task.wait(0.03)
				end
				card.Position = base
				busy = false
			end
		end)
	end

	getKeyBtn.MouseButton1Click:Connect(function()
		local copied = false
		pcall(function()
			if setclipboard then
				setclipboard(GET_KEY_URL)
				copied = true
			end
		end)
		if copied then
			setStatus("Key link copied", Color3.fromRGB(140, 200, 255))
		else
			setStatus(GET_KEY_URL, Color3.fromRGB(140, 200, 255))
		end
	end)

	unlockBtn.MouseButton1Click:Connect(tryUnlock)
	box.FocusLost:Connect(function(enter)
		if enter then
			tryUnlock()
		end
	end)

	TweenService:Create(dim, anim, { BackgroundTransparency = 0.42 }):Play()
	TweenService:Create(card, anim, {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.06,
	}):Play()
	task.defer(function()
		pcall(function()
			box:CaptureFocus()
		end)
	end)

	while not done do
		task.wait(0.05)
	end
	return unlocked
end

if not runCustomKeyGate() then
	warn("[Milky Hub] Key not accepted. Exiting.")
	return
end

getgenv().MILKY_DEFER_BOOT = true
getgenv().ZENLESS_DEFER_BOOT = true
getgenv().MILKY_NO_LOADER = true
getgenv().ZENLESS_NO_LOADER = true

local LIBRARY_URL =
	"https://raw.githubusercontent.com/andreslopezze2011-a11y/zenless-lib/refs/heads/main/MilkyHub.lua"

pcall(function()
	local prev = getgenv().Milky or getgenv().Zenless
	if prev and type(prev.Unload) == "function" then
		pcall(function()
			prev:Unload()
		end)
		task.wait(0.2)
	end
	getgenv().Milky = nil
	getgenv().Zenless = nil
	getgenv().Fluent = nil
end)

local Milky
do
	local errors = {}

	local function isLibrary(t)
		return type(t) == "table"
			and (type(t.AddTab) == "function" or type(t.CreateWindow) == "function" or type(t.Notify) == "function")
	end

	local function tryLoad(src, label)
		if type(src) ~= "string" or #src < 64 then
			error(label .. ": empty / invalid source (" .. tostring(src and #src or 0) .. " bytes)")
		end
		local head = string.sub(src, 1, 200):lower()
		if string.find(head, "<!doctype") or string.find(head, "<html") then
			error(label .. ": got HTML page, not Lua library")
		end
		local fn, err = loadstring(src)
		if not fn then
			error(label .. ": compile failed - " .. tostring(err))
		end
		local okRun, lib = pcall(fn)
		if not okRun then
			error(label .. ": runtime error - " .. tostring(lib))
		end
		if not isLibrary(lib) then
			error(label .. ": script ran but did not return Milky Hub library table")
		end
		return lib
	end

	local function httpGetLib(url)
		local body, err = httpGet(url)
		if not body then
			error(err or "HttpGet failed")
		end
		return body
	end

	do
		local ok, result = pcall(function()
			assert(typeof(readfile) == "function", "readfile unavailable")
			local candidates = {
				"MilkyHub.lua",
				"FluentGui.lua",
				"Milky.lua",
				"workspace/MilkyHub.lua",
				"workspace/FluentGui.lua",
				"scripts/MilkyHub.lua",
				"scripts/FluentGui.lua",
			}
			local pathFind = nil
			if typeof(isfile) == "function" then
				for _, p in ipairs(candidates) do
					if isfile(p) then
						pathFind = p
						break
					end
				end
			else
				for _, p in ipairs(candidates) do
					local okRead = pcall(readfile, p)
					if okRead then
						pathFind = p
						break
					end
				end
			end
			assert(pathFind, "local MilkyHub.lua / FluentGui.lua not found")
			return tryLoad(readfile(pathFind), "local:" .. pathFind)
		end)
		if ok and isLibrary(result) then
			Milky = result
		else
			table.insert(errors, "local -> " .. tostring(result))
		end
	end

	if not Milky then
		local ok, result = pcall(function()
			return tryLoad(httpGetLib(LIBRARY_URL), "remote:MilkyHub.lua")
		end)
		if ok and isLibrary(result) then
			Milky = result
		else
			table.insert(errors, "remote -> " .. tostring(result))
		end
	end

	if not Milky then
		error(
			"Failed to load Milky Hub library.\n"
				.. "Put MilkyHub.lua / FluentGui.lua in your executor workspace, or fix LIBRARY_URL.\n"
				.. table.concat(errors, "\n")
		)
	end

	pcall(function()
		getgenv().Milky = Milky
		getgenv().Zenless = Milky
		getgenv().Fluent = Milky
		Milky.KeyTier = LicenseTier
		Milky.LicenseTier = LicenseTier
		Milky.Premium = (LicenseTier == "premium")
	end)
end

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = workspace.CurrentCamera

-- Global settings
_G.HitboxEnabled = false
_G.HitboxScale = 5.0
_G.PredictorEnabled = false
_G.PredictorColor = Color3.fromRGB(255, 50, 100)
_G.DirectionalJump = true
_G.AirMoveEnabled = false
_G.AirMoveSpeed = 50
_G.StretchedFOV = false
_G.ScoreSpooferEnabled = false
_G.SelectedScoreEffect = "CosmicSpiralScoreEffect"
_G.NoclipEnabled = false
_G.InfiniteJumpEnabled = false
_G.JumpPower = 50
_G.HighJumpEnabled = false
_G.HighJumpPower = 80

local hitboxPartName = "Ball_Vis_" .. tostring(math.random(1000, 9999))
local function findFirstPart(model)
	for _, v in ipairs(model:GetDescendants()) do
		if v:IsA("BasePart") then
			return v
		end
	end
end

local ScoreFolder = ReplicatedStorage:FindFirstChild("Assets")
	and ReplicatedStorage.Assets:FindFirstChild("ScoreEffect")
local function playEffect(name, pos)
	if not _G.ScoreSpooferEnabled or not ScoreFolder or type(name) ~= "string" then
		return
	end
	local mod = ScoreFolder:FindFirstChild(name)
	if mod then
		pcall(function()
			require(mod)(pos)
		end)
	end
end

local humanoid, hrp, origJumpPower
local function onChar(char)
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
	humanoid.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Landed then
			humanoid.AutoRotate = true
		end
	end)
end
if LocalPlayer.Character then
	onChar(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onChar)

UserInputService.JumpRequest:Connect(function()
	if not humanoid or not hrp then
		return
	end

	if _G.DirectionalJump then
		task.defer(function()
			task.wait(0.03)
			local dir = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
			if dir.Magnitude > 0 then
				hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir.Unit)
				humanoid.AutoRotate = false
			end
		end)
	end

	if _G.HighJumpEnabled then
		if not origJumpPower then
			origJumpPower = humanoid.JumpPower
		end
		humanoid.JumpPower = _G.HighJumpPower
		task.wait(0.01)
		if humanoid:GetState() == Enum.HumanoidStateType.Jumping then
			hrp.Velocity = Vector3.new(hrp.Velocity.X, hrp.Velocity.Y * 1.2, hrp.Velocity.Z)
		end
	elseif origJumpPower then
		humanoid.JumpPower = origJumpPower
		origJumpPower = nil
	end

	if _G.InfiniteJumpEnabled then
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			hrp.Velocity = Vector3.new(
				hrp.Velocity.X,
				_G.JumpPower * (0.9 + math.random() * 0.2),
				hrp.Velocity.Z
			)
		end
	end
end)

local groundRing = Instance.new("Part")
groundRing.Name = "MilkyLanding"
groundRing.Shape = Enum.PartType.Cylinder
groundRing.Size = Vector3.new(0.1, 7, 7)
groundRing.Anchored = true
groundRing.CanCollide = false
groundRing.Material = Enum.Material.Neon
groundRing.Transparency = 1
groundRing.Parent = Workspace

local arcFolder = Instance.new("Folder", Workspace)
arcFolder.Name = "MilkyArcs"
local arcs = {}
for _ = 1, 15 do
	local a = Instance.new("LineHandleAdornment")
	a.Length = 0
	a.Thickness = 5
	a.AlwaysOnTop = true
	a.Adornee = Workspace
	a.Parent = arcFolder
	table.insert(arcs, a)
end

local noclipBP
local function updateNoclip()
	if _G.NoclipEnabled and hrp and hrp.Parent then
		for _, p in ipairs(hrp.Parent:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
			end
		end
		if not noclipBP or not noclipBP.Parent then
			noclipBP = Instance.new("BodyPosition")
			noclipBP.MaxForce = Vector3.new(0, 4000, 0)
			noclipBP.D = 1000
			noclipBP.P = 2000
			noclipBP.Parent = hrp
		end
		local origin = hrp.Position
		local direction = Vector3.new(0, -500, 0)
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { hrp.Parent }
		params.FilterType = Enum.RaycastFilterType.Exclude
		local result = workspace:Raycast(origin, direction, params)
		local y = (result and result.Position.Y + 3) or hrp.Position.Y
		noclipBP.Position = Vector3.new(hrp.Position.X, y, hrp.Position.Z)
	else
		if noclipBP then
			noclipBP:Destroy()
			noclipBP = nil
		end
		if hrp and hrp.Parent then
			for _, p in ipairs(hrp.Parent:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = true
				end
			end
		end
	end
end

RunService.RenderStepped:Connect(function()
	if _G.HitboxEnabled then
		for _, model in ipairs(Workspace:GetChildren()) do
			if model:IsA("Model") and model.Name:match("^CLIENT_BALL_%d+$") then
				local ball = model:FindFirstChild(hitboxPartName)
				local ref = findFirstPart(model)
				if ref then
					if not ball then
						ball = Instance.new("Part", model)
						ball.Name = hitboxPartName
						ball.Shape = Enum.PartType.Ball
						ball.CanCollide = false
						ball.Transparency = 0.75
						ball.Material = Enum.Material.ForceField
						ball.Color = Color3.fromRGB(0, 255, 120)
					end
					ball.Size = Vector3.new(2, 2, 2)
						* math.max(0.5, _G.HitboxScale + (math.random(-5, 5) / 100))
					ball.CFrame = ref.CFrame
				end
			end
		end
	else
		for _, model in ipairs(Workspace:GetChildren()) do
			if model:IsA("Model") and model.Name:match("^CLIENT_BALL_%d+$") then
				local ball = model:FindFirstChild(hitboxPartName)
				if ball then
					ball:Destroy()
				end
			end
		end
	end

	if _G.StretchedFOV then
		Camera.FieldOfView = 110
	end

	if _G.AirMoveEnabled and humanoid and hrp then
		local state = humanoid:GetState()
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			local dir = humanoid.MoveDirection
			if dir.Magnitude > 0 then
				hrp.Velocity = Vector3.new(dir.X * _G.AirMoveSpeed, hrp.Velocity.Y, dir.Z * _G.AirMoveSpeed)
			end
		end
	end

	if _G.PredictorEnabled then
		local ball = nil
		for _, obj in ipairs(Workspace:GetChildren()) do
			if (obj:IsA("Model") and obj.Name:match("^CLIENT_BALL_%d+$")) or obj.Name == "Ball" then
				ball = obj:IsA("Model") and findFirstPart(obj) or obj
				if ball then
					break
				end
			end
		end
		if ball and ball:IsA("BasePart") then
			local pos, vel = ball.Position, ball.AssemblyLinearVelocity
			local g = 196.2
			local t = (vel.Y + math.sqrt(vel.Y ^ 2 + 2 * g * math.max(0, pos.Y))) / g
			local land = Vector3.new(pos.X + vel.X * t * 0.7, 0.5, pos.Z + vel.Z * t * 0.7)
			groundRing.Transparency = 0.25
			groundRing.Color = _G.PredictorColor
			groundRing.CFrame = CFrame.new(land) * CFrame.Angles(0, 0, math.rad(90))
			local dt = t / 15
			local prev = pos
			for i = 1, 15 do
				local ti = dt * i
				local cur = Vector3.new(
					pos.X + vel.X * ti * 0.7,
					pos.Y + vel.Y * ti - 0.5 * g * ti ^ 2,
					pos.Z + vel.Z * ti * 0.7
				)
				arcs[i].Color3 = _G.PredictorColor
				arcs[i].CFrame = CFrame.lookAt(prev, cur)
				arcs[i].Length = (cur - prev).Magnitude
				prev = cur
			end
		else
			groundRing.Transparency = 1
			for _, a in ipairs(arcs) do
				a.Length = 0
			end
		end
	else
		groundRing.Transparency = 1
		for _, a in ipairs(arcs) do
			a.Length = 0
		end
	end

	if _G.InfiniteJumpEnabled and humanoid and hrp then
		local state = humanoid:GetState()
		if
			(state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)
			and UserInputService:IsKeyDown(Enum.KeyCode.Space)
		then
			hrp.Velocity = Vector3.new(
				hrp.Velocity.X,
				math.max(hrp.Velocity.Y, _G.JumpPower * 0.7),
				hrp.Velocity.Z
			)
		end
	end

	updateNoclip()
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Volleyball" or child.Name == "Ball" then
		child.Touched:Connect(function(hit)
			if _G.ScoreSpooferEnabled and hit.Name:lower():match("court|floor|ground") then
				if child.AssemblyLinearVelocity.Magnitude > 10 then
					playEffect(_G.SelectedScoreEffect, child.Position)
				end
			end
		end)
	end
end)

local remote
pcall(function()
	remote = ReplicatedStorage:WaitForChild("Packages")
		:WaitForChild("_Index")
		:WaitForChild("sleitnick_knit@1.7.0")
		:WaitForChild("knit")
		:WaitForChild("Services")
		:WaitForChild("SeasonService")
		:WaitForChild("RF")
		:WaitForChild("RequestRankedReward")
end)

local Window = Milky:CreateWindow({
	Title = "Milky Hub | Volleyball Legends",
	Accent = Color3.fromRGB(255, 120, 160),
	MinimizeKey = Enum.KeyCode.RightShift,
})

pcall(function()
	Window.KeyTier = LicenseTier
	Window.LicenseTier = LicenseTier
	Window.Premium = (LicenseTier == "premium")
end)

local function addTab(cfg)
	if Window and type(Window.AddTab) == "function" then
		return Window:AddTab(cfg)
	end
	return Milky:AddTab(cfg)
end

local auto = addTab({ Title = "Automations", Icon = "bolt" })
auto:AddSection("Ranked Rewards")
auto:AddToggle({
	Title = "Auto Spins",
	Default = false,
	Callback = function(v)
		_G.L = v
		task.spawn(function()
			while _G.L do
				if remote then
					pcall(remote.InvokeServer, remote, 1)
				end
				task.wait(0.5)
			end
		end)
	end,
})
auto:AddToggle({
	Title = "Auto Yen",
	Default = false,
	Callback = function(v)
		_G.Y = v
		task.spawn(function()
			while _G.Y do
				if remote then
					pcall(remote.InvokeServer, remote, 2)
				end
				task.wait(0.6)
			end
		end)
	end,
})
auto:AddToggle({
	Title = "Auto Abilities",
	Default = false,
	Callback = function(v)
		_G.H = v
		task.spawn(function()
			while _G.H do
				if remote then
					pcall(remote.InvokeServer, remote, 4)
				end
				task.wait(1.5)
			end
		end)
	end,
})

local vis = addTab({ Title = "Visuals", Icon = "eye" })
vis:AddSection("Ball Modifications")
vis:AddToggle({
	Title = "Hitbox Expander",
	Default = false,
	Callback = function(v)
		_G.HitboxEnabled = v
		if v then
			hitboxPartName = "Ball_Vis_" .. tostring(math.random(1000, 9999))
		end
	end,
})
vis:AddSlider({
	Title = "Hitbox Scale",
	Min = 1,
	Max = 25,
	Default = 5,
	Callback = function(v)
		_G.HitboxScale = v
	end,
})
vis:AddToggle({
	Title = "Trajectory Predictor",
	Default = false,
	Callback = function(v)
		_G.PredictorEnabled = v
	end,
})
vis:AddColorpicker({
	Title = "Predictor Color",
	Default = Color3.fromRGB(255, 50, 100),
	Callback = function(c)
		_G.PredictorColor = c
		groundRing.Color = c
		for _, a in ipairs(arcs) do
			a.Color3 = c
		end
	end,
})
vis:AddSection("Score Effect Spoofer")
vis:AddToggle({
	Title = "Enable Spoofer",
	Default = false,
	Callback = function(v)
		_G.ScoreSpooferEnabled = v
	end,
})
local effects = {}
if ScoreFolder then
	for _, mod in ipairs(ScoreFolder:GetChildren()) do
		if mod:IsA("ModuleScript") and pcall(function()
			return type(require(mod)) == "function"
		end) then
			table.insert(effects, mod.Name)
		end
	end
	table.sort(effects)
end
vis:AddDropdown({
	Title = "Effect Module",
	Values = #effects > 0 and effects or { "CosmicSpiralScoreEffect" },
	Default = effects[1] or "CosmicSpiralScoreEffect",
	Callback = function(v)
		_G.SelectedScoreEffect = v
	end,
})
vis:AddButton({
	Title = "Test Effect",
	Callback = function()
		local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local old = _G.ScoreSpooferEnabled
			_G.ScoreSpooferEnabled = true
			playEffect(_G.SelectedScoreEffect, root.Position + Vector3.new(0, 2, 0))
			_G.ScoreSpooferEnabled = old
		end
	end,
})

local mov = addTab({ Title = "Movement", Icon = "user" })
mov:AddToggle({
	Title = "Directional Jump",
	Default = true,
	Callback = function(v)
		_G.DirectionalJump = v
	end,
})
mov:AddToggle({
	Title = "Air Movement",
	Default = false,
	Callback = function(v)
		_G.AirMoveEnabled = v
	end,
})
mov:AddSlider({
	Title = "Air Speed",
	Min = 10,
	Max = 150,
	Default = 50,
	Callback = function(v)
		_G.AirMoveSpeed = v
	end,
})
mov:AddToggle({
	Title = "Stretched FOV",
	Default = false,
	Callback = function(v)
		_G.StretchedFOV = v
		if not v then
			Camera.FieldOfView = 70
		end
	end,
})

local adv = addTab({ Title = "Advanced", Icon = "shield" })
adv:AddSection("Risk Features")
adv:AddParagraph("Warning", "May be bannable. Use at your own risk.")
adv:AddToggle({
	Title = "Noclip",
	Default = false,
	Callback = function(v)
		_G.NoclipEnabled = v
		if not v and noclipBP then
			noclipBP:Destroy()
			noclipBP = nil
		end
	end,
})
adv:AddToggle({
	Title = "Infinite Jump",
	Default = false,
	Callback = function(v)
		_G.InfiniteJumpEnabled = v
	end,
})
adv:AddSlider({
	Title = "Jump Power",
	Min = 20,
	Max = 120,
	Default = 50,
	Callback = function(v)
		_G.JumpPower = v
	end,
})
adv:AddToggle({
	Title = "High Jump",
	Default = false,
	Callback = function(v)
		_G.HighJumpEnabled = v
		if not v and humanoid and origJumpPower then
			humanoid.JumpPower = origJumpPower
			origJumpPower = nil
		end
	end,
})
adv:AddSlider({
	Title = "High Jump Power",
	Min = 50,
	Max = 150,
	Default = 80,
	Callback = function(v)
		_G.HighJumpPower = v
	end,
})

local inf = addTab({ Title = "Info", Icon = "star" })
inf:AddSection("Community")
inf:AddButton({
	Title = "Join Discord",
	Primary = true,
	Callback = function()
		if setclipboard then
			setclipboard(KEY_LINK)
		end
		Milky:Notify({
			Title = "Copied!",
			Content = "Discord link copied.",
			Type = "success",
			Duration = 2,
		})
	end,
})
inf:AddParagraph("Key Info", "Keys via milky.orender.com\nGet Key opens the key site.")
inf:AddDivider()
inf:AddParagraph("Credits", "UI: Milky Hub | Script: Volleyball Legends")
inf:AddParagraph("License", "Key tier: " .. string.upper(tostring(LicenseTier)))


-- Reveal window AFTER tabs exist (fixes empty shell after Access granted / Booting ScriptHub)
pcall(function()
	Milky.KeyTier = LicenseTier
	Milky.LicenseTier = LicenseTier
	Milky.Premium = (LicenseTier == "premium")
	if Window then
		Window.KeyTier = LicenseTier
		Window.LicenseTier = LicenseTier
		Window.Premium = (LicenseTier == "premium")
	end
end)
pcall(function()
	if Window and type(Window.Show) == "function" then
		Window.Show()
	elseif type(Milky.Boot) == "function" then
		Milky:Boot({ Loader = false })
	end
end)
pcall(function()
	if Milky.Notify then
		Milky:Notify({
			Title = "Ready",
			Content = UsedOwnerKey and "Owner access enabled." or "Volleyball hub loaded.",
			Type = "success",
			Duration = 2.5,
		})
	end
end)
