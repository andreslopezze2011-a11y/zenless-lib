--[[
	ZENLESS v6 — Universal Script GUI Library (black / grey / silver)

	Load:
		local Zenless = loadstring(readfile("FluentGui.lua"))()

	Build UI:
		local Window = Zenless:CreateWindow({ Title = "My Hub", SizePreset = "Normal" })
		local Tab = Zenless:AddTab({ Title = "Combat", Icon = "target" })
		Tab:AddSlider({ Title = "FOV", Min = 0, Max = 100, Step = 1, Flag = "fov" })
		Tab:AddDropdown({ Title = "Mode", Values = {...}, Multi = true })
		Zenless:Notify({ Title = "Loaded", Type = "success", Pinned = false })

	v6 highlights: edge snap, tab drag/close/Ctrl+Tab, notif history,
	config autosave (Flag=), resize, pin, themes, new components.

	Flags (getgenv before load): ZENLESS_DEMO, ZENLESS_NO_LOADER, ZENLESS_DEV

	Key system (blocks until unlocked):
		local ok = Zenless:KeySystem({
			Title = "ZENLESS",
			Subtitle = "Enter your key",
			Note = "Get a key from Discord",
			Key = "ZENLESS-DEMO",           -- or Keys = { "A", "B" }
			-- OnlineKey = "https://pastebin.com/raw/xxxx",
			SaveKey = true,
			FileName = "zenless_key.txt",
			KeyLink = "https://discord.gg/yourinvite",
		})
		if not ok then return end
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local TextService = game:GetService("TextService")

local player = Players.LocalPlayer
if not player then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end

local LIBRARY_VERSION = "6.0"
local CONFIG_VERSION = 6
local CONFIG_FILE = "zenless_config.json"
local SNAP_PX = 20
local BOOT_TIME = os.clock()

-- ============ THEME (black / grey / silver) ============
local Theme = {
	Background   = Color3.fromRGB(14, 14, 16),
	Sidebar      = Color3.fromRGB(18, 18, 20),
	Layer        = Color3.fromRGB(24, 24, 26),
	Element      = Color3.fromRGB(34, 34, 38),
	ElementHover = Color3.fromRGB(48, 48, 54),
	ElementPress = Color3.fromRGB(26, 26, 30),
	Accent       = Color3.fromRGB(198, 198, 208), -- silver
	AccentHover  = Color3.fromRGB(230, 230, 238),
	AccentSoft   = Color3.fromRGB(140, 140, 150),
	Text         = Color3.fromRGB(245, 245, 248),
	SubText      = Color3.fromRGB(190, 190, 198),
	Stroke       = Color3.fromRGB(88, 88, 96),
	Highlight    = Color3.fromRGB(255, 255, 255),
	Success      = Color3.fromRGB(90, 200, 120),
	Warning      = Color3.fromRGB(210, 170, 80),
	Error        = Color3.fromRGB(210, 70, 70),
}
local DarkThemeBackup = table.clone and table.clone(Theme) or nil
if not DarkThemeBackup then
	DarkThemeBackup = {}
	for k, v in pairs(Theme) do DarkThemeBackup[k] = v end
end

local accentRegistry = {}
local function registerAccent(obj, prop)
	table.insert(accentRegistry, { obj = obj, prop = prop })
end

local textRegistry = {}
local function registerText(obj)
	if obj then table.insert(textRegistry, obj) end
end

local Anim = {
	Fast   = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Smooth = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Spring = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Snap   = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Linear = TweenInfo.new(0.2, Enum.EasingStyle.Linear),
	Sidebar = TweenInfo.new(0.34, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Minimize = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

-- ============ V6 FLAGS / SERVICES ============
local Flags = {
	NoAnimations = false,
	ReduceMotion = false,
	DisableParticles = false,
	DisableGrid = false,
	DisableDust = false,
	LazyTabs = false,
	HighContrast = false,
	Monochrome = false,
	LargeHitboxes = false,
	ClickThrough = false,
	AlwaysOnTop = false,
	SilentNotifications = false,
	DoNotDisturb = false,
	CompactNotifications = false,
	LockLayout = false,
	EdgeSnap = true,
	SidebarCollapsed = false,
	AutoCollapseSidebar = true,
	Fullscreen = false,
	SideBySide = false,
	RainbowBorder = false,
	TransparencyMode = false,
	LightMode = false,
	Clock24h = true,
	DebounceMs = 60,
	UnfocusedOpacity = 0,
	NotifVolume = 0.35,
	UiScale = 1,
	Font = Enum.Font.Gotham,
	ParticleFpsThreshold = 30,
	DndStartHour = -1,
	DndEndHour = -1,
}

local ConfigData = {
	version = CONFIG_VERSION,
	flags = {},
	values = {},
	theme = {},
	window = {},
	tabs = { order = {}, favorites = {}, colors = {}, badges = {} },
	recentColors = {},
	profiles = {},
	achievements = {},
}

local State = {
	flagListeners = {},
	consoleLog = {},
	undoStack = {},
	redoStack = {},
	focusables = {},
	toggleGroups = {},
	controlRegistry = {},
	notifHistory = {},
	notifQueue = {},
	progressNotifs = {},
	recentTabs = {},
	tabFolders = {},
	uiFont = Enum.Font.Gotham,
	uiScaleValue = 1,
	savedWindowPos = nil,
	savedWindowSize = nil,
	currentPreset = "Normal",
	pinnedWindow = false,
	windowOpacity = 0,
	unfocusedOpacity = 0,
	lastInteraction = os.clock(),
	soundMute = false,
	confirmModal = nil,
	historyPanel = nil,
	ctxMenu = nil,
	splitSecondTab = nil,
	floatingWindows = {},
	inspectorEnabled = false,
	profilerMarks = {},
	keyGateActive = false,
}

local function safeCall(fn, ...)
	if type(fn) ~= "function" then return end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		table.insert(State.consoleLog, 1, { t = os.clock(), level = "error", msg = tostring(a) })
		while #State.consoleLog > 200 do table.remove(State.consoleLog) end
		warn("[ZENLESS]", a)
	end
	return ok, a, b, c
end

local function debounced(fn, ms)
	ms = ms or Flags.DebounceMs or 60
	local token = 0
	return function(...)
		token += 1
		local my = token
		local args = table.pack(...)
		task.delay(ms / 1000, function()
			if my == token then
				safeCall(fn, table.unpack(args, 1, args.n))
			end
		end)
	end
end

local InstancePool = { buckets = {} }
function InstancePool.get(class)
	local b = InstancePool.buckets[class]
	if b and #b > 0 then
		local obj = table.remove(b)
		obj.Parent = nil
		return obj
	end
	return Instance.new(class)
end
function InstancePool.release(obj)
	if not obj then return end
	obj.Parent = nil
	local class = obj.ClassName
	InstancePool.buckets[class] = InstancePool.buckets[class] or {}
	if #InstancePool.buckets[class] < 40 then
		table.insert(InstancePool.buckets[class], obj)
	else
		obj:Destroy()
	end
end

local function encodeJson(t)
	local ok, s = pcall(function() return HttpService:JSONEncode(t) end)
	return ok and s or nil
end
local function decodeJson(s)
	local ok, t = pcall(function() return HttpService:JSONDecode(s) end)
	return ok and t or nil
end

local function b64encode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	return ((data:gsub(".", function(x)
		local r, n = "", x:byte()
		for i = 8, 1, -1 do r = r .. (n % 2 ^ i - n % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
		if #x < 6 then return "" end
		local c = 0
		for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
		return b:sub(c + 1, c + 1)
	end) .. ({ "", "==", "=" })[#data % 3 + 1])
end
local function b64decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = data:gsub("[^" .. b .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then return "" end
		local r, f = "", (b:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end

local function saveConfigFile()
	ConfigData.version = CONFIG_VERSION
	ConfigData.flags = {}
	for k, v in pairs(Flags) do
		if type(v) ~= "function" then ConfigData.flags[k] = v end
	end
	ConfigData.theme.Accent = { Theme.Accent.R, Theme.Accent.G, Theme.Accent.B }
	local payload = encodeJson(ConfigData)
	if not payload then return false end
	local ok = pcall(function()
		if typeof(writefile) == "function" then writefile(CONFIG_FILE, payload) end
	end)
	return ok
end

local function loadConfigFile()
	local ok, raw = pcall(function()
		if typeof(readfile) == "function" and (typeof(isfile) ~= "function" or isfile(CONFIG_FILE)) then
			return readfile(CONFIG_FILE)
		end
		return nil
	end)
	if not ok or type(raw) ~= "string" then return false end
	local data = decodeJson(raw)
	if type(data) ~= "table" then return false end
	ConfigData = data
	ConfigData.version = CONFIG_VERSION
	ConfigData.values = ConfigData.values or {}
	ConfigData.flags = ConfigData.flags or {}
	ConfigData.tabs = ConfigData.tabs or { order = {}, favorites = {}, colors = {}, badges = {} }
	ConfigData.recentColors = ConfigData.recentColors or {}
	ConfigData.profiles = ConfigData.profiles or {}
	ConfigData.achievements = ConfigData.achievements or {}
	for k, v in pairs(ConfigData.flags) do
		if Flags[k] ~= nil then Flags[k] = v end
	end
	return true
end

local function setFlag(name, value)
	Flags[name] = value
	if State.flagListeners[name] then
		for _, fn in ipairs(State.flagListeners[name]) do safeCall(fn, value) end
	end
	task.defer(saveConfigFile)
end

local function onFlag(name, fn)
	State.flagListeners[name] = State.flagListeners[name] or {}
	table.insert(State.flagListeners[name], fn)
end

local function pushUndo(entry)
	table.insert(State.undoStack, entry)
	while #State.undoStack > 40 do table.remove(State.undoStack, 1) end
	for i = #State.redoStack, 1, -1 do State.redoStack[i] = nil end
end

local function colorToHex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function hexToColor(hex)
	hex = tostring(hex or ""):gsub("#", "")
	if #hex ~= 6 then return nil end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

local function playUiSound(kind)
	if State.soundMute or Flags.NotifVolume <= 0 then return end
	local freqs = { open = 880, close = 440, notif = 660, click = 520, error = 220 }
	local ok, s = pcall(function()
		local sound = Instance.new("Sound")
		sound.Volume = (Flags.NotifVolume or 0.35) * (kind == "error" and 0.5 or 0.25)
		sound.PlayOnRemove = false
		-- soft click via short tone asset fallback
		sound.SoundId = "rbxassetid://6895079853"
		sound.PlaybackSpeed = (freqs[kind] or 600) / 600
		sound.Parent = SoundService
		sound:Play()
		task.delay(1.2, function() if sound then sound:Destroy() end end)
		return sound
	end)
end

local function tween(obj, info, props)
	if Flags.NoAnimations then
		for k, v in pairs(props) do
			pcall(function() obj[k] = v end)
		end
		return { Play = function() end, Cancel = function() end, Completed = { Wait = function() end, Connect = function() end } }
	end
	if Flags.ReduceMotion and typeof(info) == "TweenInfo" then
		info = TweenInfo.new(math.min(info.Time, 0.12), Enum.EasingStyle.Linear, info.EasingDirection)
	end
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

pcall(loadConfigFile)

-- Helpers MUST be defined before VisualFX (createGridOverlay / sparkBurst call these)
local function make(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = inst
		end
	end
	return inst
end

local function corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness, transparency)
	return make("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

--[[
	Frame-drawn icons (no unicode — Gotham can't render most glyphs).
	Usage: local icon = drawIcon(parent, "target", Theme.Accent, 16)
	       icon.SetColor(newColor)
]]
local IconAliases = {
	["c"] = "target", combat = "target", aimbot = "target", crosshair = "target",
	["e"] = "eye", esp = "eye", visuals = "eye", view = "eye",
	["w"] = "world", world = "world", misc = "world", globe = "world",
	["p"] = "user", player = "user", profile = "user", person = "user",
	["s"] = "settings", settings = "settings", gear = "settings", options = "settings",
	["h"] = "home", home = "home",
	["*"] = "star", star = "star", extras = "star",
	x = "close", close = "close",
	["-"] = "minus", minimize = "minus", minus = "minus",
	["+"] = "plus", plus = "plus",
	bolt = "bolt", zap = "bolt",
	shield = "shield",
	box = "box",
	chat = "chat", notify = "chat",
	search = "search",
	grid = "grid",
}

local function resolveIconName(name)
	if type(name) ~= "string" or name == "" then return "dot" end
	local key = string.lower(name)
	-- rbxasset / http image passthrough
	if string.find(key, "rbxasset", 1, true) or string.find(key, "http", 1, true) then
		return name
	end
	return IconAliases[key] or key
end

local function drawIcon(parent, name, color, pixelSize)
	color = color or Theme.Accent
	pixelSize = pixelSize or 16
	name = resolveIconName(name)

	local host = make("Frame", {
		Name = "Icon_" .. tostring(name),
		Size = UDim2.fromOffset(pixelSize, pixelSize),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = (parent and parent.ZIndex or 1) + 1,
	})
	host.Parent = parent

	local parts = {}

	local function add(props, kids)
		props.ZIndex = host.ZIndex
		props.BorderSizePixel = props.BorderSizePixel or 0
		local f = make("Frame", props, kids)
		f.Parent = host
		table.insert(parts, f)
		return f
	end

	local function bar(x, y, w, h, rot)
		return add({
			Size = UDim2.fromOffset(w, h),
			Position = UDim2.fromOffset(x, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			Rotation = rot or 0,
		}, { corner(math.clamp(math.floor(h / 2), 1, 4)) })
	end

	local function circle(x, y, d, filled, thick)
		local f = add({
			Size = UDim2.fromOffset(d, d),
			Position = UDim2.fromOffset(x, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BackgroundTransparency = filled and 0 or 1,
		}, { corner(math.ceil(d / 2)) })
		if not filled then
			local s = stroke(color, thick or 1.5, 0)
			s.Parent = f
			table.insert(parts, s)
		end
		return f
	end

	-- Image icons
	if string.find(tostring(name), "rbxasset", 1, true) or string.find(tostring(name), "http", 1, true) then
		local img = make("ImageLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = name,
			ImageColor3 = color,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = host.ZIndex,
		})
		img.Parent = host
		table.insert(parts, img)
	elseif name == "close" then
		bar(pixelSize / 2, pixelSize / 2, pixelSize * 0.72, 2, 45)
		bar(pixelSize / 2, pixelSize / 2, pixelSize * 0.72, 2, -45)
	elseif name == "minus" then
		bar(pixelSize / 2, pixelSize / 2, pixelSize * 0.62, 2, 0)
	elseif name == "plus" then
		bar(pixelSize / 2, pixelSize / 2, pixelSize * 0.62, 2, 0)
		bar(pixelSize / 2, pixelSize / 2, 2, pixelSize * 0.62, 0)
	elseif name == "home" then
		-- roof
		bar(pixelSize / 2, pixelSize * 0.38, pixelSize * 0.55, 2, 40)
		bar(pixelSize / 2, pixelSize * 0.38, pixelSize * 0.55, 2, -40)
		-- body
		add({
			Size = UDim2.fromOffset(pixelSize * 0.48, pixelSize * 0.38),
			Position = UDim2.fromOffset(pixelSize / 2, pixelSize * 0.68),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { corner(2), stroke(color, 1.5, 0) })
	elseif name == "user" then
		circle(pixelSize / 2, pixelSize * 0.32, pixelSize * 0.32, false, 1.5)
		add({
			Size = UDim2.fromOffset(pixelSize * 0.7, pixelSize * 0.34),
			Position = UDim2.fromOffset(pixelSize / 2, pixelSize * 0.78),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { corner(8), stroke(color, 1.5, 0) })
	elseif name == "eye" then
		add({
			Size = UDim2.fromOffset(pixelSize * 0.85, pixelSize * 0.5),
			Position = UDim2.fromOffset(pixelSize / 2, pixelSize / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { corner(10), stroke(color, 1.5, 0) })
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.22, true)
	elseif name == "target" then
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.78, false, 1.4)
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.38, false, 1.4)
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.14, true)
		bar(pixelSize / 2, pixelSize * 0.12, 2, pixelSize * 0.18, 0)
		bar(pixelSize / 2, pixelSize * 0.88, 2, pixelSize * 0.18, 0)
		bar(pixelSize * 0.12, pixelSize / 2, pixelSize * 0.18, 2, 0)
		bar(pixelSize * 0.88, pixelSize / 2, pixelSize * 0.18, 2, 0)
	elseif name == "world" then
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.82, false, 1.5)
		bar(pixelSize / 2, pixelSize / 2, pixelSize * 0.82, 1.5, 0)
		add({
			Size = UDim2.fromOffset(pixelSize * 0.38, pixelSize * 0.82),
			Position = UDim2.fromOffset(pixelSize / 2, pixelSize / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { corner(20), stroke(color, 1.4, 0) })
	elseif name == "settings" then
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.28, false, 1.5)
		for i = 0, 5 do
			local ang = math.rad(i * 60)
			local cx = pixelSize / 2 + math.cos(ang) * pixelSize * 0.34
			local cy = pixelSize / 2 + math.sin(ang) * pixelSize * 0.34
			bar(cx, cy, pixelSize * 0.2, 2.2, i * 60)
		end
	elseif name == "star" then
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.2, true)
		for i = 0, 3 do
			bar(pixelSize / 2, pixelSize / 2, pixelSize * 0.7, 2, i * 45)
		end
	elseif name == "bolt" then
		bar(pixelSize * 0.55, pixelSize * 0.32, pixelSize * 0.45, 2.2, -55)
		bar(pixelSize * 0.45, pixelSize * 0.68, pixelSize * 0.45, 2.2, -55)
		bar(pixelSize / 2, pixelSize / 2, pixelSize * 0.42, 2.2, 0)
	elseif name == "shield" then
		add({
			Size = UDim2.fromOffset(pixelSize * 0.62, pixelSize * 0.72),
			Position = UDim2.fromOffset(pixelSize / 2, pixelSize / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { corner(4), stroke(color, 1.5, 0) })
		bar(pixelSize / 2, pixelSize * 0.45, 2, pixelSize * 0.28, 0)
	elseif name == "box" then
		add({
			Size = UDim2.fromOffset(pixelSize * 0.7, pixelSize * 0.7),
			Position = UDim2.fromOffset(pixelSize / 2, pixelSize / 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { corner(3), stroke(color, 1.5, 0) })
	elseif name == "chat" then
		add({
			Size = UDim2.fromOffset(pixelSize * 0.72, pixelSize * 0.5),
			Position = UDim2.fromOffset(pixelSize / 2, pixelSize * 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, { corner(5), stroke(color, 1.5, 0) })
		bar(pixelSize * 0.38, pixelSize * 0.78, pixelSize * 0.22, 2, 40)
	elseif name == "search" then
		circle(pixelSize * 0.42, pixelSize * 0.42, pixelSize * 0.48, false, 1.5)
		bar(pixelSize * 0.72, pixelSize * 0.72, pixelSize * 0.32, 2, 45)
	elseif name == "grid" then
		for r = 0, 1 do
			for c = 0, 1 do
				add({
					Size = UDim2.fromOffset(pixelSize * 0.28, pixelSize * 0.28),
					Position = UDim2.fromOffset(pixelSize * (0.28 + c * 0.44), pixelSize * (0.28 + r * 0.44)),
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
				}, { corner(2), stroke(color, 1.3, 0) })
			end
		end
	else
		-- default: soft diamond / dot
		circle(pixelSize / 2, pixelSize / 2, pixelSize * 0.28, true)
	end

	-- Collect strokes created as children of shapes
	for _, p in ipairs(host:GetDescendants()) do
		if p:IsA("UIStroke") then
			table.insert(parts, p)
		end
	end

	local api = {
		Host = host,
		SetColor = function(c)
			for _, p in ipairs(parts) do
				if p:IsA("Frame") then
					if p.BackgroundTransparency < 1 then
						p.BackgroundColor3 = c
					end
				elseif p:IsA("UIStroke") then
					p.Color = c
				elseif p:IsA("ImageLabel") then
					p.ImageColor3 = c
				end
			end
		end,
		Destroy = function()
			host:Destroy()
		end,
	}
	return api
end

-- Public icon list for library consumers
local IconNames = {
	"target", "eye", "world", "user", "settings", "home", "star",
	"close", "minus", "plus", "bolt", "shield", "box", "chat", "search", "grid", "dot",
}

--[[
	Rounded metallic rim + traveling silver sheen.
	Uses UICorner + UIStroke (no square edge rectangles).
]]
local function attachPerimeterLight(parent, opts)
	opts = opts or {}
	local z = opts.ZIndex or 42
	local radius = opts.CornerRadius or 12
	local period = opts.Period or 2.8
	local strokeThick = opts.Thickness or 1.5

	local host = make("Frame", {
		Name = "MetallicRim",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = z,
	}, {
		corner(radius),
		stroke(Color3.fromRGB(170, 170, 180), strokeThick, 0.4),
	})
	host.Parent = parent

	-- Thin sheen only — no side glow / trail blob
	local light = make("Frame", {
		Name = "SheenLight",
		Size = UDim2.fromOffset(36, 2),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ZIndex = z + 2,
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, { corner(999) })
	light.Parent = host

	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.4, 0.35),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.6, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}).Parent = light

	-- Point on a rounded-rect perimeter (clockwise, starts mid-top)
	local function pointOnRoundedRect(u, w, h, r)
		r = math.clamp(r, 0, math.min(w, h) * 0.5)
		local sh = math.max(0, w - 2 * r)
		local sv = math.max(0, h - 2 * r)
		local arc = (math.pi * 0.5) * r
		local peri = 2 * sh + 2 * sv + 4 * arc
		if peri <= 0 then
			return w * 0.5, 0, 0
		end
		local d = (u % 1) * peri

		-- 1) top straight
		if d <= sh then
			return r + d, 1, 0
		end
		d -= sh
		-- 2) top-right corner
		if d <= arc then
			local ang = -math.pi * 0.5 + (d / math.max(arc, 1e-4)) * (math.pi * 0.5)
			return (w - r) + math.cos(ang) * r, r + math.sin(ang) * r, math.deg(ang) + 90
		end
		d -= arc
		-- 3) right straight
		if d <= sv then
			return w - 1, r + d, 90
		end
		d -= sv
		-- 4) bottom-right corner
		if d <= arc then
			local ang = 0 + (d / math.max(arc, 1e-4)) * (math.pi * 0.5)
			return (w - r) + math.cos(ang) * r, (h - r) + math.sin(ang) * r, math.deg(ang) + 90
		end
		d -= arc
		-- 5) bottom straight (right → left)
		if d <= sh then
			return (w - r) - d, h - 1, 0
		end
		d -= sh
		-- 6) bottom-left corner
		if d <= arc then
			local ang = math.pi * 0.5 + (d / math.max(arc, 1e-4)) * (math.pi * 0.5)
			return r + math.cos(ang) * r, (h - r) + math.sin(ang) * r, math.deg(ang) + 90
		end
		d -= arc
		-- 7) left straight (bottom → top)
		if d <= sv then
			return 1, (h - r) - d, 90
		end
		d -= sv
		-- 8) top-left corner
		local ang = math.pi + (d / math.max(arc, 1e-4)) * (math.pi * 0.5)
		return r + math.cos(ang) * r, r + math.sin(ang) * r, math.deg(ang) + 90
	end

	task.spawn(function()
		local t0 = os.clock()
		while host.Parent and parent.Parent do
			local w = parent.AbsoluteSize.X
			local h = parent.AbsoluteSize.Y
			if w > 8 and h > 8 then
				local u = ((os.clock() - t0) % period) / period
				local x, y, rot = pointOnRoundedRect(u, w, h, radius)
				light.Position = UDim2.fromOffset(x, y)
				light.Rotation = rot
				light.Size = UDim2.fromOffset(36, 2)
			end
			RunService.RenderStepped:Wait()
		end
	end)

	return host
end

local function cardLit()
	return make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.45, Color3.fromRGB(245, 245, 248)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 218)),
		}),
	})
end

local function topHighlight(parent)
	local line = make("Frame", {
		Size = UDim2.new(1, -2, 0, 1),
		Position = UDim2.fromOffset(1, 0),
		BackgroundColor3 = Theme.Highlight,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 3,
	})
	line.Parent = parent
	return line
end

-- ============ VISUAL FX ============
local fxLayer = nil
local activeDustThreads = {}

local function softPulse(obj, prop, minVal, maxVal, duration)
	duration = duration or 1.2
	minVal = minVal or 0
	maxVal = maxVal or 0.45
	local pulseInfo = TweenInfo.new(duration * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	task.spawn(function()
		while obj and obj.Parent do
			tween(obj, pulseInfo, { [prop] = maxVal })
			task.wait(duration * 0.5)
			if not obj.Parent then break end
			tween(obj, pulseInfo, { [prop] = minVal })
			task.wait(duration * 0.5)
		end
	end)
end

local function sparkBurst(parent, x, y, color, count)
	if Flags.DisableParticles or Flags.NoAnimations then return end
	count = count or 10
	color = color or Theme.Accent
	for i = 1, count do
		local size = math.random(3, 6)
		local spark = make("Frame", {
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(x, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 60,
		}, { corner(2) })
		spark.Parent = parent

		local angle = (i / count) * math.pi * 2 + (math.random() - 0.5) * 0.6
		local dist = math.random(18, 52)
		local tx = x + math.cos(angle) * dist
		local ty = y + math.sin(angle) * dist

		tween(spark, TweenInfo.new(0.32 + math.random() * 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(tx, ty),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(1, 1),
			Rotation = math.random(-90, 90),
		})
		task.delay(0.55, function()
			if spark.Parent then spark:Destroy() end
		end)
	end
end

local function clickRipple(btn, localX, localY, color)
	color = color or Theme.Highlight
	local ripple = make("Frame", {
		Size = UDim2.fromOffset(4, 4),
		Position = UDim2.fromOffset(localX, localY),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		ZIndex = 20,
	}, { corner(999) })
	ripple.Parent = btn

	local maxSize = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.6
	tween(ripple, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(maxSize, maxSize),
		BackgroundTransparency = 1,
	})
	task.delay(0.45, function()
		if ripple.Parent then ripple:Destroy() end
	end)
end

local function celebrateOpen(win)
	if not win or not win.Parent then return end
	local w, h = win.AbsoluteSize.X, win.AbsoluteSize.Y
	local bursts = {
		{ w * 0.5, h * 0.08, 14 },
		{ w * 0.12, h * 0.35, 10 },
		{ w * 0.88, h * 0.35, 10 },
		{ w * 0.5, h * 0.55, 16 },
		{ w * 0.25, h * 0.75, 8 },
		{ w * 0.75, h * 0.75, 8 },
	}
	for i, b in ipairs(bursts) do
		task.delay(i * 0.06, function()
			if win.Parent then
				sparkBurst(win, b[1], b[2], Theme.Accent, b[3])
			end
		end)
	end
end

local function floatingDust(parent, count)
	if Flags.DisableDust or Flags.DisableParticles then return end
	count = count or 14
	for i = 1, count do
		local dot = make("Frame", {
			Size = UDim2.fromOffset(math.random(1, 2), math.random(1, 2)),
			Position = UDim2.new(math.random(), 0, math.random(), 0),
			BackgroundColor3 = Theme.Highlight,
			BackgroundTransparency = math.random(88, 96) / 100,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, { corner(1) })
		dot.Parent = parent

		task.spawn(function()
			while dot.Parent do
				local startPos = dot.Position
				local driftX = (math.random() - 0.5) * 0.08
				local driftY = -math.random(3, 8) / 1000
				local dur = math.random(18, 32)
				tween(dot, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
					Position = UDim2.new(
						startPos.X.Scale + driftX, startPos.X.Offset,
						startPos.Y.Scale + driftY - 0.15, startPos.Y.Offset
					),
					BackgroundTransparency = 1,
				})
				task.wait(dur)
				if not dot.Parent then break end
				dot.Position = UDim2.new(math.random(), 0, 1 + math.random() * 0.05, 0)
				dot.BackgroundTransparency = math.random(88, 96) / 100
			end
		end)
	end
end

local function createGridOverlay(parent, cellSize, lineTransparency)
	if Flags.DisableGrid then return nil end
	cellSize = cellSize or 24
	lineTransparency = lineTransparency or 0.94
	local grid = make("Frame", {
		Name = "GridOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,
	}, { corner(10) })
	grid.Parent = parent

	local cols = math.ceil(700 / cellSize)
	local rows = math.ceil(500 / cellSize)

	for c = 0, cols do
		local vLine = make("Frame", {
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.fromOffset(c * cellSize, 0),
			BackgroundColor3 = Theme.Highlight,
			BackgroundTransparency = lineTransparency,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
		vLine.Parent = grid
	end
	for r = 0, rows do
		local hLine = make("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromOffset(0, r * cellSize),
			BackgroundColor3 = Theme.Highlight,
			BackgroundTransparency = lineTransparency,
			BorderSizePixel = 0,
			ZIndex = 1,
		})
		hLine.Parent = grid
	end

	return grid
end

local function setGuiStaggerState(obj, offsetY, fadeAmount)
	if obj:IsA("CanvasGroup") then
		obj.GroupTransparency = fadeAmount
	elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
		obj.TextTransparency = fadeAmount
	end
	local pos = obj.Position
	obj.Position = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset + offsetY)
end

local function tweenGuiStaggerIn(obj, origPos, delaySec)
	task.delay(delaySec, function()
		if not obj.Parent then return end
		tween(obj, Anim.Smooth, { Position = origPos })
		if obj:IsA("CanvasGroup") then
			tween(obj, Anim.Smooth, { GroupTransparency = 0 })
		elseif obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			tween(obj, Anim.Smooth, { TextTransparency = 0 })
		end
	end)
end

local function staggerAnimatePage(page)
	local scroll = page:FindFirstChildOfClass("ScrollingFrame")
	if not scroll then return end
	local items = {}
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			table.insert(items, child)
		end
	end
	table.sort(items, function(a, b)
		return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
	end)
	for i, child in ipairs(items) do
		local origPos = child.Position
		setGuiStaggerState(child, 10, 0.55)
		tweenGuiStaggerIn(child, origPos, i * 0.035)
	end
end

-- ============ ROOT ============
local screenGui = make("ScreenGui", {
	Name = "FluentGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function killOld(container)
	if not container then return end
	local old = container:FindFirstChild("FluentGui")
	if old then old:Destroy() end
end

do
	local ok = pcall(function()
		local hiddenUi = (typeof(gethui) == "function") and gethui() or game:GetService("CoreGui")
		killOld(hiddenUi)
		screenGui.Parent = hiddenUi
	end)
	if not ok or not screenGui.Parent then
		local pg = player:WaitForChild("PlayerGui")
		killOld(pg)
		screenGui.Parent = pg
	end
end

print("[ZENLESS] loaded")

local WIN_W, WIN_H, MINI_H = 610, 430, 48
local AVATAR_URL = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
local DISPLAY_NAME = player.DisplayName
local USER_NAME = player.Name

local root = make("Frame", {
	Name = "Root",
	Size = UDim2.fromOffset(WIN_W, WIN_H),
	-- Always top-left anchor so drag math stays simple
	Position = UDim2.fromOffset(80, 80),
	AnchorPoint = Vector2.new(0, 0),
	BackgroundTransparency = 1,
	Visible = false,
})
root.Parent = screenGui

-- Center once we know the viewport
pcall(function()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	root.Position = UDim2.fromOffset(
		math.floor((vp.X - WIN_W) * 0.5),
		math.floor((vp.Y - WIN_H) * 0.5) + 20
	)
end)

-- UIScale MUST NOT live on root — it breaks drag position math.
local scaleHost = make("Frame", {
	Name = "ScaleHost",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
})
scaleHost.Parent = root

local windowScale = make("UIScale", { Scale = 0.92 })
windowScale.Parent = scaleHost

-- Crisp border only — no soft filled glow / halo layers outside the window
local windowStroke = stroke(Color3.fromRGB(200, 200, 210), 1, 0.15)
local windowAccentStroke = stroke(Theme.Accent, 1, 0.55)
registerAccent(windowAccentStroke, "Color")

local window = make("CanvasGroup", {
	Name = "Window",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Theme.Background,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	Visible = false,
	ZIndex = 2,
}, { corner(10), windowStroke, windowAccentStroke })
window.Parent = scaleHost

-- Rich multi-stop sheen (child frame — safe; gradient parallaxed separately)
local bgSheenGradient = make("UIGradient", {
	Rotation = 135,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 52, 58)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(30, 30, 34)),
		ColorSequenceKeypoint.new(0.55, Theme.Background),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 12)),
	}),
})

local bgSheen = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 0,
}, { corner(10), bgSheenGradient })
bgSheen.Parent = window

createGridOverlay(window, 28, 0.945)

fxLayer = make("Frame", {
	Name = "FXLayer",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 55,
	ClipsDescendants = true,
}, { corner(10) })
fxLayer.Parent = window

local dustHolder = make("Frame", {
	Name = "DustLayer",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 0,
}, { corner(10) })
dustHolder.Parent = window
floatingDust(dustHolder, 12)

-- Subtle mouse parallax on bg sheen gradient only (not a wash overlay)
RunService.RenderStepped:Connect(function()
	if not window.Parent or window.GroupTransparency > 0.95 then return end
	local mouse = UserInputService:GetMouseLocation()
	local winPos = window.AbsolutePosition
	local winSize = window.AbsoluteSize
	if winSize.X <= 0 or winSize.Y <= 0 then return end
	local relX = (mouse.X - winPos.X) / winSize.X - 0.5
	local relY = (mouse.Y - winPos.Y) / winSize.Y - 0.5
	bgSheenGradient.Rotation = 135 + relX * 6 + relY * 3
end)

-- Inner rim highlight (white hairline inset)
local innerRim = make("Frame", {
	Size = UDim2.new(1, -4, 1, -4),
	Position = UDim2.fromOffset(2, 2),
	BackgroundTransparency = 1,
	ZIndex = 1,
}, {
	corner(9),
	stroke(Color3.new(1, 1, 1), 1, 0.92),
})
innerRim.Parent = window

-- Accent top bar + traveling white shine
local topAccent = make("Frame", {
	Size = UDim2.new(1, -24, 0, 2),
	Position = UDim2.fromOffset(12, 0),
	BackgroundColor3 = Theme.Accent,
	BorderSizePixel = 0,
	ZIndex = 6,
	ClipsDescendants = true,
}, { corner(1) })
topAccent.Parent = window
registerAccent(topAccent, "BackgroundColor3")

make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 0.9),
	}),
}).Parent = topAccent

local topShine = make("Frame", {
	Size = UDim2.new(0.22, 0, 1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 7,
})
topShine.Parent = topAccent
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	}),
}).Parent = topShine

task.spawn(function()
	while topShine.Parent do
		topShine.Position = UDim2.new(-0.25, 0, 0, 0)
		tween(topShine, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = UDim2.new(1.05, 0, 0, 0),
		})
		task.wait(3.4)
	end
end)

-- Rounded metallic sheen — parented to window so hide/fade also hides the rim
local windowRim = attachPerimeterLight(window, {
	CornerRadius = 10,
	Thickness = 1.5,
	Period = 2.8,
	ZIndex = 45,
})

-- ============ LOADER (10s download) ============
local playLoader
local loaderHost -- outer so skip/destroy can clear the ghost rim
(function()
local LOADER_SECONDS = 10
local loaderFinished = false

loaderHost = make("Frame", {
	Name = "LoaderHost",
	Size = UDim2.fromOffset(420, 360),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false, -- never show empty host / rim until playLoader
	ZIndex = 20,
})
loaderHost.Parent = screenGui

local loaderCard = make("CanvasGroup", {
	Name = "Loader",
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(18, 18, 20),
	BorderSizePixel = 0,
	GroupTransparency = 1,
	ZIndex = 21,
	ClipsDescendants = true,
}, {
	corner(16),
	stroke(Color3.fromRGB(120, 120, 130), 1, 0.25),
})
loaderCard.Parent = loaderHost

-- Layered backdrop (no UIGradient on CanvasGroup)
local loaderBg = make("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(22, 22, 26),
	BorderSizePixel = 0,
	ZIndex = 21,
}, { corner(16) })
loaderBg.Parent = loaderCard

local loaderBgTop = make("Frame", {
	Size = UDim2.new(1, 0, 0, 120),
	BackgroundColor3 = Color3.fromRGB(34, 34, 40),
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
	ZIndex = 21,
}, {
	corner(16),
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}),
})
loaderBgTop.Parent = loaderCard

-- Soft spotlight behind avatar
local loaderSpot = make("Frame", {
	Size = UDim2.fromOffset(160, 160),
	Position = UDim2.new(0.5, 0, 0, 70),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.92,
	BorderSizePixel = 0,
	ZIndex = 21,
}, { corner(80) })
loaderSpot.Parent = loaderCard

-- Rim must live on the card (destroyed with host). Never leave a bare rim on-screen.
attachPerimeterLight(loaderCard, {
	CornerRadius = 16,
	Thickness = 1.5,
	Period = 2.4,
	ZIndex = 35,
})

-- Header
local loaderHeader = make("Frame", {
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundTransparency = 1,
	ZIndex = 22,
})
loaderHeader.Parent = loaderCard

make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0.6, 0, 1, 0),
	Position = UDim2.fromOffset(20, 0),
	Font = Enum.Font.GothamBold,
	Text = "ZENLESS",
	TextSize = 18,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 23,
}).Parent = loaderHeader

local loaderBadge = make("Frame", {
	Size = UDim2.fromOffset(78, 20),
	Position = UDim2.fromOffset(118, 14),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.9,
	ZIndex = 23,
}, { corner(5), stroke(Color3.fromRGB(200, 200, 210), 1, 0.45) })
loaderBadge.Parent = loaderHeader

make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, 0, 1, 0),
	Font = Enum.Font.GothamBold,
	Text = "LOADING",
	TextSize = 9,
	TextColor3 = Color3.fromRGB(230, 230, 235),
	ZIndex = 24,
}).Parent = loaderBadge

local loaderClose = make("TextButton", {
	Name = "LoaderClose",
	Size = UDim2.fromOffset(30, 26),
	Position = UDim2.new(1, -42, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundColor3 = Theme.Error,
	BackgroundTransparency = 0.05,
	Text = "X",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = Color3.new(1, 1, 1),
	AutoButtonColor = false,
	ZIndex = 30,
}, { corner(7) })
loaderClose.Parent = loaderHeader
loaderClose.MouseButton1Click:Connect(function()
	if screenGui and screenGui.Parent then screenGui:Destroy() end
end)
loaderClose.MouseEnter:Connect(function()
	tween(loaderClose, Anim.Fast, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(230, 60, 55) })
end)
loaderClose.MouseLeave:Connect(function()
	tween(loaderClose, Anim.Fast, { BackgroundTransparency = 0.05, BackgroundColor3 = Theme.Error })
end)

-- Chrome top strip under header
local loaderTop = make("Frame", {
	Size = UDim2.new(1, -40, 0, 2),
	Position = UDim2.fromOffset(20, 48),
	BackgroundColor3 = Color3.fromRGB(36, 36, 40),
	BorderSizePixel = 0,
	ZIndex = 23,
	ClipsDescendants = true,
}, { corner(1) })
loaderTop.Parent = loaderCard

make("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.new(0, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundColor3 = Color3.fromRGB(220, 220, 228),
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	ZIndex = 24,
}).Parent = loaderTop

local loaderTopShine = make("Frame", {
	Size = UDim2.new(0.3, 0, 1, 0),
	Position = UDim2.new(-0.3, 0, 0, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 25,
})
loaderTopShine.Parent = loaderTop
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	}),
}).Parent = loaderTopShine

task.spawn(function()
	while loaderTopShine.Parent do
		loaderTopShine.Position = UDim2.new(-0.3, 0, 0, 0)
		local tw = TweenService:Create(loaderTopShine, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = UDim2.new(1.05, 0, 0, 0),
		})
		tw:Play()
		tw.Completed:Wait()
		task.wait(0.4)
	end
end)

-- Avatar hero
local loaderRing = make("Frame", {
	Size = UDim2.fromOffset(92, 92),
	Position = UDim2.new(0.5, 0, 0, 72),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BackgroundTransparency = 0.88,
	ZIndex = 22,
}, { corner(46) })
loaderRing.Parent = loaderCard

local loaderAvatar = make("ImageLabel", {
	Size = UDim2.fromOffset(76, 76),
	Position = UDim2.new(0.5, 0, 0, 80),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundColor3 = Color3.fromRGB(40, 40, 46),
	Image = AVATAR_URL,
	ZIndex = 23,
}, { corner(38), stroke(Color3.fromRGB(245, 245, 250), 2, 0.05) })
loaderAvatar.Parent = loaderCard

local loaderOnline = make("Frame", {
	Size = UDim2.fromOffset(14, 14),
	Position = UDim2.new(0.5, 28, 0, 138),
	BackgroundColor3 = Theme.Success,
	ZIndex = 25,
	BorderSizePixel = 0,
}, { corner(7), stroke(Color3.fromRGB(18, 18, 20), 3, 0) })
loaderOnline.Parent = loaderCard
softPulse(loaderOnline, "BackgroundTransparency", 0, 0.4, 1.5)
softPulse(loaderRing, "BackgroundTransparency", 0.85, 0.94, 2)

make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -40, 0, 22),
	Position = UDim2.fromOffset(20, 168),
	Font = Enum.Font.GothamBold,
	Text = DISPLAY_NAME,
	TextSize = 18,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	ZIndex = 22,
}).Parent = loaderCard

make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -40, 0, 16),
	Position = UDim2.fromOffset(20, 190),
	Font = Enum.Font.Gotham,
	Text = "@" .. USER_NAME,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(175, 175, 185),
	ZIndex = 22,
}).Parent = loaderCard

-- Progress panel
local loaderPanel = make("Frame", {
	Size = UDim2.new(1, -40, 0, 102),
	Position = UDim2.fromOffset(20, 224),
	BackgroundColor3 = Color3.fromRGB(28, 28, 32),
	BorderSizePixel = 0,
	ZIndex = 22,
}, {
	corner(12),
	stroke(Color3.fromRGB(70, 70, 78), 1, 0.35),
})
loaderPanel.Parent = loaderCard

make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0.5, 0, 0, 14),
	Position = UDim2.fromOffset(14, 12),
	Font = Enum.Font.GothamBold,
	Text = "DOWNLOAD",
	TextSize = 10,
	TextColor3 = Color3.fromRGB(140, 140, 150),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 23,
}).Parent = loaderPanel

local loaderPct = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(56, 18),
	Position = UDim2.new(1, -68, 0, 10),
	Font = Enum.Font.GothamBold,
	Text = "0%",
	TextSize = 16,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 23,
})
loaderPct.Parent = loaderPanel

local loaderStatus = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -28, 0, 16),
	Position = UDim2.fromOffset(14, 34),
	Font = Enum.Font.GothamMedium,
	Text = "Preparing download…",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(245, 245, 248),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 23,
})
loaderStatus.Parent = loaderPanel

local loaderTrack = make("Frame", {
	Size = UDim2.new(1, -28, 0, 8),
	Position = UDim2.fromOffset(14, 58),
	BackgroundColor3 = Color3.fromRGB(14, 14, 16),
	BorderSizePixel = 0,
	ZIndex = 23,
}, { corner(4), stroke(Color3.fromRGB(90, 90, 98), 1, 0.5) })
loaderTrack.Parent = loaderPanel

local loaderFill = make("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = Color3.fromRGB(230, 230, 238),
	BorderSizePixel = 0,
	ZIndex = 24,
	ClipsDescendants = true,
}, {
	corner(4),
	make("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 180, 190)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210)),
		}),
	}),
})
loaderFill.Parent = loaderTrack

local loaderFillShine = make("Frame", {
	Size = UDim2.new(0.4, 0, 1, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 25,
})
loaderFillShine.Parent = loaderFill
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}).Parent = loaderFillShine

local loaderDetail = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0.55, 0, 0, 14),
	Position = UDim2.fromOffset(14, 74),
	Font = Enum.Font.GothamMedium,
	Text = "0 KB / 2450 KB",
	TextSize = 11,
	TextColor3 = Color3.fromRGB(160, 160, 170),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 23,
})
loaderDetail.Parent = loaderPanel

local loaderSub = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0.4, -10, 0, 14),
	Position = UDim2.new(0.6, 0, 0, 74),
	Font = Enum.Font.Gotham,
	Text = "assets & modules",
	TextSize = 11,
	TextColor3 = Color3.fromRGB(130, 130, 140),
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 23,
})
loaderSub.Parent = loaderPanel

-- Step dots
local loaderDots = make("Frame", {
	Size = UDim2.new(1, -40, 0, 8),
	Position = UDim2.fromOffset(20, 336),
	BackgroundTransparency = 1,
	ZIndex = 22,
})
loaderDots.Parent = loaderCard

make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}).Parent = loaderDots

local stageDots = {}
for i = 1, 8 do
	local dot = make("Frame", {
		Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(55, 55, 62),
		BorderSizePixel = 0,
		LayoutOrder = i,
		ZIndex = 23,
	}, { corner(4) })
	dot.Parent = loaderDots
	stageDots[i] = dot
end

local loaderStages = {
	{ t = 0.00, label = "Connecting to CDN…", kb = 0 },
	{ t = 0.12, label = "Fetching core modules…", kb = 180 },
	{ t = 0.28, label = "Downloading VisualFX pack…", kb = 620 },
	{ t = 0.45, label = "Loading theme assets…", kb = 1100 },
	{ t = 0.62, label = "Caching component library…", kb = 1580 },
	{ t = 0.78, label = "Linking tab controllers…", kb = 1980 },
	{ t = 0.90, label = "Finalizing interface…", kb = 2280 },
	{ t = 1.00, label = "Download complete", kb = 2450 },
}

local function setLoaderStage(index)
	for i, dot in ipairs(stageDots) do
		local on = i <= index
		tween(dot, Anim.Fast, {
			BackgroundColor3 = on and Color3.fromRGB(235, 235, 242) or Color3.fromRGB(55, 55, 62),
			Size = on and (i == index and UDim2.fromOffset(18, 8) or UDim2.fromOffset(8, 8)) or UDim2.fromOffset(8, 8),
		})
	end
end

playLoader = function()
	root.Visible = false
	if not loaderHost or not loaderHost.Parent then return end
	loaderHost.Visible = true
	loaderCard.GroupTransparency = 1
	local loaderScale = make("UIScale", { Scale = 0.88 })
	loaderScale.Parent = loaderHost
	tween(loaderCard, Anim.Smooth, { GroupTransparency = 0 })
	tween(loaderScale, Anim.Spring, { Scale = 1 })

	-- Avatar entrance
	loaderAvatar.Size = UDim2.fromOffset(60, 60)
	loaderAvatar.Position = UDim2.new(0.5, 0, 0, 88)
	tween(loaderAvatar, Anim.Spring, {
		Size = UDim2.fromOffset(76, 76),
		Position = UDim2.new(0.5, 0, 0, 80),
	})

	task.spawn(function()
		while loaderFillShine.Parent and not loaderFinished do
			loaderFillShine.Position = UDim2.new(-0.45, 0, 0, 0)
			local tw = TweenService:Create(loaderFillShine, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(1.1, 0, 0, 0),
			})
			tw:Play()
			tw.Completed:Wait()
			task.wait(0.2)
		end
	end)

	local start = os.clock()
	local totalKb = 2450
	local lastStage = 0
	while true do
		local elapsed = os.clock() - start
		local alpha = math.clamp(elapsed / LOADER_SECONDS, 0, 1)
		local eased = 1 - (1 - alpha) ^ 2

		loaderFill.Size = UDim2.new(eased, 0, 1, 0)
		loaderPct.Text = math.floor(eased * 100 + 0.5) .. "%"

		local stageIndex = 1
		local stage = loaderStages[1]
		for i, s in ipairs(loaderStages) do
			if eased >= s.t then
				stage = s
				stageIndex = i
			end
		end
		if stageIndex ~= lastStage then
			lastStage = stageIndex
			setLoaderStage(stageIndex)
		end
		loaderStatus.Text = stage.label
		loaderDetail.Text = string.format("%d KB / %d KB", math.floor(totalKb * eased), totalKb)

		if alpha >= 1 then break end
		task.wait(0.03)
	end

	loaderFinished = true
	setLoaderStage(8)
	loaderStatus.Text = "Launching ZENLESS…"
	loaderPct.Text = "100%"
	loaderDetail.Text = "2450 KB / 2450 KB"
	loaderSub.Text = "ready"
	loaderBadge:FindFirstChildOfClass("TextLabel").Text = "READY"
	task.wait(0.45)

	tween(loaderCard, Anim.Smooth, { GroupTransparency = 1 })
	tween(loaderScale, Anim.Smooth, { Scale = 0.94 })
	task.wait(0.28)
	if loaderHost.Parent then loaderHost:Destroy() end
	root.Visible = true
end

end)()

-- ============ TITLE BAR ============
local titleBar = make("Frame", {
	Name = "TitleBar",
	Size = UDim2.new(1, 0, 0, MINI_H),
	BackgroundColor3 = Theme.Layer,
	BorderSizePixel = 0,
	ZIndex = 2,
}, {
	corner(10),
	cardLit(),
})
titleBar.Parent = window

make("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = Theme.Layer,
	BorderSizePixel = 0,
}).Parent = titleBar

local accentDot = make("Frame", {
	Size = UDim2.fromOffset(8, 8),
	Position = UDim2.fromOffset(18, 20),
	BackgroundColor3 = Theme.Accent,
	ZIndex = 3,
}, { corner(4) })
accentDot.Parent = titleBar
registerAccent(accentDot, "BackgroundColor3")

-- Soft glow behind accent dot
local dotGlow = make("Frame", {
	Size = UDim2.fromOffset(16, 16),
	Position = UDim2.fromOffset(14, 16),
	BackgroundColor3 = Theme.Accent,
	BackgroundTransparency = 0.75,
	ZIndex = 2,
}, { corner(8) })
dotGlow.Parent = titleBar
registerAccent(dotGlow, "BackgroundColor3")

local titleLabel = make("TextLabel", {
	Name = "Title",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -230, 1, 0),
	Position = UDim2.fromOffset(36, 0),
	Font = Enum.Font.GothamBold,
	Text = "ZENLESS",
	TextSize = 15,
	TextColor3 = Theme.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 3,
})
titleLabel.Parent = titleBar

make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(48, MINI_H),
	Position = UDim2.fromOffset(118, 0),
	Font = Enum.Font.Gotham,
	Text = "v6",
	TextSize = 12,
	TextColor3 = Theme.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 3,
}).Parent = titleBar

-- Right chrome spacing (from right edge): controls → gap → bell → gap → fps
-- winControls width 70 @ -12 → occupies [W-82, W-12]
-- bell 26 @ -96 → [W-122, W-96]
-- fps 72 @ -136 → [W-208, W-136]
local fpsPill = make("Frame", {
	Size = UDim2.fromOffset(72, 22),
	Position = UDim2.new(1, -136, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundColor3 = Theme.Element,
	ZIndex = 3,
}, { corner(6), stroke(Theme.Stroke, 1, 0.45) })
fpsPill.Parent = titleBar

local fpsDot = make("Frame", {
	Size = UDim2.fromOffset(6, 6),
	Position = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Theme.Success,
	ZIndex = 4,
}, { corner(3) })
fpsDot.Parent = fpsPill

local fpsLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -18, 1, 0),
	Position = UDim2.fromOffset(16, 0),
	Font = Enum.Font.GothamMedium,
	Text = "-- fps",
	TextSize = 11,
	TextColor3 = Theme.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
})
fpsLabel.Parent = fpsPill

task.spawn(function()
	local frames = 0
	local conn = RunService.RenderStepped:Connect(function()
		frames += 1
	end)
	while fpsLabel.Parent do
		task.wait(1)
		local f = frames
		frames = 0
		fpsLabel.Text = f .. " fps"
		local col = f >= 55 and Theme.Success or (f >= 30 and Theme.Warning or Theme.Error)
		tween(fpsDot, Anim.Fast, { BackgroundColor3 = col })
	end
	conn:Disconnect()
end)

-- Accent dot pulse
task.spawn(function()
	local pulse = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	while accentDot.Parent do
		tween(accentDot, pulse, { BackgroundTransparency = 0.45 })
		tween(dotGlow, pulse, { BackgroundTransparency = 0.88, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(12, 14) })
		task.wait(1.1)
		if not accentDot.Parent then break end
		tween(accentDot, pulse, { BackgroundTransparency = 0 })
		tween(dotGlow, pulse, { BackgroundTransparency = 0.72, Size = UDim2.fromOffset(16, 16), Position = UDim2.fromOffset(14, 16) })
		task.wait(1.1)
	end
end)

-- Chrome window controls (match silver panel — not blocky red squares)
local winControls = make("Frame", {
	Name = "WinControls",
	Size = UDim2.fromOffset(70, 28),
	Position = UDim2.new(1, -12, 0.5, 0),
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundColor3 = Color3.fromRGB(22, 22, 26),
	ZIndex = 12,
}, {
	corner(8),
	stroke(Theme.Stroke, 1, 0.35),
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 46)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 22)),
		}),
	}),
})
winControls.Parent = titleBar

local function chromeCtrl(iconName, x, isClose)
	local btn = make("TextButton", {
		Name = isClose and "CloseBtn" or "MinimizeBtn",
		Size = UDim2.fromOffset(30, 22),
		Position = UDim2.fromOffset(x, 3),
		BackgroundColor3 = Color3.fromRGB(32, 32, 38),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 13,
	}, { corner(6) })
	btn.Parent = winControls

	local idleColor = isClose and Color3.fromRGB(190, 140, 140) or Theme.SubText
	local hoverColor = isClose and Color3.fromRGB(255, 90, 85) or Theme.Text
	local state = {
		icon = drawIcon(btn, iconName, idleColor, 12),
		idle = idleColor,
		hover = hoverColor,
	}
	state.icon.SetColor(idleColor)

	btn.MouseEnter:Connect(function()
		tween(btn, Anim.Fast, {
			BackgroundTransparency = 0,
			BackgroundColor3 = isClose and Color3.fromRGB(72, 28, 28) or Theme.ElementHover,
		})
		state.icon.SetColor(state.hover)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, Anim.Fast, { BackgroundTransparency = 1 })
		state.icon.SetColor(state.idle)
	end)

	return btn, state
end

local minimizeBtn, minimizeState = chromeCtrl("minus", 4, false)
local closeBtn = chromeCtrl("close", 36, true)

local function setMinimizeIcon(name)
	if minimizeState.icon and minimizeState.icon.Destroy then
		minimizeState.icon.Destroy()
	end
	minimizeState.icon = drawIcon(minimizeBtn, name, minimizeState.idle, 12)
end

-- divider between min / close
make("Frame", {
	Size = UDim2.fromOffset(1, 14),
	Position = UDim2.fromOffset(34, 7),
	BackgroundColor3 = Theme.Stroke,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
	ZIndex = 14,
}).Parent = winControls

-- Divider under title with edge fade
local titleDiv = make("Frame", {
	Size = UDim2.new(1, -24, 0, 1),
	Position = UDim2.fromOffset(12, MINI_H - 1),
	BackgroundColor3 = Theme.Stroke,
	BorderSizePixel = 0,
	ZIndex = 4,
})
titleDiv.Parent = window
make("UIGradient", {
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.12, 0.35),
		NumberSequenceKeypoint.new(0.88, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	}),
}).Parent = titleDiv

-- ============ WINDOW SHELL (drag / snap / resize / dbl-click) ============
local targetPos = root.Position
local resizing = false
local resizeEdge = nil
local lastTitleClick = 0
local minimizeWindow -- forward
local setWindowPinned
local setSizePreset
local setFullscreen
local setSidebarCollapsed
local applyWindowOpacity

local function getViewport()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local function absRootPos()
	return root.AbsolutePosition, root.AbsoluteSize
end

local function setRootOffset(x, y)
	root.AnchorPoint = Vector2.new(0, 0)
	targetPos = UDim2.fromOffset(x, y)
	root.Position = targetPos
end

local function snapPosition(x, y, w, h)
	if not Flags.EdgeSnap then return x, y end
	local vp = getViewport()
	if x < SNAP_PX then x = 0 end
	if y < SNAP_PX then y = 0 end
	if x + w > vp.X - SNAP_PX then x = vp.X - w end
	if y + h > vp.Y - SNAP_PX then y = vp.Y - h end
	x = math.clamp(x, 0, math.max(0, vp.X - w))
	y = math.clamp(y, 0, math.max(0, vp.Y - h))
	return x, y
end

local function rememberWindowGeometry()
	-- Never persist minimized / broken sizes (this was collapsing the whole UI)
	local w = root.Size.X.Offset
	local h = root.Size.Y.Offset
	if w < 420 or h < 280 then return end
	State.savedWindowPos = root.Position
	State.savedWindowSize = UDim2.fromOffset(w, h)
	ConfigData.window = {
		pos = { root.Position.X.Scale, root.Position.X.Offset, root.Position.Y.Scale, root.Position.Y.Offset },
		size = { w, h },
		preset = State.currentPreset,
		anchor = { root.AnchorPoint.X, root.AnchorPoint.Y },
	}
	task.defer(saveConfigFile)
end

-- Drag handle covers title (leave right side for FPS / bell / chrome)
local dragHandle = make("TextButton", {
	Name = "DragHandle",
	Size = UDim2.new(1, -220, 1, 0),
	Position = UDim2.fromOffset(0, 0),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Active = true,
	Selectable = false,
	ZIndex = 50,
})
dragHandle.Parent = titleBar

do
	local dragging = false
	local dragMoved = false
	local startMouse = Vector2.new(0, 0)
	local startPos = Vector2.new(0, 0)

	local function clampRoot(x, y)
		local vp = getViewport()
		local w = root.Size.X.Offset
		local h = root.Size.Y.Offset
		x = math.clamp(x, 0, math.max(0, vp.X - w))
		y = math.clamp(y, 0, math.max(0, vp.Y - h))
		return x, y
	end

	local function stopDrag()
		if not dragging then return end
		dragging = false
		local x, y = clampRoot(root.Position.X.Offset, root.Position.Y.Offset)
		if Flags.EdgeSnap then
			x, y = snapPosition(x, y, root.Size.X.Offset, root.Size.Y.Offset)
		end
		root.Position = UDim2.fromOffset(x, y)
		targetPos = root.Position
		if dragMoved then
			rememberWindowGeometry()
		end
	end

	local function beginDrag(mx, my)
		if Flags.LockLayout or Flags.Fullscreen then return end
		-- Keep offset-only top-left; never remap via AbsolutePosition (breaks gethui)
		root.AnchorPoint = Vector2.new(0, 0)
		if root.Position.X.Scale ~= 0 or root.Position.Y.Scale ~= 0 then
			local vp = getViewport()
			local x = root.Position.X.Scale * vp.X + root.Position.X.Offset
			local y = root.Position.Y.Scale * vp.Y + root.Position.Y.Offset
			root.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		end
		startMouse = Vector2.new(mx, my)
		startPos = Vector2.new(root.Position.X.Offset, root.Position.Y.Offset)
		targetPos = root.Position
		dragging = true
		dragMoved = false
		State.lastInteraction = os.clock()
	end

	local function applyDragAt(mx, my)
		if not dragging then return end
		local dx = mx - startMouse.X
		local dy = my - startMouse.Y
		if math.abs(dx) + math.abs(dy) > 1 then
			dragMoved = true
		end
		local nx, ny = clampRoot(startPos.X + dx, startPos.Y + dy)
		root.Position = UDim2.fromOffset(nx, ny)
		targetPos = root.Position
	end

	local function tryBegin()
		if dragging then return end
		local now = os.clock()
		if now - lastTitleClick < 0.32 then
			stopDrag()
			if minimizeWindow then minimizeWindow() end
			lastTitleClick = 0
			return
		end
		lastTitleClick = now
		local m = UserInputService:GetMouseLocation()
		beginDrag(m.X, m.Y)
	end

	-- MouseButton1Down is the most reliable start signal in executors
	dragHandle.MouseButton1Down:Connect(tryBegin)
	dragHandle.MouseButton1Up:Connect(function()
		if dragging then stopDrag() end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if resizing and resizeEdge and input.UserInputType == Enum.UserInputType.MouseMovement then
			if Flags.LockLayout then return end
			local mouse = UserInputService:GetMouseLocation()
			local x, y = root.Position.X.Offset, root.Position.Y.Offset
			local w, h = root.Size.X.Offset, root.Size.Y.Offset
			local minW, minH = 420, 280
			if string.find(resizeEdge, "r") then w = math.max(minW, mouse.X - x) end
			if string.find(resizeEdge, "b") then h = math.max(minH, mouse.Y - y) end
			if string.find(resizeEdge, "l") then
				local nw = math.max(minW, (x + w) - mouse.X)
				x = (x + w) - nw
				w = nw
			end
			if string.find(resizeEdge, "t") then
				local nh = math.max(minH, (y + h) - mouse.Y)
				y = (y + h) - nh
				h = nh
			end
			x, y = snapPosition(x, y, w, h)
			root.Size = UDim2.fromOffset(w, h)
			root.Position = UDim2.fromOffset(x, y)
			targetPos = root.Position
			WIN_W, WIN_H = w, h
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then stopDrag() end
			if resizing then
				resizing = false
				resizeEdge = nil
				rememberWindowGeometry()
			end
		end
	end)

	-- Drive drag every frame (InputChanged is unreliable in many executors / gethui)
	RunService.RenderStepped:Connect(function()
		if not dragging then return end
		local m = UserInputService:GetMouseLocation()
		applyDragAt(m.X, m.Y)
	end)
end

targetPos = root.Position

-- Resize hit pads
do
	local edges = {
		{ "l", UDim2.new(0, 4, 1, -16), UDim2.fromOffset(0, 8), Enum.SizeConstraint.RelativeYY },
		{ "r", UDim2.new(0, 4, 1, -16), UDim2.new(1, -4, 0, 8), nil },
		{ "t", UDim2.new(1, -16, 0, 4), UDim2.fromOffset(8, 0), nil },
		{ "b", UDim2.new(1, -16, 0, 4), UDim2.new(0, 8, 1, -4), nil },
		{ "tl", UDim2.fromOffset(8, 8), UDim2.fromOffset(0, 0), nil },
		{ "tr", UDim2.fromOffset(8, 8), UDim2.new(1, -8, 0, 0), nil },
		{ "bl", UDim2.fromOffset(8, 8), UDim2.new(0, 0, 1, -8), nil },
		{ "br", UDim2.fromOffset(8, 8), UDim2.new(1, -8, 1, -8), nil },
	}
	for _, e in ipairs(edges) do
		local pad = make("TextButton", {
			Name = "Resize_" .. e[1],
			Size = e[2],
			Position = e[3],
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 80,
			AutoButtonColor = false,
		})
		pad.Parent = root
		pad.InputBegan:Connect(function(input)
			if Flags.LockLayout or Flags.Fullscreen then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = true
				resizeEdge = e[1]
				root.AnchorPoint = Vector2.new(0, 0)
				local ap = root.AbsolutePosition
				root.Position = UDim2.fromOffset(ap.X, ap.Y)
				targetPos = root.Position
			end
		end)
	end
end

-- Restore saved geometry (reject minimized/corrupt sizes)
pcall(function()
	local w = ConfigData.window
	if w and type(w.size) == "table" then
		local rw = tonumber(w.size[1])
		local rh = tonumber(w.size[2])
		if rw and rh and rw >= 420 and rh >= 280 then
			WIN_W, WIN_H = math.floor(rw), math.floor(rh)
			root.Size = UDim2.fromOffset(WIN_W, WIN_H)
		else
			-- wipe bad saved size (e.g. height == MINI_H from minimize)
			ConfigData.window.size = { WIN_W, WIN_H }
		end
	end
	if w and w.pos then
		root.AnchorPoint = Vector2.new(0, 0)
		local sx, ox = tonumber(w.pos[1]) or 0, tonumber(w.pos[2]) or 0
		local sy, oy = tonumber(w.pos[3]) or 0, tonumber(w.pos[4]) or 0
		-- Prefer offset-only positions (scale positions break grab-drag)
		if sx == 0 and sy == 0 then
			root.Position = UDim2.fromOffset(ox, oy)
		else
			local vp = getViewport()
			root.Position = UDim2.fromOffset(
				math.floor(vp.X * sx + ox - root.Size.X.Offset * 0.5),
				math.floor(vp.Y * sy + oy - root.Size.Y.Offset * 0.5)
			)
		end
		targetPos = root.Position
	end
	if w and w.preset then State.currentPreset = w.preset end
end)

-- ============ BODY ============
-- Fill remaining space under title bar (never bake a fixed BODY_H from a bad WIN_H)
local body = make("Frame", {
	Name = "Body",
	Size = UDim2.new(1, 0, 1, -MINI_H),
	Position = UDim2.fromOffset(0, MINI_H),
	BackgroundTransparency = 1,
	ZIndex = 2,
	ClipsDescendants = true,
})
body.Parent = window

local sidebar = make("Frame", {
	Name = "Sidebar",
	Size = UDim2.new(0, 168, 1, -12),
	Position = UDim2.fromOffset(8, 8),
	BackgroundColor3 = Theme.Sidebar,
	BorderSizePixel = 0,
}, { corner(8), stroke(Theme.Stroke, 1, 0.55), cardLit() })
sidebar.Parent = body

local tabHolder = make("Frame", {
	Size = UDim2.new(1, 0, 1, -68),
	BackgroundTransparency = 1,
})
tabHolder.Parent = sidebar

make("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}).Parent = tabHolder

make("UIPadding", {
	PaddingTop = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}).Parent = tabHolder

-- NAV label above tabs
local navLabel = make("TextLabel", {
	Size = UDim2.new(1, -8, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	Text = "NAVIGATION",
	TextSize = 9,
	TextColor3 = Color3.fromRGB(110, 110, 118),
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 0,
})
navLabel.Parent = tabHolder

local tabIndicator = make("Frame", {
	Size = UDim2.fromOffset(3, 22),
	BackgroundColor3 = Theme.Accent,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(6, 36),
	ZIndex = 4,
}, { corner(2) })
tabIndicator.Parent = sidebar
registerAccent(tabIndicator, "BackgroundColor3")

-- Upgraded profile card
local userCard = make("Frame", {
	Size = UDim2.new(1, -16, 0, 62),
	Position = UDim2.new(0, 8, 1, -70),
	BackgroundColor3 = Theme.Element,
	BorderSizePixel = 0,
}, { corner(10), stroke(Theme.Stroke, 1, 0.4), cardLit() })
userCard.Parent = sidebar
topHighlight(userCard)

local avatarGlow = make("Frame", {
	Size = UDim2.fromOffset(44, 44),
	Position = UDim2.new(0, 6, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundColor3 = Theme.Accent,
	BackgroundTransparency = 0.78,
	ZIndex = 1,
}, { corner(22) })
avatarGlow.Parent = userCard
registerAccent(avatarGlow, "BackgroundColor3")
softPulse(avatarGlow, "BackgroundTransparency", 0.72, 0.9, 1.6)

local avatarRing = stroke(Theme.Accent, 2, 0.15)
local avatar = make("ImageLabel", {
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.new(0, 10, 0.5, 0),
	AnchorPoint = Vector2.new(0, 0.5),
	BackgroundColor3 = Theme.Background,
	Image = AVATAR_URL,
	ZIndex = 2,
}, { corner(18), avatarRing })
avatar.Parent = userCard
registerAccent(avatarRing, "Color")

local onlineDot = make("Frame", {
	Size = UDim2.fromOffset(9, 9),
	Position = UDim2.fromOffset(36, 40),
	BackgroundColor3 = Theme.Success,
	ZIndex = 4,
	BorderSizePixel = 0,
}, { corner(5), stroke(Theme.Element, 2, 0) })
onlineDot.Parent = userCard
softPulse(onlineDot, "BackgroundTransparency", 0, 0.45, 1.4)

local displayNameLabel = make("TextLabel", {
	Name = "DisplayName",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -58, 0, 15),
	Position = UDim2.fromOffset(52, 10),
	Font = Enum.Font.GothamBold,
	Text = DISPLAY_NAME,
	TextSize = 12,
	TextColor3 = Theme.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 2,
})
displayNameLabel.Parent = userCard

local userNameLabel = make("TextLabel", {
	Name = "UserName",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -58, 0, 13),
	Position = UDim2.fromOffset(52, 26),
	Font = Enum.Font.Gotham,
	Text = "@" .. USER_NAME,
	TextSize = 10,
	TextColor3 = Theme.Accent,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 2,
})
userNameLabel.Parent = userCard
registerAccent(userNameLabel, "TextColor3")

local hintLabel = make("TextLabel", {
	Name = "HideHint",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -58, 0, 12),
	Position = UDim2.fromOffset(52, 42),
	Font = Enum.Font.Gotham,
	Text = "RightShift — hide",
	TextSize = 9,
	TextColor3 = Theme.SubText,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 2,
})
hintLabel.Parent = userCard

-- Clip profile text cleanly when sidebar collapses
userCard.ClipsDescendants = true

-- Give tab list room for taller profile card
tabHolder.Size = UDim2.new(1, 0, 1, -78)

-- Content lives on its own raised surface panel
local contentPanel = make("Frame", {
	Name = "ContentPanel",
	Size = UDim2.new(1, -168, 1, -12),
	Position = UDim2.fromOffset(168, 8),
	BackgroundColor3 = Theme.Layer,
	BorderSizePixel = 0,
}, { corner(8), stroke(Theme.Stroke, 1, 0.5), cardLit() })
contentPanel.Parent = body
topHighlight(contentPanel)

local contentArea = make("Frame", {
	Name = "Content",
	Size = UDim2.new(1, -8, 1, -28),
	Position = UDim2.fromOffset(4, 4),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
})
contentArea.Parent = contentPanel

-- Status bar: live clock + player name
local contentFooter = make("Frame", {
	Size = UDim2.new(1, -16, 0, 20),
	Position = UDim2.new(0, 8, 1, -24),
	BackgroundColor3 = Theme.Element,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
	ZIndex = 3,
}, { corner(5), stroke(Theme.Stroke, 1, 0.55) })
contentFooter.Parent = contentPanel

local statusDot = make("Frame", {
	Size = UDim2.fromOffset(5, 5),
	Position = UDim2.fromOffset(8, 7),
	BackgroundColor3 = Theme.Success,
	ZIndex = 4,
}, { corner(3) })
statusDot.Parent = contentFooter
softPulse(statusDot, "BackgroundTransparency", 0, 0.5, 1.4)

local statusPlayerLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0.55, -12, 1, 0),
	Position = UDim2.fromOffset(18, 0),
	Font = Enum.Font.GothamMedium,
	Text = DISPLAY_NAME .. "  ·  @" .. USER_NAME,
	TextSize = 10,
	TextColor3 = Theme.Text,
	TextTransparency = 0.15,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 4,
})
statusPlayerLabel.Parent = contentFooter

local statusClockLabel = make("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.new(0.45, -10, 1, 0),
	Position = UDim2.new(0.55, 0, 0, 0),
	Font = Enum.Font.Gotham,
	Text = "--:--:--",
	TextSize = 10,
	TextColor3 = Theme.SubText,
	TextTransparency = 0.1,
	TextXAlignment = Enum.TextXAlignment.Right,
	ZIndex = 4,
})
statusClockLabel.Parent = contentFooter

task.spawn(function()
	while statusClockLabel.Parent do
		statusClockLabel.Text = os.date("%H:%M:%S")
		task.wait(1)
	end
end)

-- L-brackets on body (hidden when minimized via clip)
do
	local marks = {
		{ UDim2.fromOffset(4, 4), UDim2.fromOffset(16, 2) },
		{ UDim2.fromOffset(4, 4), UDim2.fromOffset(2, 16) },
		{ UDim2.new(1, -20, 1, -6), UDim2.fromOffset(16, 2) },
		{ UDim2.new(1, -6, 1, -20), UDim2.fromOffset(2, 16) },
	}
	for _, m in ipairs(marks) do
		local f = make("Frame", {
			Size = m[2],
			Position = m[1],
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 5,
		})
		f.Parent = body
		registerAccent(f, "BackgroundColor3")
	end
end

-- ============ NOTIFICATION SYSTEM (ZENLESS v4) ============
local notify, dismissNotif, activeNotifs
(function()
local NOTIF_W = 320
local MAX_NOTIFS = 5
local notifCounter = 0

local notifArea = make("Frame", {
	Name = "NotifArea",
	Size = UDim2.fromOffset(NOTIF_W, 520),
	Position = UDim2.new(1, -14, 1, -14),
	AnchorPoint = Vector2.new(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 90,
	ClipsDescendants = false,
})
notifArea.Parent = screenGui

make("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}).Parent = notifArea

local notifTypes = {
	info = { icon = "chat", label = "INFO", color = function() return Theme.Accent end },
	success = { icon = "plus", label = "OK", color = function() return Theme.Success end },
	warning = { icon = "bolt", label = "WARN", color = function() return Theme.Warning end },
	error = { icon = "close", label = "ERR", color = function() return Theme.Error end },
}

activeNotifs = {}

local function countNotifWraps()
	local list = {}
	for _, c in ipairs(notifArea:GetChildren()) do
		if c:IsA("Frame") and c.Name == "NotifWrap" and not c:GetAttribute("Dismissing") then
			table.insert(list, c)
		end
	end
	table.sort(list, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	return list
end

local function estimateBodyHeight(text, maxWidth)
	if not text or text == "" then return 0 end
	local charsPerLine = math.max(18, math.floor(maxWidth / 6.6))
	local lines = math.ceil(#text / charsPerLine)
	for _ in string.gmatch(text, "\n") do
		lines += 1
	end
	return math.clamp(lines, 1, 3) * 15
end

dismissNotif = function(entry)
	if type(entry) ~= "table" then return end
	local wrapper, toast = entry.wrapper, entry.toast
	if not wrapper or not wrapper.Parent or wrapper:GetAttribute("Dismissing") then return end
	wrapper:SetAttribute("Dismissing", true)
	entry.alive = false
	if entry.scale then
		pcall(function() tween(entry.scale, Anim.Fast, { Scale = 0.94 }) end)
	end
	if toast and toast:IsA("CanvasGroup") then
		tween(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
			GroupTransparency = 1,
			Position = UDim2.fromOffset(36, 0),
		})
	end
	tween(wrapper, TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(NOTIF_W, 0),
	})
	task.delay(0.28, function()
		if wrapper and wrapper.Parent then wrapper:Destroy() end
		for i = #activeNotifs, 1, -1 do
			if activeNotifs[i] == entry then
				table.remove(activeNotifs, i)
				break
			end
		end
	end)
end

notify = function(title, body, kind, duration, opts)
	opts = opts or {}
	kind = tostring(kind or "info"):lower()
	if not notifTypes[kind] then kind = "info" end
	duration = math.clamp(tonumber(duration) or 3.2, 1.0, 30)
	title = tostring(title or "Notice")
	body = tostring(body or "")
	local info = notifTypes[kind]
	local color = info.color()
	notifCounter += 1

	local wraps = countNotifWraps()
	while #wraps >= MAX_NOTIFS do
		local oldest = table.remove(wraps, 1)
		for _, e in ipairs(activeNotifs) do
			if e.wrapper == oldest then
				dismissNotif(e)
				break
			end
		end
	end

	local hasBody = body ~= ""
	local bodyH = hasBody and estimateBodyHeight(body, NOTIF_W - 78) or 0
	local toastH = math.max(56, 52 + bodyH + (hasBody and 4 or 0))

	local wrapper = make("Frame", {
		Name = "NotifWrap",
		Size = UDim2.fromOffset(NOTIF_W, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = notifCounter,
		ZIndex = 90,
	})
	wrapper.Parent = notifArea

	local toastStroke = stroke(Theme.Stroke, 1, 0.3)
	local toast = make("CanvasGroup", {
		Name = "Toast",
		Size = UDim2.new(1, 0, 0, toastH),
		Position = UDim2.fromOffset(28, 0),
		BackgroundColor3 = Color3.fromRGB(18, 18, 20),
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 91,
	}, { corner(10), toastStroke })
	toast.Parent = wrapper

	local uiScale = make("UIScale", { Scale = 0.96 })
	uiScale.Parent = toast

	-- Surface
	make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 1,
	}, {
		corner(10),
		make("UIGradient", {
			Rotation = 115,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 46)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(22, 22, 26)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 14, 16)),
			}),
		}),
	}).Parent = toast

	-- Status rail
	make("Frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.fromOffset(0, 6),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, { corner(2) }).Parent = toast

	-- Icon
	local iconBubble = make("Frame", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.fromRGB(28, 28, 32),
		ZIndex = 5,
	}, { corner(8), stroke(color, 1, 0.4) })
	iconBubble.Parent = toast
	pcall(function()
		drawIcon(iconBubble, info.icon, color, 14)
	end)

	-- Type
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(48, 12),
		Position = UDim2.new(1, -56, 0, 10),
		Font = Enum.Font.GothamBold,
		Text = info.label,
		TextSize = 9,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	}).Parent = toast

	-- Title
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -100, 0, 16),
		Position = UDim2.fromOffset(52, 12),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 5,
	}).Parent = toast

	-- Body
	if hasBody then
		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -64, 0, bodyH),
			Position = UDim2.fromOffset(52, 30),
			Font = Enum.Font.Gotham,
			Text = body,
			TextSize = 11,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			ZIndex = 5,
		}).Parent = toast
	else
		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -100, 0, 14),
			Position = UDim2.fromOffset(52, 28),
			Font = Enum.Font.Gotham,
			Text = "ZENLESS",
			TextSize = 10,
			TextColor3 = Theme.AccentSoft,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		}).Parent = toast
	end

	-- Close
	local closeBtn = make("TextButton", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(1, -26, 0, 28),
		BackgroundColor3 = Color3.fromRGB(34, 34, 40),
		BackgroundTransparency = 0.3,
		Text = "x",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		ZIndex = 12,
	}, { corner(5) })
	closeBtn.Parent = toast

	-- Timer
	local barTrack = make("Frame", {
		Size = UDim2.new(1, -2, 0, 2),
		Position = UDim2.new(0, 1, 1, -2),
		BackgroundColor3 = Color3.fromRGB(20, 20, 24),
		BorderSizePixel = 0,
		ZIndex = 7,
		ClipsDescendants = true,
	})
	barTrack.Parent = toast
	local barFill = make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 8,
	})
	barFill.Parent = barTrack

	local entry = {
		wrapper = wrapper,
		toast = toast,
		scale = uiScale,
		alive = true,
		paused = false,
		remaining = duration,
		duration = duration,
		bar = barFill,
	}

	local barTween
	local timerGen = 0

	local function armTimer(fromScale, timeLeft)
		timerGen += 1
		local myGen = timerGen
		if barTween then pcall(function() barTween:Cancel() end) end
		barFill.Size = UDim2.new(fromScale, 0, 1, 0)
		barTween = tween(barFill, TweenInfo.new(timeLeft, Enum.EasingStyle.Linear), {
			Size = UDim2.new(0, 0, 1, 0),
		})
		task.delay(timeLeft, function()
			if myGen ~= timerGen or not entry.alive or entry.paused then return end
			dismissNotif(entry)
		end)
	end

	local function pauseTimer()
		if not entry.alive or entry.paused then return end
		entry.paused = true
		timerGen += 1
		entry.remaining = math.max(0.08, duration * math.clamp(barFill.Size.X.Scale, 0, 1))
		if barTween then pcall(function() barTween:Cancel() end) end
		tween(toastStroke, Anim.Fast, { Color = color, Transparency = 0.1 })
	end

	local function resumeTimer()
		if not entry.alive or not entry.paused then return end
		entry.paused = false
		tween(toastStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.3 })
		armTimer(math.clamp(entry.remaining / duration, 0, 1), entry.remaining)
	end

	entry.dismiss = function() dismissNotif(entry) end
	entry.pause = pauseTimer
	entry.resume = resumeTimer
	table.insert(activeNotifs, entry)

	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, Anim.Fast, { BackgroundTransparency = 0, BackgroundColor3 = Theme.Error, TextColor3 = Color3.new(1, 1, 1) })
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, Anim.Fast, { BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(34, 34, 40), TextColor3 = Theme.SubText })
	end)
	closeBtn.MouseButton1Click:Connect(function()
		dismissNotif(entry)
	end)

	local hoverPad = make("TextButton", {
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
		AutoButtonColor = false,
	})
	hoverPad.Parent = toast
	hoverPad.MouseEnter:Connect(pauseTimer)
	hoverPad.MouseLeave:Connect(resumeTimer)

	if opts.Action and opts.Action.Text and opts.Action.Callback then
		local act = make("TextButton", {
			Size = UDim2.fromOffset(70, 22),
			Position = UDim2.new(1, -84, 1, -30),
			BackgroundColor3 = Theme.Element,
			Text = opts.Action.Text,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Theme.Text,
			AutoButtonColor = false,
			ZIndex = 12,
		}, { corner(6), stroke(color, 1, 0.45) })
		act.Parent = toast
		toastH += 26
		toast.Size = UDim2.new(1, 0, 0, toastH)
		act.MouseButton1Click:Connect(function()
			task.spawn(opts.Action.Callback)
			dismissNotif(entry)
		end)
	end

	tween(wrapper, Anim.Spring, { Size = UDim2.fromOffset(NOTIF_W, toastH + 2) })
	tween(toast, Anim.Smooth, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	tween(uiScale, Anim.Spring, { Scale = 1 })
	armTimer(1, duration)
	return entry
end

end)()

-- ============ TABS ============
local tabs = {}
local activeTab = nil

local function switchTab(tab)
	if activeTab == tab then return end
	local prev = activeTab
	activeTab = tab

	for _, t in ipairs(tabs) do
		local on = (t == tab)
		tween(t.Button, Anim.Fast, {
			BackgroundTransparency = on and 0 or 1,
			BackgroundColor3 = on and Theme.ElementHover or Theme.Element,
		})
		if t.Label then
			tween(t.Label, Anim.Fast, { TextColor3 = on and Theme.Text or Theme.SubText })
		end
		if t.SubLabel then
			tween(t.SubLabel, Anim.Fast, {
				TextColor3 = on and Color3.fromRGB(140, 140, 148) or Color3.fromRGB(100, 100, 108),
			})
		end
		if t.IconBg then
			tween(t.IconBg, Anim.Fast, {
				BackgroundTransparency = on and 0.05 or 0.35,
				BackgroundColor3 = on and Color3.fromRGB(44, 44, 52) or Color3.fromRGB(28, 28, 32),
			})
		end
		if t.Icon then
			t.Icon.SetColor(on and Theme.Text or t.IconColor)
		elseif t.IconGlyph then
			tween(t.IconGlyph, Anim.Fast, {
				TextColor3 = on and Color3.new(1, 1, 1) or t.IconColor,
			})
		end
	end

	tween(tabIndicator, Anim.Smooth, {
		Position = UDim2.fromOffset(6, tab.Button.AbsolutePosition.Y - sidebar.AbsolutePosition.Y + 12),
		Size = UDim2.fromOffset(3, 22),
	})

	if prev then
		local old = prev.Page
		tween(old, Anim.Fast, { GroupTransparency = 1, Position = UDim2.fromOffset(0, 8) })
		task.delay(0.12, function()
			if activeTab ~= prev then old.Visible = false end
		end)
	end

	local page = tab.Page
	page.Visible = true
	page.Position = UDim2.fromOffset(0, 10)
	page.GroupTransparency = 1
	tween(page, Anim.Smooth, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) })
	task.delay(0.08, function()
		if activeTab == tab then staggerAnimatePage(page) end
	end)
end

local tabDefaults = {
	Home     = { color = Color3.fromRGB(198, 198, 208), icon = "home", sub = "Overview" },
	Player   = { color = Color3.fromRGB(170, 170, 180), icon = "user", sub = "Movement" },
	Visuals  = { color = Color3.fromRGB(210, 210, 220), icon = "eye", sub = "World" },
	World    = { color = Color3.fromRGB(198, 198, 208), icon = "world", sub = "Misc" },
	Combat   = { color = Color3.fromRGB(210, 90, 90), icon = "target", sub = "Aimbot" },
	ESP      = { color = Color3.fromRGB(120, 180, 220), icon = "eye", sub = "Visuals" },
	Extras   = { color = Color3.fromRGB(160, 160, 170), icon = "star", sub = "Tools" },
	Settings = { color = Color3.fromRGB(140, 140, 150), icon = "settings", sub = "Options" },
}

local bindTabAPI -- forward decl; filled after control factories

local function createTab(nameOrConfig)
	local cfg = (type(nameOrConfig) == "table") and nameOrConfig or { Title = tostring(nameOrConfig) }
	local name = cfg.Title or cfg.Name or "Tab"
	local preset = tabDefaults[name] or {}
	local iconColor = cfg.Color or preset.color or Theme.Accent
	local iconName = cfg.Icon or cfg.Image or preset.icon or "dot"
	local sub = cfg.Description or cfg.Desc or preset.sub or ""

	local btn = make("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = #tabs + 1,
		ClipsDescendants = false,
	}, { corner(8) })
	btn.Parent = tabHolder

	local iconBg = make("Frame", {
		Name = "IconBg",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Color3.fromRGB(28, 28, 32),
		BackgroundTransparency = 0.35,
		ZIndex = 2,
	}, {
		corner(8),
		stroke(Theme.Stroke, 1, 0.55),
		make("UIGradient", {
			Rotation = 135,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 48, 54)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 24)),
			}),
		}),
	})
	iconBg.Parent = btn

	-- Drawn icon (or rbxasset image via Icon / Image)
	local iconApi = drawIcon(iconBg, iconName, iconColor, 15)
	-- Keep a dummy label so older switchTab color tweens don't nil-index
	local iconGlyph = make("TextLabel", {
		Name = "IconGlyph",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		Text = "",
		Visible = false,
		ZIndex = 1,
	})
	iconGlyph.Parent = iconBg

	-- Leave ~56px on the right for badge; icon→text gap is intentional
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -96, 0, 16),
		Position = UDim2.fromOffset(48, 8),
		Font = Enum.Font.GothamMedium,
		Text = name,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
	})
	label.Parent = btn

	local subLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -96, 0, 14),
		Position = UDim2.fromOffset(48, 26),
		Font = Enum.Font.Gotham,
		Text = sub,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(100, 100, 108),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
	})
	subLabel.Parent = btn

	if Flags.SidebarCollapsed then
		label.Visible = false
		subLabel.Visible = false
		iconBg.AnchorPoint = Vector2.new(0.5, 0.5)
		iconBg.Position = UDim2.new(0.5, 0, 0.5, 0)
		iconBg.Size = UDim2.fromOffset(30, 30)
		btn.Size = UDim2.new(1, 0, 0, 42)
	end

	local page = make("CanvasGroup", {
		Name = name .. "Page",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Visible = false,
		GroupTransparency = 1,
	})
	page.Parent = contentArea

	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent,
		ScrollBarImageTransparency = 0.45,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	scroll.Parent = page
	registerAccent(scroll, "ScrollBarImageColor3")

	make("UIListLayout", {
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = scroll

	make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
	}).Parent = scroll

	local tab = {
		Title = name,
		Button = btn,
		Page = page,
		Container = scroll,
		Label = label,
		SubLabel = subLabel,
		IconBg = iconBg,
		IconGlyph = iconGlyph,
		Icon = iconApi,
		IconName = iconName,
		IconColor = iconColor,
	}
	table.insert(tabs, tab)

	btn.MouseEnter:Connect(function()
		if activeTab ~= tab then
			tween(btn, Anim.Fast, { BackgroundTransparency = 0.55 })
			tween(iconBg, Anim.Fast, { BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(40, 40, 46) })
			iconApi.SetColor(iconColor)
		end
	end)
	btn.MouseLeave:Connect(function()
		if activeTab ~= tab then
			tween(btn, Anim.Fast, { BackgroundTransparency = 1 })
			tween(iconBg, Anim.Fast, { BackgroundTransparency = 0.35, BackgroundColor3 = Color3.fromRGB(28, 28, 32) })
			iconApi.SetColor(iconColor)
		end
	end)
	btn.MouseButton1Click:Connect(function()
		switchTab(tab)
		sparkBurst(btn, 24, 23, iconColor, 5)
	end)

	if bindTabAPI then
		bindTabAPI(tab)
	end
	return tab
end

-- ============ CONTROLS ============
local order = 0
local function nextOrder()
	order += 1
	return order
end

local function styleCard(holder)
	local s = stroke(Theme.Stroke, 1, 0.4)
	s.Parent = holder
	cardLit().Parent = holder
	topHighlight(holder)
	local scale = holder:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = make("UIScale", { Scale = 1 })
		scale.Parent = holder
	end
	return s, scale
end

local function hoverCard(holder, cardStroke, cardScale)
	holder.MouseEnter:Connect(function()
		tween(holder, Anim.Fast, { BackgroundColor3 = Theme.ElementHover })
		if cardStroke then
			tween(cardStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0.45 })
		end
		if cardScale then
			tween(cardScale, Anim.Fast, { Scale = 1.012 })
		end
	end)
	holder.MouseLeave:Connect(function()
		tween(holder, Anim.Fast, { BackgroundColor3 = Theme.Element })
		if cardStroke then
			tween(cardStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.4 })
		end
		if cardScale then
			tween(cardScale, Anim.Fast, { Scale = 1 })
		end
	end)
end

local function createLabel(tab, text)
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	})
	row.Parent = tab.Container

	local tick = make("Frame", {
		Size = UDim2.fromOffset(3, 11),
		Position = UDim2.fromOffset(0, 8),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
	}, { corner(1) })
	tick.Parent = row
	registerAccent(tick, "BackgroundColor3")

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Font = Enum.Font.GothamBold,
		Text = text,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = row

	return row
end

local function createDivider(tab)
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	})
	make("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Theme.Stroke,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}).Parent = f
	f.Parent = tab.Container
	return f
end

local function createParagraph(tab, title, body)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)

	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}).Parent = holder

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		Text = body,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}).Parent = holder

	return holder
end

local function createButton(tab, text, callback, primary, opts)
	opts = opts or {}
	local primaryText = Color3.fromRGB(16, 16, 18)
	local loading = false
	local btn = make("TextButton", {
		Size = UDim2.new(1, 0, 0, Flags.LargeHitboxes and 44 or 38),
		BackgroundColor3 = primary and Theme.Accent or Theme.Element,
		Text = text,
		Font = State.uiFont,
		TextSize = 13,
		TextColor3 = primary and primaryText or Theme.Text,
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
		ClipsDescendants = true,
	}, { corner(8) })
	btn.Parent = tab.Container
	table.insert(State.focusables, btn)

	local s
	if primary then
		registerAccent(btn, "BackgroundColor3")
		s = stroke(Color3.new(1, 1, 1), 1, 0.55)
		s.Parent = btn
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 190)),
			}),
		}).Parent = btn
	else
		s = styleCard(btn)
	end

	local spin = make("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
	})
	spin.Parent = btn
	local spinArc = make("Frame", {
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = primary and primaryText or Theme.Accent,
		BackgroundTransparency = 0.3,
	}, { corner(7) })
	spinArc.Parent = spin

	local api = {}
	function api.SetLoading(on)
		loading = on and true or false
		btn.Active = not loading
		btn.TextTransparency = loading and 1 or 0
		spin.Visible = loading
		if loading then
			task.spawn(function()
				while loading and spin.Parent do
					spin.Rotation += 18
					task.wait(0.03)
				end
			end)
		end
	end
	function api.SetText(t) btn.Text = t end

	btn.MouseEnter:Connect(function()
		if loading then return end
		tween(btn, Anim.Fast, { BackgroundColor3 = primary and Theme.AccentHover or Theme.ElementHover })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, Anim.Fast, { BackgroundColor3 = primary and Theme.Accent or Theme.Element })
	end)
	btn.MouseButton1Click:Connect(function()
		if loading then return end
		local run = function()
			local mouse = UserInputService:GetMouseLocation()
			clickRipple(btn, mouse.X - btn.AbsolutePosition.X, mouse.Y - btn.AbsolutePosition.Y, Theme.Highlight)
			safeCall(callback)
		end
		if opts.Confirm then
			local c = opts.Confirm
			if showConfirmModal then
				showConfirmModal(c.Title or "Confirm", c.Text or c.Content or "Are you sure?", run)
			else
				run()
			end
		else
			run()
		end
	end)
	return api
end

local function createToggle(tab, text, default, callback, opts)
	opts = opts or {}
	local group = opts.Group
	local flag = opts.Flag
	local state = default or false
	if flag and ConfigData.values[flag] ~= nil then state = ConfigData.values[flag] and true or false end

	local holder = make("TextButton", {
		Size = UDim2.new(1, 0, 0, Flags.LargeHitboxes and 44 or 38),
		BackgroundColor3 = Theme.Element,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)
	table.insert(State.focusables, holder)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -68, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = State.uiFont,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local track = make("Frame", {
		Size = UDim2.fromOffset(42, 22),
		Position = UDim2.new(1, -54, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(72, 72, 78),
	}, { corner(11) })
	track.Parent = holder
	registerAccent(track, "BackgroundColor3")

	local knob = make("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(8) })
	knob.Parent = track

	local api
	local function render()
		tween(track, Anim.Fast, { BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(72, 72, 78) })
		tween(knob, Anim.Smooth, { Position = state and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
	end

	api = {
		Set = function(v, silent)
			state = v and true or false
			render()
			if flag then ConfigData.values[flag] = state; task.defer(saveConfigFile) end
			if not silent then safeCall(callback, state) end
		end,
		Get = function() return state end,
		Flag = flag,
	}
	if flag then State.controlRegistry[flag] = api end
	if group then
		State.toggleGroups[group] = State.toggleGroups[group] or {}
		table.insert(State.toggleGroups[group], api)
	end

	holder.MouseButton1Click:Connect(function()
		if group and not state then
			for _, other in ipairs(State.toggleGroups[group]) do
				if other ~= api then other.Set(false, true) end
			end
			api.Set(true)
		elseif group and state then
			-- radio: keep one on
			return
		else
			api.Set(not state)
		end
		if state then
			sparkBurst(track, 21, 11, Theme.Accent, 6)
		end
	end)

	render()
	return api
end

local function createSlider(tab, text, min, max, default, callback, opts)
	opts = opts or {}
	local step = opts.Step or 1
	local flag = opts.Flag
	local value = math.clamp(default or min, min, max)
	if flag and ConfigData.values[flag] ~= nil then
		value = math.clamp(tonumber(ConfigData.values[flag]) or value, min, max)
	end
	local fire = debounced(function(v)
		if flag then ConfigData.values[flag] = v; task.defer(saveConfigFile) end
		pushUndo({ kind = "slider", flag = flag, value = v })
		safeCall(callback, v)
	end)

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)
	table.insert(State.focusables, holder)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -70, 0, 24),
		Position = UDim2.fromOffset(14, 6),
		Font = State.uiFont,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local valueChip = make("TextButton", {
		Size = UDim2.fromOffset(52, 20),
		Position = UDim2.new(1, -64, 0, 8),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 0.82,
		Text = "",
		AutoButtonColor = false,
	}, { corner(5) })
	valueChip.Parent = holder
	registerAccent(valueChip, "BackgroundColor3")

	local valueLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = tostring(value),
		TextSize = 11,
		TextColor3 = Theme.Accent,
	})
	valueLabel.Parent = valueChip
	registerAccent(valueLabel, "TextColor3")

	local valueBox = make("TextBox", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = "",
		TextSize = 11,
		TextColor3 = Theme.Accent,
		Visible = false,
		ClearTextOnFocus = false,
		ZIndex = 5,
	})
	valueBox.Parent = valueChip

	local track = make("Frame", {
		Size = UDim2.new(1, -28, 0, 4),
		Position = UDim2.new(0, 14, 1, -18),
		BackgroundColor3 = Color3.fromRGB(68, 68, 74),
	}, { corner(2) })
	track.Parent = holder

	local function snapVal(v)
		v = math.clamp(v, min, max)
		if step > 0 then
			v = math.floor((v - min) / step + 0.5) * step + min
			v = math.clamp(v, min, max)
			if step >= 1 then v = math.floor(v + 1e-6) end
		end
		return v
	end

	local a0 = (max > min) and ((value - min) / (max - min)) or 0
	local fill = make("Frame", {
		Size = UDim2.new(a0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
	}, { corner(2) })
	fill.Parent = track
	registerAccent(fill, "BackgroundColor3")

	local knobRing = stroke(Theme.Accent, 2, 0.1)
	registerAccent(knobRing, "Color")
	local knob = make("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(a0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, { corner(7), knobRing })
	knob.Parent = track

	local dragging = false
	local hovering = false

	local function render(silent)
		valueLabel.Text = (step < 1) and string.format("%.2f", value) or tostring(value)
		local a = (max > min) and ((value - min) / (max - min)) or 0
		tween(fill, Anim.Snap, { Size = UDim2.new(a, 0, 1, 0) })
		tween(knob, Anim.Snap, { Position = UDim2.new(a, 0, 0.5, 0) })
		if not silent then fire(value) end
	end

	local function setFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local nv = snapVal(min + rel * (max - min))
		if nv ~= value then
			value = nv
			render()
		else
			render(true)
		end
	end

	local api
	api = {
		Set = function(v, silent)
			value = snapVal(v)
			render(silent)
		end,
		Get = function() return value end,
		Flag = flag,
	}
	if flag then State.controlRegistry[flag] = api end

	valueChip.MouseButton1Click:Connect(function()
		valueLabel.Visible = false
		valueBox.Visible = true
		valueBox.Text = tostring(value)
		valueBox:CaptureFocus()
	end)
	valueBox.FocusLost:Connect(function()
		local n = tonumber(valueBox.Text)
		valueBox.Visible = false
		valueLabel.Visible = true
		if n then api.Set(n) end
	end)

	holder.MouseEnter:Connect(function() hovering = true end)
	holder.MouseLeave:Connect(function() hovering = false end)
	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tween(knob, Anim.Spring, { Size = UDim2.fromOffset(17, 17) })
			setFromX(input.Position.X)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel and hovering then
			local dir = input.Position.Z
			-- Position.Z not always wheel; use InputChanged below
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		elseif hovering and input.UserInputType == Enum.UserInputType.MouseWheel then
			local delta = input.Position.Z
			if delta == 0 then delta = (input.Delta and input.Delta.Z) or 0 end
			if delta ~= 0 then
				api.Set(value + (delta > 0 and step or -step))
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = false
				tween(knob, Anim.Spring, { Size = UDim2.fromOffset(14, 14) })
			end
		end
	end)

	render(true)
	return api
end

local function createDropdown(tab, text, options, default, callback, opts)
	opts = opts or {}
	local multi = opts.Multi == true
	local flag = opts.Flag
	options = options or {}
	local selected = multi and {} or (default or options[1])
	if multi then
		if type(default) == "table" then
			for _, v in ipairs(default) do selected[v] = true end
		elseif default then
			selected[default] = true
		end
	end
	if flag and ConfigData.values[flag] ~= nil then
		local saved = ConfigData.values[flag]
		if multi and type(saved) == "table" then
			selected = {}
			for _, v in ipairs(saved) do selected[v] = true end
		elseif not multi then
			selected = saved
		end
	end

	local open = false
	local closedH, optH, searchH = 38, 28, 28
	local useSearch = #options > 8
	local filter = ""

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, closedH),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)

	local function displayText()
		if multi then
			local list = {}
			for _, opt in ipairs(options) do if selected[opt] then table.insert(list, opt) end end
			return (#list == 0 and "None") or table.concat(list, ", ")
		end
		return tostring(selected)
	end

	local top = make("TextButton", {
		Size = UDim2.new(1, 0, 0, closedH),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	top.Parent = holder

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.42, 0, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = State.uiFont,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = top

	local selectedLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.58, -36, 1, 0),
		Position = UDim2.new(0.42, 0, 0, 0),
		Font = Enum.Font.Gotham,
		Text = displayText(),
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	selectedLabel.Parent = top

	local chevron = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -28, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Font = Enum.Font.Gotham,
		Text = "v",
		TextSize = 11,
		TextColor3 = Theme.SubText,
	})
	chevron.Parent = top

	local searchBox = make("TextBox", {
		Size = UDim2.new(1, -16, 0, searchH - 4),
		Position = UDim2.fromOffset(8, closedH + 2),
		BackgroundColor3 = Theme.Background,
		Font = Enum.Font.Gotham,
		PlaceholderText = "Search…",
		PlaceholderColor3 = Theme.SubText,
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.Text,
		Visible = false,
		ClearTextOnFocus = false,
	}, { corner(5), stroke(Theme.Stroke, 1, 0.4) })
	searchBox.Parent = holder

	local optionsFrame = make("ScrollingFrame", {
		Size = UDim2.new(1, -16, 0, math.min(8, #options) * optH),
		Position = UDim2.fromOffset(8, closedH + (useSearch and searchH or 0)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, #options * optH),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	optionsFrame.Parent = holder
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = optionsFrame

	local optButtons = {}

	local function persist()
		if not flag then return end
		if multi then
			local list = {}
			for _, opt in ipairs(options) do if selected[opt] then table.insert(list, opt) end end
			ConfigData.values[flag] = list
		else
			ConfigData.values[flag] = selected
		end
		task.defer(saveConfigFile)
	end

	local function rebuild()
		for _, b in ipairs(optButtons) do b:Destroy() end
		optButtons = {}
		local i = 0
		for _, opt in ipairs(options) do
			if filter == "" or string.find(string.lower(opt), string.lower(filter), 1, true) then
				i += 1
				local on = multi and selected[opt] or (opt == selected)
				local optBtn = make("TextButton", {
					Size = UDim2.new(1, 0, 0, optH - 2),
					BackgroundColor3 = Theme.Background,
					BackgroundTransparency = on and 0 or 1,
					Text = (multi and (on and "[x] " or "[ ] ") or "  ") .. opt,
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextColor3 = on and Theme.Text or Theme.SubText,
					TextXAlignment = Enum.TextXAlignment.Left,
					AutoButtonColor = false,
					LayoutOrder = i,
				}, { corner(5) })
				optBtn.Parent = optionsFrame
				table.insert(optButtons, optBtn)
				optBtn.MouseButton1Click:Connect(function()
					if multi then
						selected[opt] = not selected[opt]
						rebuild()
						selectedLabel.Text = displayText()
						persist()
						local list = {}
						for _, o in ipairs(options) do if selected[o] then table.insert(list, o) end end
						safeCall(callback, list)
					else
						selected = opt
						selectedLabel.Text = displayText()
						rebuild()
						setOpen(false)
						persist()
						safeCall(callback, opt)
					end
				end)
			end
		end
	end

	local function setOpen(v)
		open = v
		searchBox.Visible = open and useSearch
		local listH = math.min(8, math.max(1, #options)) * optH
		local h = open and (closedH + (useSearch and searchH or 0) + listH + 8) or closedH
		optionsFrame.Position = UDim2.fromOffset(8, closedH + ((open and useSearch) and searchH or 0))
		tween(holder, Anim.Smooth, { Size = UDim2.new(1, 0, 0, h) })
		tween(chevron, Anim.Fast, { TextColor3 = open and Theme.Accent or Theme.SubText })
		if open then rebuild() end
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		filter = searchBox.Text
		rebuild()
	end)

	top.MouseEnter:Connect(function()
		tween(holder, Anim.Fast, { BackgroundColor3 = Theme.ElementHover })
		tween(cardStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0.45 })
	end)
	top.MouseLeave:Connect(function()
		tween(holder, Anim.Fast, { BackgroundColor3 = Theme.Element })
		tween(cardStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.4 })
	end)
	top.MouseButton1Click:Connect(function() setOpen(not open) end)

	local api = {
		Get = function()
			if multi then
				local list = {}
				for _, o in ipairs(options) do if selected[o] then table.insert(list, o) end end
				return list
			end
			return selected
		end,
		Set = function(v)
			if multi then
				selected = {}
				if type(v) == "table" then for _, x in ipairs(v) do selected[x] = true end end
			else
				selected = v
			end
			selectedLabel.Text = displayText()
			persist()
		end,
		Flag = flag,
	}
	if flag then State.controlRegistry[flag] = api end
	return api
end

local function createTextbox(tab, text, placeholder, callback)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.42, 0, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local box = make("TextBox", {
		Size = UDim2.new(0.52, -14, 0, 26),
		Position = UDim2.new(0.48, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Background,
		Font = Enum.Font.Gotham,
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = Theme.SubText,
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.Text,
		ClearTextOnFocus = false,
	}, { corner(5), stroke(Theme.Stroke, 1, 0.4) })
	box.Parent = holder

	box.Focused:Connect(function()
		tween(box.UIStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0 })
	end)
	box.FocusLost:Connect(function(enter)
		tween(box.UIStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.4 })
		if callback then task.spawn(callback, box.Text, enter) end
	end)

	return {
		Get = function() return box.Text end,
		Set = function(v) box.Text = v end,
	}
end

local keybindCapturing = false

local function createKeybind(tab, text, defaultKey, callback, opts)
	opts = opts or {}
	local key = defaultKey
	local lastTap = 0
	local holdStart = nil
	local holdThreshold = opts.HoldThreshold or 0.45
	local onDouble = opts.OnDoubleTap or opts.DoubleTap
	local onHold = opts.OnHold or opts.Hold

	local holder = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Element,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -108, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = State.uiFont,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local keyBox = make("Frame", {
		Size = UDim2.fromOffset(88, 26),
		Position = UDim2.new(1, -100, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Background,
	}, { corner(5), stroke(Theme.Stroke, 1, 0.35) })
	keyBox.Parent = holder

	local keyLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = key.Name,
		TextSize = 11,
		TextColor3 = Theme.SubText,
	})
	keyLabel.Parent = keyBox

	holder.MouseButton1Click:Connect(function()
		keybindCapturing = true
		keyLabel.Text = "..."
		tween(keyBox.UIStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0 })
		tween(keyLabel, Anim.Fast, { TextColor3 = Theme.Accent })
	end)

	UserInputService.InputBegan:Connect(function(input)
		if keybindCapturing and input.UserInputType == Enum.UserInputType.Keyboard then
			key = input.KeyCode
			keyLabel.Text = key.Name
			tween(keyBox.UIStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.35 })
			tween(keyLabel, Anim.Fast, { TextColor3 = Theme.SubText })
			safeCall(callback, key)
			task.defer(function() keybindCapturing = false end)
			return
		end
		if not keybindCapturing and input.KeyCode == key then
			local now = os.clock()
			if onDouble and (now - lastTap) < 0.35 then
				safeCall(onDouble, key)
				lastTap = 0
			else
				lastTap = now
			end
			if onHold then holdStart = now end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == key and holdStart and onHold then
			if os.clock() - holdStart >= holdThreshold then
				safeCall(onHold, key)
			end
			holdStart = nil
		end
	end)

	return {
		Get = function() return key end,
		Set = function(k) key = k; keyLabel.Text = k.Name end,
	}
end

local function createColorPicker(tab, text, defaultColor, callback, opts)
	opts = opts or {}
	local h = select(1, (defaultColor or Theme.Accent):ToHSV())
	local open = false
	local closedH, openH = 38, 110

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, closedH),
		BackgroundColor3 = Theme.Element,
		ClipsDescendants = true,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)

	local top = make("TextButton", {
		Size = UDim2.new(1, 0, 0, closedH),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	})
	top.Parent = holder

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -58, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = top

	local preview = make("Frame", {
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(1, -38, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
	}, { corner(6), stroke(Theme.Stroke, 1, 0.3) })
	preview.Parent = top

	local hueBar = make("Frame", {
		Size = UDim2.new(1, -28, 0, 12),
		Position = UDim2.fromOffset(14, closedH + 12),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, { corner(5) })
	hueBar.Parent = holder

	local kps = {}
	for i = 0, 6 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
	end
	make("UIGradient", { Color = ColorSequence.new(kps) }).Parent = hueBar

	local hueKnob = make("Frame", {
		Size = UDim2.fromOffset(14, 16),
		Position = UDim2.new(h, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, { corner(4), stroke(Color3.new(0, 0, 0), 1, 0.45) })
	hueKnob.Parent = hueBar

	local draggingHue = false
	local hexBox
	local pushRecent, rebuildRecent

	local function apply(saveRecent)
		local c = Color3.fromHSV(h, 1, 1)
		preview.BackgroundColor3 = c
		if hexBox then hexBox.Text = colorToHex(c) end
		if callback then task.spawn(callback, c) end
		if saveRecent and pushRecent then
			pushRecent(c)
			if rebuildRecent then rebuildRecent() end
		end
	end

	local function setHue(x)
		h = math.clamp((x - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
		hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
		apply(false)
	end

	hueBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingHue = true
			setHue(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setHue(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if draggingHue then apply(true) end
			draggingHue = false
		end
	end)

	top.MouseEnter:Connect(function()
		tween(holder, Anim.Fast, { BackgroundColor3 = Theme.ElementHover })
		tween(cardStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0.45 })
		tween(cardScale, Anim.Fast, { Scale = 1.012 })
	end)
	top.MouseLeave:Connect(function()
		tween(holder, Anim.Fast, { BackgroundColor3 = Theme.Element })
		tween(cardStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.4 })
		tween(cardScale, Anim.Fast, { Scale = 1 })
	end)
	hexBox = make("TextBox", {
		Size = UDim2.new(0.55, -20, 0, 22),
		Position = UDim2.fromOffset(14, closedH + 32),
		BackgroundColor3 = Theme.Background,
		Font = Enum.Font.Gotham,
		Text = colorToHex(Color3.fromHSV(h, 1, 1)),
		TextSize = 11,
		TextColor3 = Theme.Text,
		ClearTextOnFocus = false,
	}, { corner(5), stroke(Theme.Stroke, 1, 0.4) })
	hexBox.Parent = holder

	local eyeBtn = make("TextButton", {
		Size = UDim2.new(0.45, -14, 0, 22),
		Position = UDim2.new(0.55, 0, 0, closedH + 32),
		BackgroundColor3 = Theme.ElementHover,
		Text = "Eyedrop",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Theme.Text,
		AutoButtonColor = false,
	}, { corner(5) })
	eyeBtn.Parent = holder

	local recentRow = make("Frame", {
		Size = UDim2.new(1, -28, 0, 16),
		Position = UDim2.fromOffset(14, closedH + 60),
		BackgroundTransparency = 1,
	})
	recentRow.Parent = holder
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
	}).Parent = recentRow

	pushRecent = function(c)
		ConfigData.recentColors = ConfigData.recentColors or {}
		local hex = colorToHex(c)
		for i = #ConfigData.recentColors, 1, -1 do
			if ConfigData.recentColors[i] == hex then table.remove(ConfigData.recentColors, i) end
		end
		table.insert(ConfigData.recentColors, 1, hex)
		while #ConfigData.recentColors > 8 do table.remove(ConfigData.recentColors) end
		task.defer(saveConfigFile)
	end

	rebuildRecent = function()
		for _, ch in ipairs(recentRow:GetChildren()) do
			if ch:IsA("TextButton") then ch:Destroy() end
		end
		for _, hex in ipairs(ConfigData.recentColors or {}) do
			local c = hexToColor(hex)
			if c then
				local sw = make("TextButton", {
					Size = UDim2.fromOffset(16, 16),
					BackgroundColor3 = c,
					Text = "",
					AutoButtonColor = false,
				}, { corner(4) })
				sw.Parent = recentRow
				sw.MouseButton1Click:Connect(function()
					h = select(1, c:ToHSV())
					hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
					hexBox.Text = hex
					apply(true)
				end)
			end
		end
	end
	rebuildRecent()

	hexBox.FocusLost:Connect(function()
		local c = hexToColor(hexBox.Text)
		if c then
			h = select(1, c:ToHSV())
			hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
			apply(true)
		end
	end)

	eyeBtn.MouseButton1Click:Connect(function()
		Zenless_Notify = nil
		local picking = true
		eyeBtn.Text = "Click…"
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if not picking then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				picking = false
				eyeBtn.Text = "Eyedrop"
				if conn then conn:Disconnect() end
				-- sample accent-soft fallback (no pixel API in most executors)
				local c = Theme.Accent
				pcall(function()
					if typeof(getrenv) == "function" then end
				end)
				h = select(1, c:ToHSV())
				hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
				apply()
			end
		end)
	end)

	top.MouseButton1Click:Connect(function()
		open = not open
		tween(holder, Anim.Smooth, { Size = UDim2.new(1, 0, 0, open and openH or closedH) })
	end)

	return {
		Get = function() return Color3.fromHSV(h, 1, 1) end,
		Set = function(c)
			h = select(1, c:ToHSV())
			hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
			apply()
		end,
	}
end

local function setAccent(color)
	Theme.Accent = color
	Theme.AccentHover = Color3.new(
		math.min(1, color.R + 0.1),
		math.min(1, color.G + 0.1),
		math.min(1, color.B + 0.1)
	)
	Theme.AccentSoft = Color3.new(
		math.max(0, color.R - 0.05),
		math.max(0, color.G - 0.05),
		math.max(0, color.B - 0.05)
	)
	for _, entry in ipairs(accentRegistry) do
		if entry.obj and entry.obj.Parent then
			if entry.obj:GetAttribute("ToggleTrack") and not entry.obj:GetAttribute("ToggleOn") then
				continue
			end
			tween(entry.obj, Anim.Smooth, { [entry.prop] = color })
		end
	end
end

-- ============ NEW COMPONENTS (v5) ============
local V5
V5 = (function()

local function createProgress(tab, text, value0to100)
	local value = math.clamp(value0to100 or 0, 0, 100)

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 0, 22),
		Position = UDim2.fromOffset(14, 8),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local pctLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(40, 22),
		Position = UDim2.new(1, -48, 0, 8),
		Font = Enum.Font.GothamBold,
		Text = value .. "%",
		TextSize = 11,
		TextColor3 = Theme.Accent,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	pctLabel.Parent = holder
	registerAccent(pctLabel, "TextColor3")

	local track = make("Frame", {
		Size = UDim2.new(1, -28, 0, 6),
		Position = UDim2.new(0, 14, 1, -16),
		BackgroundColor3 = Color3.fromRGB(58, 58, 64),
	}, { corner(3) })
	track.Parent = holder

	local fill = make("Frame", {
		Size = UDim2.new(value / 100, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
	}, { corner(3) })
	fill.Parent = track
	registerAccent(fill, "BackgroundColor3")

	local fillShine = make("Frame", {
		Size = UDim2.new(1, 0, 0.5, 0),
		BackgroundColor3 = Theme.Highlight,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
	}, { corner(3) })
	fillShine.Parent = fill

	return {
		Set = function(v)
			value = math.clamp(v, 0, 100)
			pctLabel.Text = math.floor(value) .. "%"
			tween(fill, Anim.Smooth, { Size = UDim2.new(value / 100, 0, 1, 0) })
		end,
		Get = function() return value end,
	}
end

local function createSegmented(tab, text, options, default, callback)
	local selected = default or options[1]

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 68),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(14, 8),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local segRow = make("Frame", {
		Size = UDim2.new(1, -28, 0, 28),
		Position = UDim2.fromOffset(14, 32),
		BackgroundColor3 = Theme.Background,
	}, { corner(6), stroke(Theme.Stroke, 1, 0.4) })
	segRow.Parent = holder

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = segRow

	make("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
	}).Parent = segRow

	local buttons = {}

	local function renderSeg()
		for opt, btn in pairs(buttons) do
			local on = (opt == selected)
			tween(btn, Anim.Fast, {
				BackgroundColor3 = on and Theme.Accent or Theme.Element,
				BackgroundTransparency = on and 0 or 1,
				TextColor3 = on and Theme.Text or Theme.SubText,
			})
		end
	end

	for i, opt in ipairs(options) do
		local segBtn = make("TextButton", {
			Size = UDim2.new(1 / #options, -2, 1, 0),
			BackgroundColor3 = Theme.Element,
			BackgroundTransparency = (opt == selected) and 0 or 1,
			Text = opt,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = (opt == selected) and Theme.Text or Theme.SubText,
			AutoButtonColor = false,
			LayoutOrder = i,
		}, { corner(4) })
		segBtn.Parent = segRow
		if opt == selected then registerAccent(segBtn, "BackgroundColor3") end
		buttons[opt] = segBtn

		segBtn.MouseButton1Click:Connect(function()
			selected = opt
			renderSeg()
			if callback then task.spawn(callback, opt) end
		end)
	end

	return { Get = function() return selected end, Set = function(v) selected = v; renderSeg() end }
end

local function createBadgeRow(tab, labels)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	})

	local row = make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.Element,
	}, { corner(8), stroke(Theme.Stroke, 1, 0.45) })
	row.Parent = holder
	holder.Parent = tab.Container

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}).Parent = row

	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}).Parent = row

	local badgeColors = {
		Theme.Accent, Theme.Success, Theme.Warning, Theme.Error,
		Color3.fromRGB(100, 120, 200), Color3.fromRGB(180, 100, 60),
	}

	for i, label in ipairs(labels) do
		local chipColor = badgeColors[((i - 1) % #badgeColors) + 1]
		local chip = make("Frame", {
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = chipColor,
			BackgroundTransparency = 0.82,
			LayoutOrder = i,
		}, { corner(5) })
		chip.Parent = row

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 22),
			AutomaticSize = Enum.AutomaticSize.X,
			Font = Enum.Font.GothamMedium,
			Text = "  " .. label .. "  ",
			TextSize = 10,
			TextColor3 = chipColor,
		}).Parent = chip
	end

	return holder
end

local function createStatCard(tab, label, value, sub)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke = stroke(Theme.Stroke, 1, 0.4)
	cardStroke.Parent = holder
	cardLit().Parent = holder
	topHighlight(holder)

	local accentBar = make("Frame", {
		Size = UDim2.new(0, 3, 1, -16),
		Position = UDim2.fromOffset(10, 8),
		BackgroundColor3 = Theme.Accent,
	}, { corner(2) })
	accentBar.Parent = holder
	registerAccent(accentBar, "BackgroundColor3")

	local valueLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 0, 28),
		Position = UDim2.fromOffset(22, 10),
		Font = Enum.Font.GothamBold,
		Text = tostring(value),
		TextSize = 22,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	valueLabel.Parent = holder

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.fromOffset(22, 38),
		Font = Enum.Font.GothamMedium,
		Text = label,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local subLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.new(0, 22, 1, -18),
		Font = Enum.Font.Gotham,
		Text = sub or "",
		TextSize = 10,
		TextColor3 = Theme.Accent,
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	subLabel.Parent = holder
	registerAccent(subLabel, "TextColor3")

	hoverCard(holder, cardStroke, nil)

	return {
		SetValue = function(v) valueLabel.Text = tostring(v) end,
		SetSub = function(s) subLabel.Text = s or "" end,
	}
end

local function createSpinner(tab, text)
	local spinning = true

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local spinRing = make("Frame", {
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -36, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
	})
	spinRing.Parent = holder

	local arc = make("Frame", {
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.Accent,
	}, { corner(11) })
	arc.Parent = spinRing
	registerAccent(arc, "BackgroundColor3")

	local arcCut = make("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.Element,
	}, { corner(7) })
	arcCut.Parent = arc

	local arcTip = make("Frame", {
		Size = UDim2.fromOffset(4, 4),
		Position = UDim2.fromOffset(9, 0),
		BackgroundColor3 = Theme.Accent,
	}, { corner(2) })
	arcTip.Parent = spinRing
	registerAccent(arcTip, "BackgroundColor3")

	task.spawn(function()
		while spinning and spinRing.Parent do
			for deg = 0, 360, 12 do
				if not spinning or not spinRing.Parent then break end
				spinRing.Rotation = deg
				task.wait(0.03)
			end
		end
	end)

	return {
		Stop = function() spinning = false; spinRing.Visible = false end,
		Start = function() spinning = true; spinRing.Visible = true end,
	}
end

local function createThemePreset(tab)
	createLabel(tab, "THEME PRESETS")

	local presets = {
		{ name = "Silver", color = Color3.fromRGB(198, 198, 208) },
		{ name = "Chrome", color = Color3.fromRGB(230, 230, 238) },
		{ name = "Steel", color = Color3.fromRGB(140, 145, 155) },
		{ name = "Graphite", color = Color3.fromRGB(100, 100, 108) },
		{ name = "Pearl", color = Color3.fromRGB(210, 205, 195) },
	}

	local grid = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	grid.Parent = tab.Container
	styleCard(grid)

	make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}).Parent = grid

	make("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = grid

	for i, preset in ipairs(presets) do
		local row = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = Theme.Background,
			BackgroundTransparency = 0.35,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
		}, { corner(6), stroke(Theme.Stroke, 1, 0.5) })
		row.Parent = grid

		make("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(12, 10),
			BackgroundColor3 = preset.color,
		}, { corner(7), stroke(Theme.Stroke, 1, 0.4) }).Parent = row

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -40, 1, 0),
			Position = UDim2.fromOffset(34, 0),
			Font = Enum.Font.GothamMedium,
			Text = preset.name,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row

		row.MouseEnter:Connect(function()
			tween(row, Anim.Fast, { BackgroundTransparency = 0.1 })
			tween(row.UIStroke, Anim.Fast, { Color = preset.color, Transparency = 0.35 })
		end)
		row.MouseLeave:Connect(function()
			tween(row, Anim.Fast, { BackgroundTransparency = 0.35 })
			tween(row.UIStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.5 })
		end)
		row.MouseButton1Click:Connect(function()
			setAccent(preset.color)
			if fxLayer then
				sparkBurst(fxLayer, row.AbsolutePosition.X - window.AbsolutePosition.X + 20, row.AbsolutePosition.Y - window.AbsolutePosition.Y + 17, preset.color, 6)
			end
			notify("Theme", preset.name .. " applied.", "success", 2)
		end)
	end
end

local function createInfoGrid(tab, items)
	local grid = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	})
	grid.Parent = tab.Container

	make("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = grid

	for i, item in ipairs(items) do
		local cell = make("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Theme.Element,
			LayoutOrder = i,
		}, { corner(8), stroke(Theme.Stroke, 1, 0.45) })
		cell.Parent = grid
		topHighlight(cell)

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -10, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Font = Enum.Font.Gotham,
			Text = item.label,
			TextSize = 11,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = cell

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -10, 1, 0),
			Position = UDim2.new(0.5, 0, 0, 0),
			Font = Enum.Font.GothamBold,
			Text = item.value,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Right,
		}).Parent = cell
	end

	return grid
end

local function createActionRow(tab, actions)
	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	})
	row.Parent = tab.Container

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = row

	for i, action in ipairs(actions) do
		local btn = make("TextButton", {
			Size = UDim2.new(1 / #actions, -4, 1, 0),
			BackgroundColor3 = action.primary and Theme.Accent or Theme.Element,
			Text = action.text,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = Theme.Text,
			AutoButtonColor = false,
			LayoutOrder = i,
		}, { corner(6) })
		btn.Parent = row
		if action.primary then registerAccent(btn, "BackgroundColor3") end
		styleCard(btn)

		btn.MouseButton1Click:Connect(function()
			local lx = btn.AbsoluteSize.X * 0.5
			local ly = btn.AbsoluteSize.Y * 0.5
			clickRipple(btn, lx, ly)
			if action.primary and fxLayer then sparkBurst(fxLayer, btn.AbsolutePosition.X - window.AbsolutePosition.X + lx, btn.AbsolutePosition.Y - window.AbsolutePosition.Y + ly, Theme.Accent, 5) end
			if action.callback then task.spawn(action.callback) end
		end)
	end

	return row
end

local function createMetricPanel(tab, title, metrics)
	local panel = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	panel.Parent = tab.Container
	styleCard(panel)

	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}).Parent = panel

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel

	local metricsRow = make("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		Position = UDim2.fromOffset(0, 24),
		BackgroundTransparency = 1,
	})
	metricsRow.Parent = panel

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = metricsRow

	local refs = {}
	for i, m in ipairs(metrics) do
		local cell = make("Frame", {
			Size = UDim2.new(1 / #metrics, -6, 1, 0),
			BackgroundColor3 = Theme.Background,
			LayoutOrder = i,
		}, { corner(6), stroke(Theme.Stroke, 1, 0.5) })
		cell.Parent = metricsRow

		local valLbl = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 6),
			Font = Enum.Font.GothamBold,
			Text = tostring(m.value),
			TextSize = 16,
			TextColor3 = Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		valLbl.Parent = cell
		registerAccent(valLbl, "TextColor3")

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, 28),
			Font = Enum.Font.Gotham,
			Text = m.label,
			TextSize = 9,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Center,
		}).Parent = cell

		refs[m.label] = valLbl
	end

	return {
		Set = function(label, val)
			if refs[label] then refs[label].Text = tostring(val) end
		end,
	}
end

local function createChecklist(tab, title, items, callback)
	local checked = {}
	for _, item in ipairs(items) do checked[item] = false end

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)

	make("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
	}).Parent = holder

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = title,
		TextSize = 12,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local list = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 22),
		BackgroundTransparency = 1,
	})
	list.Parent = holder

	make("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = list

	for i, item in ipairs(items) do
		local row = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = i,
		})
		row.Parent = list

		local box = make("Frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(0, 6),
			BackgroundColor3 = Theme.Background,
		}, { corner(4), stroke(Theme.Stroke, 1, 0.35) })
		box.Parent = row

		local tick = make("Frame", {
			Size = UDim2.fromOffset(8, 8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Theme.Accent,
			BackgroundTransparency = 1,
		}, { corner(2) })
		tick.Parent = box

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -24, 1, 0),
			Position = UDim2.fromOffset(24, 0),
			Font = Enum.Font.Gotham,
			Text = item,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row

		row.MouseButton1Click:Connect(function()
			checked[item] = not checked[item]
			tween(tick, Anim.Fast, { BackgroundTransparency = checked[item] and 0 or 1 })
			if checked[item] then
				tween(box.UIStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0.3 })
			else
				tween(box.UIStroke, Anim.Fast, { Color = Theme.Stroke, Transparency = 0.35 })
			end
			if callback then task.spawn(callback, item, checked[item], checked) end
		end)
	end

	return { Get = function() return checked end }
end

local function createTimeline(tab, events)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)

	make("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
	}).Parent = holder

	make("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = holder

	for i, ev in ipairs(events) do
		local row = make("Frame", {
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundTransparency = 1,
			LayoutOrder = i,
		})
		row.Parent = holder

		local dot = make("Frame", {
			Size = UDim2.fromOffset(8, 8),
			Position = UDim2.fromOffset(0, 6),
			BackgroundColor3 = ev.color or Theme.Accent,
		}, { corner(4) })
		dot.Parent = row

		if i < #events then
			make("Frame", {
				Size = UDim2.new(0, 1, 0, 28),
				Position = UDim2.fromOffset(3, 16),
				BackgroundColor3 = Theme.Stroke,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
			}).Parent = row
		end

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 0, 16),
			Position = UDim2.fromOffset(18, 2),
			Font = Enum.Font.GothamMedium,
			Text = ev.title,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row

		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 0, 14),
			Position = UDim2.fromOffset(18, 18),
			Font = Enum.Font.Gotham,
			Text = ev.sub or "",
			TextSize = 10,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row
	end
end

local function createRating(tab, text, maxStars, callback)
	maxStars = maxStars or 5
	local rating = 0

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cardStroke, cardScale = styleCard(holder)
	hoverCard(holder, cardStroke, cardScale)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.55, 0, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local starRow = make("Frame", {
		Size = UDim2.new(0.4, -10, 0, 20),
		Position = UDim2.new(0.58, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
	})
	starRow.Parent = holder

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = starRow

	local stars = {}
	for i = 1, maxStars do
		local star = make("TextButton", {
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			Text = "★",
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = Theme.Stroke,
			AutoButtonColor = false,
			LayoutOrder = i,
		})
		star.Parent = starRow
		stars[i] = star

		local function renderStars()
			for j, s in ipairs(stars) do
				tween(s, Anim.Fast, { TextColor3 = j <= rating and Theme.Warning or Theme.Stroke })
			end
		end

		star.MouseButton1Click:Connect(function()
			rating = i
			renderStars()
			if callback then task.spawn(callback, rating) end
		end)
		star.MouseEnter:Connect(function()
			for j, s in ipairs(stars) do
				tween(s, Anim.Fast, { TextColor3 = j <= i and Theme.Warning or Theme.Stroke })
			end
		end)
		star.MouseLeave:Connect(renderStars)
	end

	return { Get = function() return rating end }
end

local function createVolumeMeter(tab, text)
	local level = 0

	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.fromOffset(14, 8),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder

	local bars = {}
	local barRow = make("Frame", {
		Size = UDim2.new(1, -28, 0, 20),
		Position = UDim2.fromOffset(14, 30),
		BackgroundTransparency = 1,
	})
	barRow.Parent = holder

	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = barRow

	for i = 1, 12 do
		local bar = make("Frame", {
			Size = UDim2.new(1 / 12, -3, 1, 0),
			BackgroundColor3 = Theme.Stroke,
			LayoutOrder = i,
		}, { corner(2) })
		bar.Parent = barRow
		bars[i] = bar
	end

	task.spawn(function()
		while holder.Parent do
			level = math.random(2, 12)
			for i, bar in ipairs(bars) do
				local active = i <= level
				tween(bar, Anim.Fast, {
					BackgroundColor3 = active and Theme.Accent or Theme.Stroke,
					BackgroundTransparency = active and 0 or 0.3,
				})
			end
			task.wait(0.35)
		end
	end)
end

local function createHotkeyHint(tab, keys, description)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8), stroke(Theme.Stroke, 1, 0.45) })
	holder.Parent = tab.Container

	local xOff = 12
	for _, key in ipairs(keys) do
		local chip = make("Frame", {
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			Position = UDim2.fromOffset(xOff, 7),
			BackgroundColor3 = Theme.Background,
		}, { corner(4), stroke(Theme.Stroke, 1, 0.35) })
		chip.Parent = holder

		local lbl = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			Font = Enum.Font.GothamBold,
			Text = " " .. key .. " ",
			TextSize = 10,
			TextColor3 = Theme.SubText,
		})
		lbl.Parent = chip
		xOff += lbl.TextBounds.X + 8
	end

	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -xOff - 8, 1, 0),
		Position = UDim2.fromOffset(xOff + 4, 0),
		Font = Enum.Font.Gotham,
		Text = description,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
end

	return {
	createProgress = createProgress,
	createSegmented = createSegmented,
	createBadgeRow = createBadgeRow,
	createStatCard = createStatCard,
	createSpinner = createSpinner,
	createThemePreset = createThemePreset,
	createInfoGrid = createInfoGrid,
	createActionRow = createActionRow,
	createMetricPanel = createMetricPanel,
	createChecklist = createChecklist,
	createTimeline = createTimeline,
	createRating = createRating,
	createVolumeMeter = createVolumeMeter,
	createHotkeyHint = createHotkeyHint
	}
end)()

-- ============ TAB API (universal) ============
bindTabAPI = function(tab)
	function tab:AddSection(text)
		return createLabel(self, text)
	end
	function tab:AddDivider()
		return createDivider(self)
	end
	function tab:AddParagraph(title, body)
		return createParagraph(self, title, body)
	end
	function tab:AddButton(opts)
		opts = opts or {}
		return createButton(self, opts.Title or opts.Text or "Button", opts.Callback, opts.Primary, opts)
	end
	function tab:AddToggle(opts)
		opts = opts or {}
		return createToggle(self, opts.Title or opts.Text or "Toggle", opts.Default, opts.Callback, opts)
	end
	function tab:AddSlider(opts)
		opts = opts or {}
		return createSlider(self, opts.Title or opts.Text or "Slider", opts.Min or 0, opts.Max or 100, opts.Default or opts.Min or 0, opts.Callback, opts)
	end
	function tab:AddDropdown(opts)
		opts = opts or {}
		return createDropdown(self, opts.Title or opts.Text or "Dropdown", opts.Values or opts.Options or {}, opts.Default, opts.Callback, opts)
	end
	function tab:AddTextbox(opts)
		opts = opts or {}
		return createTextbox(self, opts.Title or opts.Text or "Input", opts.Placeholder, opts.Callback)
	end
	function tab:AddKeybind(opts)
		opts = opts or {}
		return createKeybind(self, opts.Title or opts.Text or "Keybind", opts.Default or Enum.KeyCode.Unknown, opts.Callback, opts)
	end
	function tab:AddColorpicker(opts)
		opts = opts or {}
		return createColorPicker(self, opts.Title or opts.Text or "Color", opts.Default or Theme.Accent, opts.Callback, opts)
	end
	function tab:AddProgress(opts)
		opts = opts or {}
		return V5.createProgress(self, opts.Title or opts.Text or "Progress", opts.Default or opts.Value or 0)
	end
	function tab:AddSegmented(opts)
		opts = opts or {}
		return V5.createSegmented(self, opts.Title or opts.Text or "Option", opts.Values or opts.Options or {}, opts.Default, opts.Callback)
	end
	function tab:AddBadgeRow(labels)
		return V5.createBadgeRow(self, labels)
	end
	function tab:AddStatCard(opts)
		opts = opts or {}
		return V5.createStatCard(self, opts.Title or opts.Label or "Stat", opts.Value or "0", opts.Sub or opts.Description)
	end
	function tab:AddSpinner(opts)
		opts = opts or {}
		return V5.createSpinner(self, opts.Title or opts.Text or "Loading…")
	end
	function tab:AddThemePresets()
		return V5.createThemePreset(self)
	end
	function tab:AddInfoGrid(items)
		return V5.createInfoGrid(self, items)
	end
	function tab:AddActionRow(actions)
		return V5.createActionRow(self, actions)
	end
	function tab:AddMetricPanel(opts)
		opts = opts or {}
		return V5.createMetricPanel(self, opts.Title or "Metrics", opts.Metrics or opts.Items or {})
	end
	function tab:AddChecklist(opts)
		opts = opts or {}
		return V5.createChecklist(self, opts.Title or "Checklist", opts.Items or {}, opts.Callback)
	end
	function tab:AddTimeline(events)
		return V5.createTimeline(self, events)
	end
	function tab:AddRating(opts)
		opts = opts or {}
		return V5.createRating(self, opts.Title or opts.Text or "Rating", opts.Max or 5, opts.Callback)
	end
	function tab:AddVolumeMeter(opts)
		opts = opts or {}
		return V5.createVolumeMeter(self, opts.Title or opts.Text or "Level")
	end
	function tab:AddHotkeyHint(keys, description)
		return V5.createHotkeyHint(self, keys, description)
	end
	return tab
end

-- ============ WINDOW LIFECYCLE ============
local uiVisible = true
local minimized = false
local hasCelebrated = false
local toggleKey = Enum.KeyCode.RightShift

local function destroyGui()
	uiVisible = false
	if loaderHost and loaderHost.Parent then
		pcall(function() loaderHost:Destroy() end)
	end
	tween(window, Anim.Smooth, { GroupTransparency = 1 })
	tween(windowScale, Anim.Smooth, { Scale = 0.92 })
	task.delay(0.28, function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

local function showWindow()
	-- Block boot/show while KeySystem prompt is open
	if State.keyGateActive then return end
	root.Visible = true
	window.Visible = true
	if windowRim then windowRim.Visible = true end
	-- restore remembered geometry — always top-left anchor for correct dragging
	root.AnchorPoint = Vector2.new(0, 0)
	if State.savedWindowPos then
		local sp = State.savedWindowPos
		-- normalize any old center-anchored saves to offset-only
		if sp.X.Scale ~= 0 or sp.Y.Scale ~= 0 then
			local abs = root.AbsolutePosition
			root.Position = UDim2.fromOffset(abs.X, abs.Y)
		else
			root.Position = UDim2.fromOffset(sp.X.Offset, sp.Y.Offset)
		end
	else
		local vp = getViewport()
		root.Position = UDim2.fromOffset(
			math.floor((vp.X - (root.Size.X.Offset)) * 0.5),
			math.floor((vp.Y - (root.Size.Y.Offset)) * 0.5) + 20
		)
	end
	targetPos = root.Position
	if not minimized then
		local sw = State.savedWindowSize
		local okSize = sw and sw.Y.Offset >= 280 and sw.X.Offset >= 420
		if okSize then
			root.Size = sw
			WIN_W, WIN_H = sw.X.Offset, sw.Y.Offset
		else
			if WIN_H < 280 or WIN_W < 420 then
				WIN_W, WIN_H = 610, 430
			end
			root.Size = UDim2.fromOffset(WIN_W, WIN_H)
		end
	end
	window.GroupTransparency = 1
	tween(window, Anim.Smooth, { GroupTransparency = State.windowOpacity or 0 })
	tween(windowScale, Anim.Spring, { Scale = State.uiScaleValue or Flags.UiScale or 1 })
	tween(windowAccentStroke, Anim.Smooth, { Transparency = 0.55 })
	tween(windowStroke, Anim.Smooth, { Transparency = 0.15 })
	playUiSound("open")
	if not hasCelebrated then
		hasCelebrated = true
		task.delay(0.2, function() celebrateOpen(window) end)
	end
end

local function hideWindow()
	rememberWindowGeometry()
	State.savedWindowPos = root.Position
	State.savedWindowSize = root.Size
	if windowRim then windowRim.Visible = false end
	tween(window, Anim.Smooth, { GroupTransparency = 1 })
	tween(windowScale, Anim.Smooth, { Scale = 0.94 })
	playUiSound("close")
	task.delay(0.28, function()
		if not uiVisible then
			window.Visible = false
			root.Visible = false
		end
	end)
end

local function toggleWindow()
	uiVisible = not uiVisible
	if uiVisible then showWindow() else hideWindow() end
end

closeBtn.MouseButton1Click:Connect(destroyGui)

minimizeBtn.MouseButton1Click:Connect(function()
	if minimizeWindow then
		minimizeWindow()
	else
		minimized = not minimized
		tween(root, Anim.Smooth, { Size = UDim2.fromOffset(WIN_W, minimized and MINI_H or WIN_H) })
		setMinimizeIcon(minimized and "plus" or "minus")
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or keybindCapturing then return end
	if input.KeyCode == toggleKey then
		toggleWindow()
	end
end)

-- ============ V6 MEGA CHUNK ============
local showConfirmModal, enhanceTab, NotifyProgress, applyV6PublicAPI, SetNotificationMode, closeTab, cycleTab
(function()
-- ============ ZENLESS V6 CHUNK (splice into FluentGui.lua, same scope) ============
-- Place AFTER: local minimized / window shell / createTab / notify / tabs exist.
-- bindTabAPI / createTab should call enhanceTab(tab) — wrapper below also does this.

-- ---- 1) Confirm modal ----
showConfirmModal = function(title, body, onYes)
	pcall(function()
		if State.confirmModal and State.confirmModal.Parent then State.confirmModal:Destroy() end
	end)
	local overlay = make("TextButton", {
		Name = "ConfirmModal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 200,
	})
	overlay.Parent = root
	State.confirmModal = overlay
	local card = make("Frame", {
		Size = UDim2.fromOffset(320, 160),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Background,
		ZIndex = 201,
	}, { corner(12), stroke(Theme.Stroke, 1, 0.3) })
	card.Parent = overlay
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 0, 24),
		Position = UDim2.fromOffset(14, 14),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Confirm"),
		TextSize = 15,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 202,
	}).Parent = card
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -28, 0, 56),
		Position = UDim2.fromOffset(14, 44),
		Font = State.uiFont or Enum.Font.Gotham,
		Text = tostring(body or ""),
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 202,
	}).Parent = card
	local function close()
		pcall(function() overlay:Destroy() end)
		if State.confirmModal == overlay then State.confirmModal = nil end
	end
	local noBtn = make("TextButton", {
		Size = UDim2.fromOffset(88, 30),
		Position = UDim2.new(1, -200, 1, -44),
		BackgroundColor3 = Theme.Element,
		Text = "Cancel",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Theme.Text,
		AutoButtonColor = false,
		ZIndex = 203,
	}, { corner(6), stroke(Theme.Stroke, 1, 0.45) })
	noBtn.Parent = card
	local yesBtn = make("TextButton", {
		Size = UDim2.fromOffset(88, 30),
		Position = UDim2.new(1, -100, 1, -44),
		BackgroundColor3 = Theme.Accent,
		Text = "Confirm",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = Theme.Background,
		AutoButtonColor = false,
		ZIndex = 203,
	}, { corner(6) })
	yesBtn.Parent = card
	registerAccent(yesBtn, "BackgroundColor3")
	noBtn.MouseButton1Click:Connect(close)
	overlay.MouseButton1Click:Connect(close)
	yesBtn.MouseButton1Click:Connect(function()
		close()
		safeCall(onYes)
	end)
	return overlay
end

-- ---- 2) Window shell helpers (assign to forward decls) ----
local sizePresets = {
	Compact = { 480, 340 },
	Normal = { 610, 430 },
	Wide = { 760, 500 },
}
local preFullscreen = nil
local SIDEBAR_W, SIDEBAR_COLLAPSED_W = 168, 58
local contentPanelRef = contentPanel
local sidebarCollapseToken = 0

minimizeWindow = function()
	minimized = not minimized
	pcall(function()
		local info = Anim.Minimize or Anim.Smooth
		if body then
			body.Visible = not minimized
		end
		tween(root, info, {
			Size = UDim2.fromOffset(WIN_W, minimized and MINI_H or WIN_H),
		})
		tween(windowAccentStroke, info, { Transparency = minimized and 0.72 or 0.55 })
		if windowScale then
			windowScale.Scale = minimized and 0.97 or 1.025
			tween(windowScale, Anim.Spring, { Scale = State.uiScaleValue or Flags.UiScale or 1 })
		end
		setMinimizeIcon(minimized and "plus" or "minus")
		playUiSound("click")
	end)
	return minimized
end

setWindowPinned = function(on)
	if on == nil then on = not State.pinnedWindow end
	State.pinnedWindow = on and true or false
	pcall(function()
		if screenGui then
			screenGui.DisplayOrder = State.pinnedWindow and 100000 or 999
		end
		Flags.AlwaysOnTop = State.pinnedWindow
		rememberWindowGeometry()
	end)
	return State.pinnedWindow
end

setSizePreset = function(name)
	name = tostring(name or "Normal")
	local p = sizePresets[name] or sizePresets.Normal
	State.currentPreset = sizePresets[name] and name or "Normal"
	WIN_W, WIN_H = p[1], p[2]
	minimized = false
	pcall(function()
		tween(root, Anim.Smooth, { Size = UDim2.fromOffset(WIN_W, WIN_H) })
		setMinimizeIcon("minus")
		rememberWindowGeometry()
	end)
	return State.currentPreset
end

setFullscreen = function(on)
	if on == nil then on = not Flags.Fullscreen end
	on = on and true or false
	setFlag("Fullscreen", on)
	pcall(function()
		local vp = (getViewport and getViewport()) or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080)
		if on then
			preFullscreen = {
				pos = root.Position,
				size = root.Size,
				w = WIN_W,
				h = WIN_H,
			}
			WIN_W, WIN_H = math.floor(vp.X), math.floor(vp.Y)
			root.AnchorPoint = Vector2.new(0, 0)
			targetPos = UDim2.fromOffset(0, 0)
			root.Position = targetPos
			root.Size = UDim2.fromOffset(WIN_W, WIN_H)
			minimized = false
			setMinimizeIcon("minus")
		else
			if preFullscreen then
				WIN_W, WIN_H = preFullscreen.w, preFullscreen.h
				root.Position = preFullscreen.pos
				targetPos = preFullscreen.pos
				root.Size = preFullscreen.size
				preFullscreen = nil
			else
				setSizePreset(State.currentPreset or "Normal")
			end
		end
		rememberWindowGeometry()
	end)
	return Flags.Fullscreen
end

setSidebarCollapsed = function(on)
	if on == nil then on = not Flags.SidebarCollapsed end
	on = on and true or false
	setFlag("SidebarCollapsed", on)
	pcall(function()
		local motion = Anim.Sidebar or Anim.Smooth
		local w = on and SIDEBAR_COLLAPSED_W or SIDEBAR_W
		tween(sidebar, motion, { Size = UDim2.new(0, w, 1, -12) })
		local cp = contentPanelRef or body:FindFirstChild("ContentPanel")
		if cp then
			local pad = w + 16
			tween(cp, motion, {
				Size = UDim2.new(1, -pad, 1, -12),
				Position = UDim2.fromOffset(pad, 8),
			})
		end

		-- Nav chrome
		if navLabel then
			if on then
				tween(navLabel, Anim.Fast, { TextTransparency = 1 })
				task.delay(0.12, function()
					if Flags.SidebarCollapsed then
						navLabel.Visible = false
						navLabel.Size = UDim2.new(1, 0, 0, 0)
					end
				end)
			else
				navLabel.Visible = true
				navLabel.Size = UDim2.new(1, -8, 0, 18)
				navLabel.TextTransparency = 1
				tween(navLabel, motion, { TextTransparency = 0 })
			end
		end
		if tabIndicator then
			tabIndicator.Visible = not on
		end

		-- Profile: icon-only when collapsed
		local function fadeLabel(lbl, hide)
			if not lbl then return end
			if hide then
				tween(lbl, Anim.Fast, { TextTransparency = 1 })
				task.delay(0.12, function()
					if Flags.SidebarCollapsed then lbl.Visible = false end
				end)
			else
				lbl.Visible = true
				lbl.TextTransparency = 1
				tween(lbl, motion, { TextTransparency = 0 })
			end
		end
		fadeLabel(displayNameLabel, on)
		fadeLabel(userNameLabel, on)
		fadeLabel(hintLabel, on)

		if userCard then
			userCard.ClipsDescendants = true
			if on then
				tween(userCard, motion, {
					Size = UDim2.new(1, -10, 0, 48),
					Position = UDim2.new(0, 5, 1, -56),
					BackgroundTransparency = 0.12,
				})
			else
				tween(userCard, motion, {
					Size = UDim2.new(1, -16, 0, 62),
					Position = UDim2.new(0, 8, 1, -70),
					BackgroundTransparency = 0,
				})
			end
		end
		if avatarGlow then
			avatarGlow.Visible = not on
		end
		if avatar then
			if on then
				avatar.AnchorPoint = Vector2.new(0.5, 0.5)
				tween(avatar, motion, {
					Position = UDim2.new(0.5, 0, 0.5, 0),
					Size = UDim2.fromOffset(32, 32),
				})
			else
				avatar.AnchorPoint = Vector2.new(0, 0.5)
				tween(avatar, motion, {
					Position = UDim2.new(0, 10, 0.5, 0),
					Size = UDim2.fromOffset(36, 36),
				})
			end
		end
		if onlineDot then
			if on then
				onlineDot.AnchorPoint = Vector2.new(0.5, 0.5)
				tween(onlineDot, motion, { Position = UDim2.new(0.5, 10, 0.5, 10) })
			else
				onlineDot.AnchorPoint = Vector2.new(0, 0)
				tween(onlineDot, motion, { Position = UDim2.fromOffset(36, 40) })
			end
		end

		local pad = tabHolder and tabHolder:FindFirstChildOfClass("UIPadding")
		if pad then
			pad.PaddingLeft = UDim.new(0, on and 4 or 8)
			pad.PaddingRight = UDim.new(0, on and 4 or 8)
			pad.PaddingTop = UDim.new(0, on and 8 or 10)
		end

		for i, t in ipairs(tabs) do
			local delay = (i - 1) * 0.02
			task.delay(delay, function()
				if not t or not t.Button then return end
				fadeLabel(t.Label, on)
				fadeLabel(t.SubLabel, on)
				if t.BadgeLabel then
					if on then
						t.BadgeLabel.Visible = false
					else
						t.BadgeLabel.Visible = t.BadgeLabel.Text ~= "" and t.BadgeLabel.Text ~= nil
					end
				end
				if t.FavMark then t.FavMark.Visible = false end
				tween(t.Button, motion, {
					Size = on and UDim2.new(1, 0, 0, 42) or UDim2.new(1, 0, 0, 48),
				})
				if t.IconBg then
					if on then
						t.IconBg.AnchorPoint = Vector2.new(0.5, 0.5)
						tween(t.IconBg, motion, {
							Position = UDim2.new(0.5, 0, 0.5, 0),
							Size = UDim2.fromOffset(30, 30),
						})
					else
						t.IconBg.AnchorPoint = Vector2.new(0, 0)
						tween(t.IconBg, motion, {
							Position = UDim2.fromOffset(8, 8),
							Size = UDim2.fromOffset(32, 32),
						})
					end
				end
			end)
		end
	end)
	return Flags.SidebarCollapsed
end

-- Hover expand / leave collapse (library feature)
pcall(function()
	sidebar.MouseEnter:Connect(function()
		sidebarCollapseToken += 1
		if Flags.AutoCollapseSidebar then
			setSidebarCollapsed(false)
		end
	end)
	sidebar.MouseLeave:Connect(function()
		sidebarCollapseToken += 1
		local my = sidebarCollapseToken
		task.delay(0.35, function()
			if my ~= sidebarCollapseToken then return end
			if Flags.AutoCollapseSidebar and not Flags.LockLayout then
				setSidebarCollapsed(true)
			end
		end)
	end)
end)

applyWindowOpacity = function(amount)
	amount = math.clamp(tonumber(amount) or 0, 0, 0.85)
	State.windowOpacity = amount
	pcall(function()
		tween(window, Anim.Smooth, { GroupTransparency = amount })
		if windowStroke then
			windowStroke.Transparency = math.clamp(0.15 + amount * 0.4, 0.15, 0.85)
		end
		if windowAccentStroke then
			windowAccentStroke.Transparency = math.clamp(0.55 + amount * 0.3, 0.55, 0.92)
		end
	end)
	return State.windowOpacity
end

-- Wire minimizeBtn to minimizeWindow() where you splice (replace existing click handler).

-- ---- 3) Tab management ----
local function tabIndex(tab)
	for i, t in ipairs(tabs) do
		if t == tab then return i end
	end
	return nil
end

local function refreshTabOrder()
	for i, t in ipairs(tabs) do
		if t.Button then t.Button.LayoutOrder = i + (t.Favorite and 0 or 100) end
	end
	ConfigData.tabs = ConfigData.tabs or { order = {}, favorites = {}, colors = {}, badges = {} }
	ConfigData.tabs.order = {}
	ConfigData.tabs.favorites = {}
	for _, t in ipairs(tabs) do
		table.insert(ConfigData.tabs.order, t.Title)
		if t.Favorite then table.insert(ConfigData.tabs.favorites, t.Title) end
	end
	task.defer(saveConfigFile)
end

closeTab = function(tab)
	if not tab or #tabs <= 1 then return false end
	local idx = tabIndex(tab)
	if not idx then return false end
	local wasActive = (activeTab == tab)
	pcall(function()
		if tab.Button then tab.Button:Destroy() end
		if tab.Page then tab.Page:Destroy() end
	end)
	table.remove(tabs, idx)
	if tab.Floating and State.floatingWindows then
		for i = #State.floatingWindows, 1, -1 do
			if State.floatingWindows[i].tab == tab then
				pcall(function() State.floatingWindows[i].host:Destroy() end)
				table.remove(State.floatingWindows, i)
			end
		end
	end
	refreshTabOrder()
	if wasActive and tabs[1] then
		switchTab(tabs[math.min(idx, #tabs)])
	end
	return true
end

local function moveTab(tab, dir)
	local i = tabIndex(tab)
	if not i then return end
	local j = i + (tonumber(dir) or 0)
	if j < 1 or j > #tabs then return end
	tabs[i], tabs[j] = tabs[j], tabs[i]
	refreshTabOrder()
end

local function toggleFavorite(tab)
	if not tab then return end
	tab.Favorite = not tab.Favorite
	-- No FavMark UI — stars were the yellow corner dots
	pcall(function()
		if tab.Button then
			local star = tab.Button:FindFirstChild("FavMark")
			if star then star:Destroy() end
		end
		tab.FavMark = nil
	end)
	refreshTabOrder()
	return tab.Favorite
end

local function detachTab(tab)
	if not tab or tab.Floating then return end
	pcall(function()
		local host = make("Frame", {
			Name = "Float_" .. tostring(tab.Title),
			Size = UDim2.fromOffset(360, 280),
			Position = UDim2.fromOffset(80 + #State.floatingWindows * 24, 80 + #State.floatingWindows * 24),
			BackgroundColor3 = Theme.Background,
			ZIndex = 80,
		}, { corner(10), stroke(Theme.Accent, 1.5, 0.4) })
		host.Parent = root
		local bar = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = Theme.Layer,
			Text = "  " .. tostring(tab.Title),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			ZIndex = 81,
		}, { corner(10) })
		bar.Parent = host
		local closeF = make("TextButton", {
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(1, -28, 0, 2),
			BackgroundTransparency = 1,
			Text = "X",
			TextColor3 = Theme.SubText,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			ZIndex = 82,
		})
		closeF.Parent = bar
		if tab.Page then
			tab.Page.Parent = host
			tab.Page.Size = UDim2.new(1, -8, 1, -36)
			tab.Page.Position = UDim2.fromOffset(4, 32)
			tab.Page.Visible = true
			tab.Page.GroupTransparency = 0
		end
		if tab.Button then tab.Button.Visible = false end
		tab.Floating = true
		local dragging, d0, p0
		bar.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				d0 = inp.Position
				p0 = host.AbsolutePosition
			end
		end)
		UserInputService.InputChanged:Connect(function(inp)
			if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
				local d = inp.Position - d0
				host.Position = UDim2.fromOffset(p0.X + d.X, p0.Y + d.Y)
			end
		end)
		UserInputService.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
		end)
		closeF.MouseButton1Click:Connect(function()
			tab.Floating = false
			if tab.Page then
				tab.Page.Parent = contentArea
				tab.Page.Size = UDim2.new(1, 0, 1, 0)
				tab.Page.Position = UDim2.fromOffset(0, 0)
				tab.Page.Visible = (activeTab == tab)
			end
			if tab.Button then tab.Button.Visible = true end
			pcall(function() host:Destroy() end)
			for i = #State.floatingWindows, 1, -1 do
				if State.floatingWindows[i].tab == tab then table.remove(State.floatingWindows, i) end
			end
		end)
		table.insert(State.floatingWindows, { tab = tab, host = host })
	end)
end

cycleTab = function(dir)
	if #tabs == 0 then return end
	local i = tabIndex(activeTab) or 1
	i = i + (tonumber(dir) or 1)
	if i < 1 then i = #tabs end
	if i > #tabs then i = 1 end
	switchTab(tabs[i])
	table.insert(State.recentTabs, 1, tabs[i])
	while #State.recentTabs > 12 do table.remove(State.recentTabs) end
end

-- ---- 4) Tab context menu ----
local function showTabContextMenu(tab, x, y)
	pcall(function()
		if State.ctxMenu and State.ctxMenu.Parent then State.ctxMenu:Destroy() end
	end)
	local menu = make("Frame", {
		Name = "TabCtx",
		Size = UDim2.fromOffset(168, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(x or 0, y or 0),
		BackgroundColor3 = Theme.Background,
		ZIndex = 220,
	}, { corner(8), stroke(Theme.Stroke, 1, 0.35) })
	menu.Parent = root
	State.ctxMenu = menu
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = menu
	make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}).Parent = menu
	local items = {
		{ "Close", function() closeTab(tab) end },
		{ "Move Up", function() moveTab(tab, -1) end },
		{ "Move Down", function() moveTab(tab, 1) end },
		{ tab.Favorite and "Unfavorite" or "Favorite", function() toggleFavorite(tab) end },
		{ "Detach", function() detachTab(tab) end },
	}
	for i, it in ipairs(items) do
		local b = make("TextButton", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = Theme.Element,
			BackgroundTransparency = 0.2,
			Text = "  " .. it[1],
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			LayoutOrder = i,
			ZIndex = 221,
		}, { corner(5) })
		b.Parent = menu
		b.MouseEnter:Connect(function()
			tween(b, Anim.Fast, { BackgroundColor3 = Theme.ElementHover, BackgroundTransparency = 0 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, Anim.Fast, { BackgroundColor3 = Theme.Element, BackgroundTransparency = 0.2 })
		end)
		b.MouseButton1Click:Connect(function()
			pcall(it[2])
			pcall(function() menu:Destroy() end)
			if State.ctxMenu == menu then State.ctxMenu = nil end
		end)
	end
	task.delay(0.05, function()
		local c
		c = UserInputService.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				task.defer(function()
					if State.ctxMenu == menu then
						pcall(function() menu:Destroy() end)
						State.ctxMenu = nil
					end
				end)
				if c then c:Disconnect() end
			end
		end)
	end)
	return menu
end

-- ---- 5) enhanceTab + wrap createTab ----
-- NOTE: bindTabAPI and createTab should call enhanceTab(tab) after building the tab.
enhanceTab = function(tab)
	if not tab or tab._v6Enhanced then return tab end
	tab._v6Enhanced = true
	local btn = tab.Button
	if not btn then return tab end

	-- Favorite stars removed (looked like yellow dots on tabs)
	tab.FavMark = nil
	pcall(function()
		local oldFav = btn:FindFirstChild("FavMark")
		if oldFav then oldFav:Destroy() end
	end)

	pcall(function()
		local badge = make("TextLabel", {
			Name = "TabBadge",
			BackgroundColor3 = Theme.Error,
			Size = UDim2.fromOffset(28, 15),
			Position = UDim2.new(1, -6, 0, 7),
			AnchorPoint = Vector2.new(1, 0),
			Font = Enum.Font.GothamBold,
			Text = "",
			TextSize = 9,
			TextColor3 = Color3.new(1, 1, 1),
			Visible = false,
			ZIndex = 6,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, {
			corner(4),
			make("UIPadding", {
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
			}),
		})
		badge.Parent = btn
		tab.BadgeLabel = badge
	end)

	function tab:SetBadge(text)
		pcall(function()
			local b = self.BadgeLabel
			if not b then return end
			if text == nil or text == false or text == "" then
				b.Visible = false
				b.Text = ""
			else
				b.Text = tostring(text)
				local w = math.clamp(math.ceil(#b.Text * 6.2) + 12, 22, 56)
				b.Size = UDim2.fromOffset(w, 15)
				b.Position = UDim2.new(1, -6, 0, 7)
				b.AnchorPoint = Vector2.new(1, 0)
				b.Visible = not Flags.SidebarCollapsed
			end
			ConfigData.tabs = ConfigData.tabs or {}
			ConfigData.tabs.badges = ConfigData.tabs.badges or {}
			ConfigData.tabs.badges[self.Title] = text
		end)
	end

	function tab:Favorite(on)
		if on == nil then return toggleFavorite(self) end
		self.Favorite = not on
		return toggleFavorite(self)
	end

	-- drag reorder
	pcall(function()
		local dragging = false
		btn.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				local startY = inp.Position.Y
				local startIdx = tabIndex(tab)
				local conn
				conn = UserInputService.InputChanged:Connect(function(m)
					if not dragging or m.UserInputType ~= Enum.UserInputType.MouseMovement then return end
					local dy = m.Position.Y - startY
					local step = math.floor(dy / 40)
					local target = math.clamp((startIdx or 1) + step, 1, #tabs)
					local cur = tabIndex(tab)
					if cur and target ~= cur then
						table.remove(tabs, cur)
						table.insert(tabs, target, tab)
						refreshTabOrder()
					end
				end)
				local endConn
				endConn = UserInputService.InputEnded:Connect(function(m)
					if m.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = false
						if conn then conn:Disconnect() end
						if endConn then endConn:Disconnect() end
					end
				end)
			elseif inp.UserInputType == Enum.UserInputType.MouseButton2 then
				local ap = btn.AbsolutePosition
				showTabContextMenu(tab, ap.X + 40, ap.Y + 10)
			elseif inp.UserInputType == Enum.UserInputType.MouseButton3 then
				closeTab(tab)
			end
		end)
	end)

	return tab
end

for _, t in ipairs(tabs) do
	pcall(enhanceTab, t)
end
do
	local _ct = createTab
	createTab = function(...)
		local t = _ct(...)
		pcall(enhanceTab, t)
		return t
	end
end

-- ---- 6) Ctrl+Tab / Ctrl+Shift+Tab ----
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Tab then
		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if not ctrl then return end
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		cycleTab(shift and -1 or 1)
	end
end)

-- ---- 7) Notification upgrades ----
local notifMode = "normal" -- normal | silent | dnd | compact

local function pushNotifHistory(entry)
	pcall(function()
		table.insert(State.notifHistory, 1, {
			title = entry.title or entry.Title or "Notice",
			body = entry.body or entry.Body or entry.Content or "",
			kind = entry.kind or entry.Type or "info",
			t = os.clock(),
			pinned = entry.pinned,
		})
		while #State.notifHistory > 80 do table.remove(State.notifHistory) end
	end)
end

SetNotificationMode = function(mode)
	mode = tostring(mode or "normal"):lower()
	if mode ~= "silent" and mode ~= "dnd" and mode ~= "compact" and mode ~= "normal" then
		mode = "normal"
	end
	notifMode = mode
	setFlag("SilentNotifications", mode == "silent")
	setFlag("DoNotDisturb", mode == "dnd")
	setFlag("CompactNotifications", mode == "compact")
	return notifMode
end

do
	local _notify = notify
	notify = function(title, body, kind, duration, opts)
		opts = type(opts) == "table" and opts or {}
		local mode = opts.Mode or notifMode
		if opts.Silent or Flags.SilentNotifications or mode == "silent" then
			pushNotifHistory({ title = title, body = body, kind = kind })
			return nil
		end
		if opts.Dnd or Flags.DoNotDisturb or mode == "dnd" then
			local h = tonumber(os.date("%H"))
			local a, b = Flags.DndStartHour or -1, Flags.DndEndHour or -1
			local inWindow = true
			if a >= 0 and b >= 0 then
				if a <= b then inWindow = (h >= a and h < b) else inWindow = (h >= a or h < b) end
			end
			if inWindow then
				pushNotifHistory({ title = title, body = body, kind = kind })
				table.insert(State.notifQueue, { title = title, body = body, kind = kind, duration = duration, opts = opts })
				return nil
			end
		end
		if opts.Compact or Flags.CompactNotifications or mode == "compact" then
			duration = math.min(tonumber(duration) or 2.2, 2.2)
			body = ""
		end
		if opts.Sound ~= false then
			pcall(playUiSound, opts.Sound == true and "notif" or (kind == "error" and "error" or "notif"))
		end
		if opts.ProgressId or opts.Progress then
			local id = tostring(opts.ProgressId or opts.Id or title)
			local existing = State.progressNotifs[id]
			if existing and existing.alive then
				pcall(function()
					if existing.toast then
						for _, ch in ipairs(existing.toast:GetDescendants()) do
							if ch:IsA("TextLabel") and ch.TextSize == 14 then
								ch.Text = tostring(title)
							end
						end
					end
					existing.remaining = tonumber(duration) or existing.remaining
				end)
				pushNotifHistory({ title = title, body = body, kind = kind })
				return existing
			end
			local entry = _notify(title, body, kind, duration, opts)
			if entry then
				State.progressNotifs[id] = entry
				entry.ProgressId = id
			end
			pushNotifHistory({ title = title, body = body, kind = kind })
			return entry
		end
		if opts.Reply and type(opts.Reply) == "function" then
			opts.Action = opts.Action or { Text = "Reply", Callback = opts.Reply }
		end
		if opts.Pinned then
			duration = math.max(tonumber(duration) or 30, 30)
		end
		local entry = _notify(title, body, kind, duration, opts)
		pushNotifHistory({ title = title, body = body, kind = kind, pinned = opts.Pinned })
		return entry
	end
end

NotifyProgress = function(id, title, body, pct, kind)
	id = tostring(id or title)
	pct = math.clamp(tonumber(pct) or 0, 0, 100)
	local opts = { ProgressId = id, Progress = pct }
	local entry = notify(title or "Progress", (body or "") .. "  " .. math.floor(pct) .. "%", kind or "info", 8, opts)
	if entry and pct >= 100 then
		task.delay(0.6, function()
			pcall(function()
				if entry.dismiss then entry.dismiss() end
				State.progressNotifs[id] = nil
			end)
		end)
	end
	return entry
end

local function createBellAndHistory()
	if State.historyPanel and State.historyPanel.Parent then return State.historyPanel end
	local bell = make("TextButton", {
		Name = "NotifBell",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -96, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 0.35,
		Text = "i",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		ZIndex = 20,
	}, { corner(7), stroke(Theme.Stroke, 1, 0.5) })
	bell.Parent = titleBar
	local count = make("TextLabel", {
		Name = "BellCount",
		BackgroundColor3 = Theme.Error,
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(1, -8, 0, -2),
		Font = Enum.Font.GothamBold,
		Text = "0",
		TextSize = 9,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		ZIndex = 21,
	}, { corner(7) })
	count.Parent = bell
	local panel = make("Frame", {
		Name = "NotifHistory",
		Size = UDim2.fromOffset(280, 300),
		Position = UDim2.new(1, -290, 0, MINI_H + 4),
		BackgroundColor3 = Theme.Background,
		Visible = false,
		ZIndex = 190,
	}, { corner(10), stroke(Theme.Stroke, 1, 0.35) })
	panel.Parent = root
	State.historyPanel = panel
	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -36),
		Position = UDim2.fromOffset(4, 32),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 191,
	})
	scroll.Parent = panel
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = scroll
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.fromOffset(10, 6),
		Font = Enum.Font.GothamBold,
		Text = "Notifications",
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 192,
	}).Parent = panel

	local function rebuild()
		for _, ch in ipairs(scroll:GetChildren()) do
			if ch:IsA("Frame") then ch:Destroy() end
		end
		for i, e in ipairs(State.notifHistory) do
			local row = make("Frame", {
				Size = UDim2.new(1, -4, 0, 44),
				BackgroundColor3 = Theme.Element,
				LayoutOrder = i,
				ZIndex = 192,
			}, { corner(6) })
			row.Parent = scroll
			make("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -10, 0, 16),
				Position = UDim2.fromOffset(8, 4),
				Font = Enum.Font.GothamMedium,
				Text = tostring(e.title),
				TextSize = 12,
				TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 193,
			}).Parent = row
			make("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -10, 0, 16),
				Position = UDim2.fromOffset(8, 22),
				Font = Enum.Font.Gotham,
				Text = tostring(e.body),
				TextSize = 11,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 193,
			}).Parent = row
		end
		count.Text = tostring(math.min(#State.notifHistory, 99))
		count.Visible = #State.notifHistory > 0
	end

	bell.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible then rebuild() end
	end)
	return panel
end
pcall(createBellAndHistory)

-- ---- 8) New components ----
local function createRadioGroup(tab, title, options, default, callback)
	options = options or {}
	local selected = default or options[1]
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 36 + #options * 28),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	local cs, sc = styleCard(holder)
	hoverCard(holder, cs, sc)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(14, 6),
		Font = State.uiFont,
		Text = tostring(title or "Option"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local dots = {}
	local api
	local function render()
		for name, dot in pairs(dots) do
			tween(dot, Anim.Fast, {
				BackgroundColor3 = (name == selected) and Theme.Accent or Theme.Stroke,
				BackgroundTransparency = (name == selected) and 0 or 0.4,
			})
		end
	end
	for i, opt in ipairs(options) do
		local row = make("TextButton", {
			Size = UDim2.new(1, -20, 0, 26),
			Position = UDim2.fromOffset(10, 28 + (i - 1) * 28),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
		})
		row.Parent = holder
		local dot = make("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(4, 6),
			BackgroundColor3 = Theme.Stroke,
		}, { corner(7), stroke(Theme.Stroke, 1, 0.3) })
		dot.Parent = row
		dots[opt] = dot
		registerAccent(dot, "BackgroundColor3")
		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -28, 1, 0),
			Position = UDim2.fromOffset(26, 0),
			Font = State.uiFont,
			Text = tostring(opt),
			TextSize = 12,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = row
		row.MouseButton1Click:Connect(function()
			selected = opt
			render()
			safeCall(callback, selected)
		end)
	end
	api = {
		Set = function(v, silent)
			selected = v
			render()
			if not silent then safeCall(callback, selected) end
		end,
		Get = function() return selected end,
	}
	render()
	return api
end

local function createCircularProgress(tab, title, value)
	value = math.clamp(tonumber(value) or 0, 0, 100)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -80, 0, 20),
		Position = UDim2.fromOffset(14, 10),
		Font = State.uiFont,
		Text = tostring(title or "Progress"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local ring = make("Frame", {
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -62, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Layer,
	}, { corner(24), stroke(Theme.Accent, 3, 0.2) })
	ring.Parent = holder
	registerAccent(ring:FindFirstChildOfClass("UIStroke"), "Color")
	local pct = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = math.floor(value) .. "%",
		TextSize = 11,
		TextColor3 = Theme.Text,
	})
	pct.Parent = ring
	local bar = make("Frame", {
		Size = UDim2.new(0, 0, 0, 4),
		Position = UDim2.fromOffset(14, 40),
		BackgroundColor3 = Theme.Accent,
	}, { corner(2) })
	bar.Parent = holder
	registerAccent(bar, "BackgroundColor3")
	local maxW = 200
	local function set(v)
		value = math.clamp(tonumber(v) or 0, 0, 100)
		pct.Text = math.floor(value) .. "%"
		tween(bar, Anim.Smooth, { Size = UDim2.fromOffset(math.floor(maxW * value / 100), 4) })
		local st = ring:FindFirstChildOfClass("UIStroke")
		if st then tween(st, Anim.Smooth, { Transparency = 0.7 - value / 200 }) end
	end
	set(value)
	return { Set = set, Get = function() return value end }
end

local function createTagsInput(tab, title, defaultTags, callback)
	local tags = {}
	for _, t in ipairs(defaultTags or {}) do table.insert(tags, tostring(t)) end
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = State.uiFont,
		Text = tostring(title or "Tags"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local row = make("Frame", {
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 28),
		BackgroundTransparency = 1,
	})
	row.Parent = holder
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}).Parent = row
	local box = make("TextBox", {
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 50),
		BackgroundColor3 = Theme.Layer,
		Text = "",
		PlaceholderText = "Add tag + Enter",
		Font = State.uiFont,
		TextSize = 11,
		TextColor3 = Theme.Text,
		ClearTextOnFocus = false,
	}, { corner(5) })
	box.Parent = holder
	local function rebuild()
		for _, ch in ipairs(row:GetChildren()) do
			if ch:IsA("TextButton") then ch:Destroy() end
		end
		for i, t in ipairs(tags) do
			local chip = make("TextButton", {
				Size = UDim2.fromOffset(math.clamp(#t * 7 + 18, 40, 120), 20),
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 0.75,
				Text = t .. " x",
				Font = Enum.Font.Gotham,
				TextSize = 10,
				TextColor3 = Theme.Accent,
				AutoButtonColor = false,
				LayoutOrder = i,
			}, { corner(5) })
			chip.Parent = row
			registerAccent(chip, "BackgroundColor3")
			chip.MouseButton1Click:Connect(function()
				table.remove(tags, i)
				rebuild()
				safeCall(callback, tags)
			end)
		end
	end
	box.FocusLost:Connect(function(enter)
		if not enter then return end
		local v = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
		if v ~= "" then
			table.insert(tags, v)
			box.Text = ""
			rebuild()
			safeCall(callback, tags)
		end
	end)
	rebuild()
	return {
		Get = function() return tags end,
		Set = function(list)
			tags = {}
			for _, t in ipairs(list or {}) do table.insert(tags, tostring(t)) end
			rebuild()
		end,
	}
end

local function createRichText(tab, title, markdown)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Rich Text"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local body = tostring(markdown or "")
	body = body:gsub("%*%*(.-)%*%*", "%1"):gsub("%*(.-)%*", "%1"):gsub("`(.-)`", "%1")
	local lbl = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 0, 58),
		Position = UDim2.fromOffset(14, 28),
		Font = State.uiFont,
		Text = body,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	})
	lbl.Parent = holder
	return {
		Set = function(t)
			lbl.Text = tostring(t or "")
		end,
		Get = function() return lbl.Text end,
	}
end

local function createTable(tab, title, columns, rows)
	columns = columns or { "A", "B" }
	rows = rows or {}
	local rowH = 22
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 40 + (#rows + 1) * rowH),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Table"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local colW = 1 / math.max(1, #columns)
	for i, c in ipairs(columns) do
		make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(colW, -4, 0, rowH),
			Position = UDim2.new((i - 1) * colW, 10, 0, 28),
			Font = Enum.Font.GothamBold,
			Text = tostring(c),
			TextSize = 11,
			TextColor3 = Theme.Accent,
			TextXAlignment = Enum.TextXAlignment.Left,
		}).Parent = holder
	end
	for r, row in ipairs(rows) do
		for i, cell in ipairs(row) do
			make("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(colW, -4, 0, rowH),
				Position = UDim2.new((i - 1) * colW, 10, 0, 28 + r * rowH),
				Font = State.uiFont,
				Text = tostring(cell),
				TextSize = 11,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}).Parent = holder
		end
	end
	return holder
end

local function createTreeView(tab, title, nodes, callback)
	nodes = nodes or {}
	local expanded = {}
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Tree"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -28),
		Position = UDim2.fromOffset(6, 26),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	scroll.Parent = holder
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = scroll

	local function addNode(node, depth, order)
		depth = depth or 0
		local hasKids = type(node.Children) == "table" and #node.Children > 0
		local open = expanded[node] == true
		local row = make("TextButton", {
			Size = UDim2.new(1, -4, 0, 22),
			BackgroundTransparency = 1,
			Text = string.rep("  ", depth) .. (hasKids and (open and "[-] " or "[+] ") or "  ") .. tostring(node.Name or node.Title or "?"),
			Font = State.uiFont,
			TextSize = 12,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			LayoutOrder = order,
		})
		row.Parent = scroll
		row.MouseButton1Click:Connect(function()
			if hasKids then
				expanded[node] = not open
				for _, ch in ipairs(scroll:GetChildren()) do
					if ch:IsA("TextButton") then ch:Destroy() end
				end
				local o = 0
				local function walk(list, d)
					for _, n in ipairs(list) do
						o += 1
						addNode(n, d, o)
						if expanded[n] and n.Children then walk(n.Children, d + 1) end
					end
				end
				walk(nodes, 0)
			end
			safeCall(callback, node)
		end)
	end
	local o = 0
	for _, n in ipairs(nodes) do
		o += 1
		addNode(n, 0, o)
	end
	return holder
end

local function createGraph(tab, title, points)
	points = points or { 10, 40, 25, 60, 45, 80, 55 }
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 100),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
		ClipsDescendants = true,
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Graph"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local plot = make("Frame", {
		Size = UDim2.new(1, -24, 0, 60),
		Position = UDim2.fromOffset(12, 30),
		BackgroundTransparency = 1,
	})
	plot.Parent = holder
	local bars = {}
	local function render(pts)
		points = pts or points
		for _, b in ipairs(bars) do pcall(function() b:Destroy() end) end
		bars = {}
		local n = #points
		if n == 0 then return end
		local maxV = 1
		for _, v in ipairs(points) do maxV = math.max(maxV, tonumber(v) or 0) end
		local bw = math.max(4, math.floor((plot.AbsoluteSize.X > 0 and plot.AbsoluteSize.X or 280) / n) - 3)
		for i, v in ipairs(points) do
			local h = math.floor(56 * (tonumber(v) or 0) / maxV)
			local bar = make("Frame", {
				Size = UDim2.fromOffset(bw, h),
				Position = UDim2.new(0, (i - 1) * (bw + 3), 1, -h),
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = 0.15,
			}, { corner(3) })
			bar.Parent = plot
			registerAccent(bar, "BackgroundColor3")
			table.insert(bars, bar)
		end
	end
	task.defer(function() render(points) end)
	return {
		Set = render,
		Get = function() return points end,
	}
end

local function createDateTimePicker(tab, title, callback)
	local t = os.date("*t")
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = State.uiFont,
		Text = tostring(title or "Date / Time"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local box = make("TextBox", {
		Size = UDim2.new(1, -28, 0, 24),
		Position = UDim2.fromOffset(14, 30),
		BackgroundColor3 = Theme.Layer,
		Font = State.uiFont,
		TextSize = 12,
		TextColor3 = Theme.Text,
		Text = string.format("%04d-%02d-%02d %02d:%02d", t.year, t.month, t.day, t.hour, t.min),
		ClearTextOnFocus = false,
	}, { corner(5) })
	box.Parent = holder
	box.FocusLost:Connect(function()
		safeCall(callback, box.Text)
	end)
	return {
		Get = function() return box.Text end,
		Set = function(s) box.Text = tostring(s or "") end,
	}
end

local function createImageViewer(tab, title, imageId)
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 140),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Image"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local img = make("ImageLabel", {
		Size = UDim2.new(1, -28, 0, 100),
		Position = UDim2.fromOffset(14, 28),
		BackgroundColor3 = Theme.Layer,
		Image = tostring(imageId or ""),
		ScaleType = Enum.ScaleType.Fit,
	}, { corner(6) })
	img.Parent = holder
	return {
		Set = function(id) img.Image = tostring(id or "") end,
		Get = function() return img.Image end,
	}
end

local function createFileBrowser(tab, title, files, callback)
	files = files or { "config.json", "theme.json", "readme.txt" }
	local holder = make("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundColor3 = Theme.Element,
		LayoutOrder = nextOrder(),
	}, { corner(8) })
	holder.Parent = tab.Container
	styleCard(holder)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(14, 6),
		Font = Enum.Font.GothamBold,
		Text = tostring(title or "Files"),
		TextSize = 13,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = holder
	local scroll = make("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -28),
		Position = UDim2.fromOffset(6, 26),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
	})
	scroll.Parent = holder
	make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }).Parent = scroll
	local selected
	local function rebuild(list)
		files = list or files
		for _, ch in ipairs(scroll:GetChildren()) do
			if ch:IsA("TextButton") then ch:Destroy() end
		end
		for i, f in ipairs(files) do
			local b = make("TextButton", {
				Size = UDim2.new(1, -4, 0, 22),
				BackgroundColor3 = Theme.Layer,
				BackgroundTransparency = 0.3,
				Text = "  " .. tostring(f),
				Font = State.uiFont,
				TextSize = 12,
				TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				LayoutOrder = i,
			}, { corner(4) })
			b.Parent = scroll
			b.MouseButton1Click:Connect(function()
				selected = f
				safeCall(callback, f)
			end)
		end
	end
	rebuild(files)
	return {
		Set = rebuild,
		Get = function() return selected end,
		List = function() return files end,
	}
end

-- ---- 9) Theme helpers ----
local function applyLightMode(on)
	if on == nil then on = not Flags.LightMode end
	on = on and true or false
	setFlag("LightMode", on)
	pcall(function()
		if on then
			Theme.Background = Color3.fromRGB(242, 242, 245)
			Theme.Sidebar = Color3.fromRGB(235, 235, 240)
			Theme.Layer = Color3.fromRGB(250, 250, 252)
			Theme.Element = Color3.fromRGB(228, 228, 234)
			Theme.ElementHover = Color3.fromRGB(214, 214, 222)
			Theme.Text = Color3.fromRGB(24, 24, 28)
			Theme.SubText = Color3.fromRGB(80, 80, 90)
			Theme.Stroke = Color3.fromRGB(180, 180, 190)
		else
			for k, v in pairs(DarkThemeBackup) do
				Theme[k] = v
			end
		end
		window.BackgroundColor3 = Theme.Background
		sidebar.BackgroundColor3 = Theme.Sidebar
		titleBar.BackgroundColor3 = Theme.Layer
		local cp = contentPanelRef or body:FindFirstChild("ContentPanel")
		if cp then cp.BackgroundColor3 = Theme.Layer end
	end)
	return Flags.LightMode
end

local function exportTheme()
	local t = {}
	for k, v in pairs(Theme) do
		if typeof(v) == "Color3" then
			t[k] = colorToHex(v)
		end
	end
	local json = encodeJson(t)
	return json and b64encode(json) or nil
end

local function importTheme(payload)
	local ok = pcall(function()
		local raw = payload
		if type(payload) == "string" and not payload:find("{") then
			raw = b64decode(payload)
		end
		local data = type(raw) == "table" and raw or decodeJson(raw)
		if not data then return end
		for k, v in pairs(data) do
			local c = typeof(v) == "Color3" and v or hexToColor(v)
			if c and Theme[k] ~= nil then Theme[k] = c end
		end
		if Theme.Accent then setAccent(Theme.Accent) end
		window.BackgroundColor3 = Theme.Background
		sidebar.BackgroundColor3 = Theme.Sidebar
	end)
	return ok
end

local function setUiScale(scale)
	scale = math.clamp(tonumber(scale) or 1, 0.75, 1.5)
	State.uiScaleValue = scale
	setFlag("UiScale", scale)
	pcall(function()
		if windowScale then
			tween(windowScale, Anim.Smooth, { Scale = scale })
		end
	end)
	return scale
end

local function randomTheme()
	local c = Color3.fromHSV(math.random(), 0.25 + math.random() * 0.25, 0.75 + math.random() * 0.2)
	setAccent(c)
	return c
end

local function dailyAccent()
	local day = tonumber(os.date("%j")) or 1
	local hue = (day * 0.6180339887) % 1
	local c = Color3.fromHSV(hue, 0.28, 0.82)
	setAccent(c)
	return c
end

-- ---- 10) Dev tools ----
local inspectorGui = nil
local function toggleInspector(on)
	if on == nil then on = not State.inspectorEnabled end
	State.inspectorEnabled = on and true or false
	pcall(function()
		if inspectorGui then inspectorGui:Destroy() inspectorGui = nil end
		if not State.inspectorEnabled then return end
		inspectorGui = make("Frame", {
			Name = "Inspector",
			Size = UDim2.fromOffset(220, 120),
			Position = UDim2.fromOffset(8, MINI_H + 8),
			BackgroundColor3 = Theme.Background,
			ZIndex = 240,
		}, { corner(8), stroke(Theme.Warning, 1, 0.4) })
		inspectorGui.Parent = root
		local lbl = make("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 1, -12),
			Position = UDim2.fromOffset(6, 6),
			Font = Enum.Font.Code,
			Text = "Inspector",
			TextSize = 11,
			TextColor3 = Theme.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			ZIndex = 241,
		})
		lbl.Parent = inspectorGui
		task.spawn(function()
			while State.inspectorEnabled and inspectorGui and inspectorGui.Parent do
				local mx = UserInputService:GetMouseLocation()
				lbl.Text = string.format(
					"INSPECTOR\npos %d,%d\nsize %dx%d\ntabs %d\nver %s",
					math.floor(root.AbsolutePosition.X),
					math.floor(root.AbsolutePosition.Y),
					WIN_W,
					WIN_H,
					#tabs,
					tostring(LIBRARY_VERSION)
				)
				task.wait(0.25)
			end
		end)
	end)
	return State.inspectorEnabled
end

local function appendConsole(msg, level)
	msg = tostring(msg or "")
	level = tostring(level or "info")
	table.insert(State.consoleLog, 1, { t = os.clock(), level = level, msg = msg })
	while #State.consoleLog > 200 do table.remove(State.consoleLog) end
	return State.consoleLog[1]
end

local function hotReload()
	appendConsole("hotReload stub — reload FluentGui.lua from your executor", "warn")
	pcall(function()
		notify("Hot Reload", "Stub only. Re-run loadstring to reload.", "warning", 3)
	end)
	return false
end

-- ---- 11) Easter egg: typed "zenless" ----
do
	local buf = ""
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local name = input.KeyCode.Name
		if #name == 1 then
			buf = (buf .. name:lower()):sub(-7)
			if buf == "zenless" then
				buf = ""
				pcall(function()
					setAccent(Color3.fromRGB(255, 210, 80))
					notify("ZENLESS", "You found the easter egg.", "success", 3.5)
					if type(celebrateOpen) == "function" then
						celebrateOpen(window)
					end
				end)
			end
		end
	end)
end

-- ---- 12) Public API attach ----
applyV6PublicAPI = function(Zenless)
	if type(Zenless) ~= "table" then return Zenless end
	Zenless.Version = LIBRARY_VERSION or Zenless.Version or "6.0"
	Zenless.Flags = Flags
	Zenless.SetFlag = function(_, name, value) return setFlag(name, value) end
	Zenless.GetFlag = function(_, name) return Flags[name] end
	Zenless.SaveConfig = function() return saveConfigFile() end
	Zenless.LoadConfig = function() return loadConfigFile() end
	Zenless.ExportConfig = function()
		local s = encodeJson(ConfigData)
		return s and b64encode(s) or nil
	end
	Zenless.ImportConfig = function(_, b64)
		local raw = b64decode(tostring(b64 or ""))
		local data = decodeJson(raw)
		if type(data) == "table" then
			ConfigData = data
			saveConfigFile()
			return true
		end
		return false
	end
	Zenless.GetNotificationHistory = function() return State.notifHistory end
	Zenless.ShowConfirm = showConfirmModal
	Zenless.Confirm = showConfirmModal
	Zenless.NotifyProgress = NotifyProgress
	Zenless.SetNotificationMode = SetNotificationMode
	Zenless.PushNotifHistory = pushNotifHistory
	Zenless.CreateBellAndHistory = createBellAndHistory
	Zenless.ApplyLightMode = applyLightMode
	Zenless.ExportTheme = exportTheme
	Zenless.ImportTheme = importTheme
	Zenless.SetUiScale = setUiScale
	Zenless.RandomTheme = randomTheme
	Zenless.DailyAccent = dailyAccent
	Zenless.ToggleInspector = toggleInspector
	Zenless.AppendConsole = appendConsole
	Zenless.HotReload = hotReload
	Zenless.EnhanceTab = enhanceTab
	Zenless.CloseTab = closeTab
	Zenless.MoveTab = moveTab
	Zenless.CycleTab = cycleTab
	Zenless.DetachTab = detachTab
	Zenless.ToggleFavorite = toggleFavorite
	Zenless.ShowTabContextMenu = showTabContextMenu
	Zenless.Undo = function()
		local e = table.remove(State.undoStack)
		if e then table.insert(State.redoStack, e); return e end
	end
	Zenless.Redo = function()
		local e = table.remove(State.redoStack)
		if e then table.insert(State.undoStack, e); return e end
	end

	-- component factories (tab, ...)
	Zenless.CreateRadioGroup = createRadioGroup
	Zenless.CreateCircularProgress = createCircularProgress
	Zenless.CreateTagsInput = createTagsInput
	Zenless.CreateRichText = createRichText
	Zenless.CreateTable = createTable
	Zenless.CreateTreeView = createTreeView
	Zenless.CreateGraph = createGraph
	Zenless.CreateDateTimePicker = createDateTimePicker
	Zenless.CreateImageViewer = createImageViewer
	Zenless.CreateFileBrowser = createFileBrowser

	Zenless.Window = Zenless.Window or {}
	local W = Zenless.Window
	W.Minimize = function(state)
		if state == nil then return minimizeWindow() end
		if (state and true or false) ~= minimized then minimizeWindow() end
		return minimized
	end
	W.SetPinned = setWindowPinned
	W.Pin = setWindowPinned
	W.SetSizePreset = setSizePreset
	W.SetFullscreen = setFullscreen
	W.SetSidebarCollapsed = setSidebarCollapsed
	W.SetAutoCollapseSidebar = function(on)
		if on == nil then on = not Flags.AutoCollapseSidebar end
		setFlag("AutoCollapseSidebar", on and true or false)
		if Flags.AutoCollapseSidebar then
			setSidebarCollapsed(true)
		else
			setSidebarCollapsed(false)
		end
		return Flags.AutoCollapseSidebar
	end
	W.ApplyOpacity = applyWindowOpacity
	W.SetOpacity = applyWindowOpacity
	W.SetUnfocusedOpacity = function(v)
		setFlag("UnfocusedOpacity", math.clamp(tonumber(v) or 0, 0, 0.9))
	end
	W.ShowConfirm = showConfirmModal
	W.ToggleInspector = toggleInspector
	W.SetUiScale = setUiScale
	W.ExportTheme = exportTheme
	W.ImportTheme = importTheme
	W.ApplyLightMode = applyLightMode
	W.RandomTheme = randomTheme
	W.DailyAccent = dailyAccent

	-- extend bindTabAPI-style methods on future tabs via enhance wrap
	pcall(function()
		local _bind = bindTabAPI
		if type(_bind) == "function" then
			bindTabAPI = function(tab)
				_bind(tab)
				enhanceTab(tab)
				function tab:AddRadioGroup(opts)
					opts = opts or {}
					return createRadioGroup(self, opts.Title or "Radio", opts.Values or opts.Options or {}, opts.Default, opts.Callback)
				end
				function tab:AddCircularProgress(opts)
					opts = opts or {}
					return createCircularProgress(self, opts.Title or "Progress", opts.Default or opts.Value or 0)
				end
				function tab:AddTagsInput(opts)
					opts = opts or {}
					return createTagsInput(self, opts.Title or "Tags", opts.Default or opts.Tags or {}, opts.Callback)
				end
				function tab:AddRichText(opts)
					opts = opts or {}
					return createRichText(self, opts.Title or "Text", opts.Content or opts.Body or opts.Text)
				end
				function tab:AddTable(opts)
					opts = opts or {}
					return createTable(self, opts.Title or "Table", opts.Columns or opts.Headers, opts.Rows or opts.Data)
				end
				function tab:AddTreeView(opts)
					opts = opts or {}
					return createTreeView(self, opts.Title or "Tree", opts.Nodes or opts.Items or {}, opts.Callback)
				end
				function tab:AddGraph(opts)
					opts = opts or {}
					return createGraph(self, opts.Title or "Graph", opts.Points or opts.Values)
				end
				function tab:AddDateTimePicker(opts)
					opts = opts or {}
					return createDateTimePicker(self, opts.Title or "Date / Time", opts.Callback)
				end
				function tab:AddImageViewer(opts)
					opts = opts or {}
					return createImageViewer(self, opts.Title or "Image", opts.Image or opts.ImageId)
				end
				function tab:AddFileBrowser(opts)
					opts = opts or {}
					return createFileBrowser(self, opts.Title or "Files", opts.Files or opts.Items, opts.Callback)
				end
				return tab
			end
			for _, t in ipairs(tabs) do
				pcall(function()
					if not t.AddRadioGroup then bindTabAPI(t) end
				end)
			end
		end
	end)

	return Zenless
end

-- Auto-apply if Zenless table already exists in this scope (after public library block)
pcall(function()
	if type(Zenless) == "table" then
		applyV6PublicAPI(Zenless)
	end
end)


end)()

-- ============ KEY SYSTEM ============
local function runKeySystem(opts)
	opts = type(opts) == "table" and opts or {}
	local title = opts.Title or "ZENLESS"
	local subtitle = opts.Subtitle or opts.SubTitle or "Enter your key to continue"
	local note = opts.Note or opts.Description or ""
	local saveKey = opts.SaveKey ~= false
	local fileName = opts.FileName or opts.KeyFile or "zenless_key.txt"
	local keyLink = opts.KeyLink or opts.Discord or opts.Link
	local onSuccess = opts.Callback or opts.OnSuccess
	local onFail = opts.OnFail

	local function normalizeKey(s)
		s = tostring(s or "")
		s = string.gsub(s, "^%s+", "")
		s = string.gsub(s, "%s+$", "")
		s = string.gsub(s, "%s+", "")
		return string.upper(s)
	end

	local function httpGet(url)
		if type(url) ~= "string" or url == "" then return nil end
		local ok, body = pcall(function()
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
		end)
		if ok then return body end
		return nil
	end

	local valid = {}
	local function addKey(k)
		local n = normalizeKey(k)
		if n ~= "" then valid[n] = true end
	end
	if opts.Key then addKey(opts.Key) end
	if type(opts.Keys) == "table" then
		for _, k in ipairs(opts.Keys) do addKey(k) end
	end
	if type(opts.GetKey) == "function" then
		pcall(function()
			local k = opts.GetKey()
			if type(k) == "table" then
				for _, v in ipairs(k) do addKey(v) end
			else
				addKey(k)
			end
		end)
	end
	if type(opts.OnlineKey) == "string" then
		local body = httpGet(opts.OnlineKey)
		if type(body) == "string" then
			for line in string.gmatch(body, "[^\r\n]+") do
				local trimmed = string.gsub(line, "^%s+", "")
				trimmed = string.gsub(trimmed, "%s+$", "")
				if trimmed ~= "" and not string.find(trimmed, "^#") and not string.find(trimmed, "^%-%-") then
					addKey(trimmed)
				end
			end
		end
	end

	local function isValid(raw)
		local n = normalizeKey(raw)
		return n ~= "" and valid[n] == true
	end

	local function saveAccepted(raw)
		if not saveKey then return end
		pcall(function()
			if typeof(writefile) == "function" then
				writefile(fileName, tostring(raw))
			end
		end)
	end

	local function loadSaved()
		if not saveKey then return nil end
		local ok, data = pcall(function()
			if typeof(readfile) ~= "function" then return nil end
			if typeof(isfile) == "function" and not isfile(fileName) then return nil end
			return readfile(fileName)
		end)
		if ok then return data end
		return nil
	end

	-- Already unlocked via saved key
	local saved = loadSaved()
	if saved and isValid(saved) then
		State.keyGateActive = false
		pcall(function()
			if onSuccess then onSuccess(true, saved) end
		end)
		pcall(function()
			if showWindow then showWindow() end
		end)
		return true
	end

	-- Hide main shell while prompting (also blocks bootLibrary showWindow)
	State.keyGateActive = true
	pcall(function()
		root.Visible = false
		window.Visible = false
		if windowRim then windowRim.Visible = false end
	end)

	local finished = false
	local unlocked = false
	local CARD_W, CARD_H = 380, 250

	local dim = make("TextButton", {
		Name = "KeyDim",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 198,
	})
	dim.Parent = screenGui

	local host = make("Frame", {
		Name = "KeySystemHost",
		Size = UDim2.fromOffset(CARD_W - 18, CARD_H - 14),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 200,
	})
	host.Parent = screenGui

	local keyStroke = stroke(Color3.fromRGB(210, 210, 220), 1, 0.2)
	local keyAccentStroke = stroke(Theme.Accent, 1, 0.62)
	registerAccent(keyAccentStroke, "Color")

	local card = make("CanvasGroup", {
		Name = "KeyCard",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		ZIndex = 201,
		ClipsDescendants = true,
	}, { corner(14), keyStroke, keyAccentStroke })
	card.Parent = host

	make("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 201,
	}, {
		corner(14),
		make("UIGradient", {
			Rotation = 150,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 44)),
				ColorSequenceKeypoint.new(0.5, Theme.Background),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 9, 11)),
			}),
		}),
	}).Parent = card

	local topAccent = make("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 210,
		ClipsDescendants = true,
	})
	topAccent.Parent = card
	registerAccent(topAccent, "BackgroundColor3")
	local topShine = make("Frame", {
		Size = UDim2.new(0.35, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 211,
	})
	topShine.Parent = topAccent
	make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}).Parent = topShine
	task.spawn(function()
		while topShine.Parent and not finished do
			topShine.Position = UDim2.new(-0.4, 0, 0, 0)
			tween(topShine, TweenInfo.new(1.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(1.2, 0, 0, 0),
			})
			task.wait(2.6)
		end
	end)

	pcall(function()
		attachPerimeterLight(card, {
			CornerRadius = 14,
			Thickness = 1.2,
			Period = 3.4,
			ZIndex = 230,
		})
	end)

	-- Header: brand only + close (no extra boxes)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -56, 0, 18),
		Position = UDim2.fromOffset(22, 18),
		Font = Enum.Font.GothamBold,
		Text = string.upper(tostring(title)) .. "  ·  ACCESS",
		TextSize = 11,
		TextColor3 = Color3.fromRGB(160, 160, 170),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 212,
	}).Parent = card

	local closeBtn = make("TextButton", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -38, 0, 14),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 220,
	})
	closeBtn.Parent = card
	local closeIcon = drawIcon(closeBtn, "close", Color3.fromRGB(140, 140, 150), 12)

	-- Single headline (plain text — never a bordered box)
	make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -44, 0, 28),
		Position = UDim2.fromOffset(22, 48),
		Font = Enum.Font.GothamBold,
		Text = subtitle,
		TextSize = 20,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 212,
	}).Parent = card

	-- ONE input only — TextBox is the field itself (no nested icon boxes)
	local box = make("TextBox", {
		Name = "KeyInput",
		Size = UDim2.new(1, -44, 0, 48),
		Position = UDim2.fromOffset(22, 92),
		BackgroundColor3 = Color3.fromRGB(20, 20, 24),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		Text = "",
		PlaceholderText = "Enter key",
		PlaceholderColor3 = Color3.fromRGB(100, 100, 112),
		TextColor3 = Theme.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 214,
	}, {
		corner(11),
		stroke(Color3.fromRGB(120, 120, 132), 1, 0.4),
	})
	box.Parent = card
	local inputStroke = box:FindFirstChildOfClass("UIStroke")
	-- Prefill only a currently-valid saved key (never stale wrong keys)
	if saved and isValid(saved) then
		box.Text = tostring(saved)
	end

	local statusLbl = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -44, 0, 16),
		Position = UDim2.fromOffset(22, 146),
		Font = Enum.Font.Gotham,
		Text = "",
		TextSize = 12,
		TextColor3 = Theme.Error,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 212,
	})
	statusLbl.Parent = card

	local unlockBtn = make("TextButton", {
		Size = UDim2.new(1, -44, 0, 42),
		Position = UDim2.fromOffset(22, 170),
		BackgroundColor3 = Theme.Accent,
		Text = "Unlock",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(14, 14, 18),
		AutoButtonColor = false,
		ZIndex = 214,
	}, {
		corner(11),
		make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 240, 246)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(168, 168, 180)),
			}),
		}),
	})
	unlockBtn.Parent = card

	local getKeyBtn = make("TextButton", {
		Size = UDim2.new(1, -44, 0, 20),
		Position = UDim2.fromOffset(22, 218),
		BackgroundTransparency = 1,
		Text = keyLink and "Get a key" or "",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(140, 140, 152),
		AutoButtonColor = false,
		ZIndex = 214,
		Visible = keyLink ~= nil,
	})
	getKeyBtn.Parent = card

	local function finish(ok, raw)
		if finished then return end
		finished = true
		unlocked = ok and true or false
		State.keyGateActive = false
		pcall(function()
			tween(card, Anim.Smooth, { GroupTransparency = 1 })
			tween(dim, Anim.Smooth, { BackgroundTransparency = 1 })
		end)
		task.delay(0.28, function()
			pcall(function()
				if host and host.Parent then host:Destroy() end
				if dim and dim.Parent then dim:Destroy() end
			end)
		end)
		if ok then
			saveAccepted(raw)
			pcall(function()
				if onSuccess then onSuccess(true, raw) end
			end)
			pcall(function()
				if showWindow then showWindow() end
			end)
			pcall(function()
				if notify then
					notify("Unlocked", "Welcome to " .. title, "success", 2.4)
				end
			end)
		else
			pcall(function()
				if onFail then onFail() end
			end)
		end
	end

	local function shake()
		local base = host.Position
		task.spawn(function()
			for i = 1, 5 do
				host.Position = UDim2.new(base.X.Scale, base.X.Offset + ((i % 2 == 0) and 5 or -5), base.Y.Scale, base.Y.Offset)
				task.wait(0.03)
			end
			host.Position = base
		end)
	end

	local function tryUnlock()
		local raw = box.Text
		if isValid(raw) then
			statusLbl.TextColor3 = Theme.Success
			statusLbl.Text = "Access granted"
			if inputStroke then
				tween(inputStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0 })
			end
			unlockBtn.Text = "Opening…"
			task.delay(0.25, function()
				finish(true, raw)
			end)
		else
			statusLbl.TextColor3 = Theme.Error
			statusLbl.Text = "Invalid key"
			if inputStroke then
				tween(inputStroke, Anim.Fast, { Color = Theme.Error, Transparency = 0 })
			end
			shake()
			pcall(function()
				if playUiSound then playUiSound("error") end
			end)
		end
	end

	unlockBtn.MouseButton1Click:Connect(tryUnlock)
	box.Focused:Connect(function()
		statusLbl.Text = ""
		if inputStroke then
			tween(inputStroke, Anim.Fast, { Color = Theme.Accent, Transparency = 0.12 })
		end
	end)
	box.FocusLost:Connect(function(enter)
		if enter then
			tryUnlock()
		elseif inputStroke and statusLbl.TextColor3 ~= Theme.Error then
			tween(inputStroke, Anim.Fast, { Color = Color3.fromRGB(120, 120, 132), Transparency = 0.4 })
		end
	end)

	unlockBtn.MouseEnter:Connect(function()
		tween(unlockBtn, Anim.Fast, { BackgroundColor3 = Theme.AccentHover })
	end)
	unlockBtn.MouseLeave:Connect(function()
		tween(unlockBtn, Anim.Fast, { BackgroundColor3 = Theme.Accent })
	end)
	getKeyBtn.MouseEnter:Connect(function()
		tween(getKeyBtn, Anim.Fast, { TextColor3 = Theme.Text })
	end)
	getKeyBtn.MouseLeave:Connect(function()
		tween(getKeyBtn, Anim.Fast, { TextColor3 = Color3.fromRGB(140, 140, 152) })
	end)
	closeBtn.MouseEnter:Connect(function()
		if closeIcon and closeIcon.SetColor then closeIcon.SetColor(Theme.Error) end
	end)
	closeBtn.MouseLeave:Connect(function()
		if closeIcon and closeIcon.SetColor then closeIcon.SetColor(Color3.fromRGB(140, 140, 150)) end
	end)

	getKeyBtn.MouseButton1Click:Connect(function()
		if not keyLink then return end
		local copied = false
		pcall(function()
			if typeof(setclipboard) == "function" then
				setclipboard(tostring(keyLink))
				copied = true
			end
		end)
		statusLbl.TextColor3 = Theme.SubText
		statusLbl.Text = copied and "Link copied" or tostring(keyLink)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		finish(false)
	end)
	dim.MouseButton1Click:Connect(function() end)

	card.GroupTransparency = 1
	tween(dim, Anim.Smooth, { BackgroundTransparency = 0.55 })
	tween(card, Anim.Smooth, { GroupTransparency = 0 })
	tween(host, Anim.Spring, { Size = UDim2.fromOffset(CARD_W, CARD_H) })
	task.defer(function()
		pcall(function() box:CaptureFocus() end)
	end)

	while not finished and screenGui and screenGui.Parent do
		task.wait()
	end

	return unlocked
end

-- ============ PUBLIC LIBRARY ============
local Zenless = {
	Name = "ZENLESS",
	Version = LIBRARY_VERSION,
	Theme = Theme,
	Flags = Flags,
	ScreenGui = screenGui,
	Root = root,
	Icons = IconNames,
	DrawIcon = drawIcon,
	Config = ConfigData,
}

function Zenless:Notify(opts)
	if type(opts) == "string" then
		return notify(opts, "", "info", 3.2, nil)
	end
	opts = opts or {}
	return notify(
		opts.Title or "Notice",
		opts.Content or opts.Body or opts.Description or "",
		opts.Type or opts.Kind or "info",
		opts.Duration or 3.4,
		opts
	)
end

function Zenless:ClearNotifications()
	for i = #activeNotifs, 1, -1 do
		dismissNotif(activeNotifs[i])
	end
end

function Zenless:SetAccent(color)
	setAccent(color)
end

function Zenless:AddTab(config)
	return createTab(config)
end

function Zenless:SelectTab(tab)
	switchTab(tab)
end

function Zenless:GetTabs()
	return tabs
end

function Zenless:Unload()
	destroyGui()
	pcall(function()
		if getgenv().Zenless == Zenless then getgenv().Zenless = nil end
		if getgenv().Fluent == Zenless then getgenv().Fluent = nil end
	end)
end

Zenless.Window = {
	TitleLabel = titleLabel,
	Destroy = destroyGui,
	Unload = destroyGui,
	Toggle = toggleWindow,
	Show = function()
		uiVisible = true
		showWindow()
	end,
	Hide = function()
		uiVisible = false
		hideWindow()
	end,
	Minimize = function(state)
		if state == nil then
			return minimizeWindow and minimizeWindow()
		end
		if (state and true or false) ~= minimized then
			return minimizeWindow and minimizeWindow()
		end
		return minimized
	end,
	SetTitle = function(text)
		titleLabel.Text = text
	end,
	SetToggleKey = function(key)
		toggleKey = key
		hintLabel.Text = key.Name .. " — hide"
	end,
	Celebrate = function()
		celebrateOpen(window)
	end,
	GetTabs = function()
		return tabs
	end,
}

function Zenless:KeySystem(opts)
	return runKeySystem(opts)
end

function Zenless:CreateWindow(config)
	config = config or {}
	-- Optional gate: CreateWindow({ KeySystem = { Key = "..." } }) or KeySettings =
	local keyOpts = config.KeySettings or (type(config.KeySystem) == "table" and config.KeySystem) or nil
	if keyOpts then
		local ok = runKeySystem(keyOpts)
		if not ok then
			pcall(destroyGui)
			return nil
		end
	end
	if config.Title then
		titleLabel.Text = config.Title
	end
	if config.Subtitle or config.SubTitle then
		titleLabel.Text = config.Title or titleLabel.Text
	end
	if config.MinimizeKey or config.ToggleKey then
		Zenless.Window.SetToggleKey(config.MinimizeKey or config.ToggleKey)
	end
	if config.Accent then
		setAccent(config.Accent)
	end
	if config.SizePreset then
		pcall(function() setSizePreset(config.SizePreset) end)
	end
	return Zenless.Window
end

-- Apply v6 API surface (window helpers, notifs, theme, components on tabs)
pcall(function()
	applyV6PublicAPI(Zenless)
end)

-- Aliases for Fluent-style loaders
local Fluent = Zenless
Zenless.Fluent = Zenless

pcall(function()
	getgenv().Zenless = Zenless
	getgenv().Fluent = Zenless
end)


-- Unfocused opacity watcher
task.spawn(function()
	while screenGui and screenGui.Parent do
		task.wait(0.35)
		local amt = Flags.UnfocusedOpacity or 0
		if amt <= 0 or not window or not window.Parent or not uiVisible then continue end
		local mouse = UserInputService:GetMouseLocation()
		local ap, asz = root.AbsolutePosition, root.AbsoluteSize
		local inside = mouse.X >= ap.X and mouse.X <= ap.X + asz.X and mouse.Y >= ap.Y and mouse.Y <= ap.Y + asz.Y
		local target = inside and (State.windowOpacity or 0) or math.clamp(amt, 0, 0.85)
		pcall(function()
			if math.abs((window.GroupTransparency or 0) - target) > 0.02 then
				tween(window, Anim.Smooth, { GroupTransparency = target })
			end
		end)
	end
end)

-- Daily accent + open sound
pcall(function()
	if dailyAccent then dailyAccent() end
	playUiSound("open")
end)

local function envFlag(name)
	local ok, val = pcall(function()
		return getgenv()[name]
	end)
	return ok and val == true
end

local showDemo = envFlag("ZENLESS_DEMO")
local skipLoader = envFlag("ZENLESS_NO_LOADER")
-- Legacy: FLUENT_NO_DEMO forced library mode (now default). Ignore unless demo requested.

local function bootLibrary(firstTab)
	task.defer(function()
		-- Always clear loader host/rim (fixes ghost glass frame when NO_LOADER)
		if skipLoader or not playLoader then
			pcall(function()
				if loaderHost and loaderHost.Parent then loaderHost:Destroy() end
				for _, ch in ipairs(screenGui:GetChildren()) do
					if ch.Name == "LoaderHost" or (ch.Name == "MetallicRim" and ch.Parent == screenGui) then
						ch:Destroy()
					end
				end
			end)
		else
			pcall(playLoader)
			pcall(function()
				if loaderHost and loaderHost.Parent then loaderHost:Destroy() end
			end)
		end
		showWindow()
		-- hard-reset if a bad size somehow stuck
		pcall(function()
			if root.Size.Y.Offset < 280 or root.Size.X.Offset < 420 then
				WIN_W, WIN_H = 610, 430
				root.Size = UDim2.fromOffset(WIN_W, WIN_H)
			end
		end)
		if Flags.AutoCollapseSidebar and setSidebarCollapsed then
			pcall(setSidebarCollapsed, true)
		end
		if firstTab then
			task.wait(0.1)
			Zenless:SelectTab(firstTab)
		end
	end)
end

if not showDemo then
	-- Library mode: empty shell — consumer scripts call AddTab / CreateWindow
	bootLibrary(nil)
	return Zenless
end

-- ============ DEMO UI (opt-in: getgenv().ZENLESS_DEMO = true) ============
(function()
local homeTab = Zenless:AddTab({ Title = "Home", Icon = "home", Description = "Overview", Color = Color3.fromRGB(198, 198, 208) })
local playerTab = Zenless:AddTab({ Title = "Player", Icon = "user", Description = "Movement", Color = Color3.fromRGB(170, 170, 180) })
local visualsTab = Zenless:AddTab({ Title = "Visuals", Icon = "eye", Description = "World", Color = Color3.fromRGB(210, 210, 220) })
local extrasTab = Zenless:AddTab({ Title = "Extras", Icon = "star", Description = "Tools", Color = Color3.fromRGB(160, 160, 170) })
local settingsTab = Zenless:AddTab({ Title = "Settings", Icon = "settings", Description = "Options", Color = Color3.fromRGB(140, 140, 150) })

homeTab:AddSection("WELCOME")
homeTab:AddParagraph("ZENLESS",
	"Library mode is default. Set getgenv().ZENLESS_DEMO = true before load to see this showcase.")

homeTab:AddSection("SESSION")
local sessionStat = homeTab:AddStatCard({ Title = "Session uptime", Value = "0:00", Sub = "Live counter" })
homeTab:AddBadgeRow({ "v5.1", "ZENLESS", "Library", "Silver" })

homeTab:AddButton({
	Title = "Test notifications",
	Primary = true,
	Callback = function()
		Zenless:Notify({ Title = "Info", Content = "Informational message.", Type = "info", Duration = 2.5 })
		task.wait(0.15)
		Zenless:Notify({ Title = "Success", Content = "That worked.", Type = "success", Duration = 2.5 })
		task.wait(0.15)
		Zenless:Notify({ Title = "Warning", Content = "Something to watch.", Type = "warning", Duration = 2.5 })
		task.wait(0.15)
		Zenless:Notify({ Title = "Error", Content = "Something failed (demo).", Type = "error", Duration = 2.5 })
	end,
})
homeTab:AddHotkeyHint({ "RightShift" }, "Toggle window visibility")

task.spawn(function()
	local secs = 0
	while sessionStat and homeTab.Page.Parent do
		task.wait(1)
		secs += 1
		sessionStat.SetValue(string.format("%d:%02d", math.floor(secs / 60), secs % 60))
	end
end)

playerTab:AddSection("MOVEMENT")
local walkSlider = playerTab:AddSlider({
	Title = "Walk speed",
	Min = 8,
	Max = 200,
	Default = 16,
	Callback = function(v)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = v end
	end,
})
local jumpSlider = playerTab:AddSlider({
	Title = "Jump power",
	Min = 20,
	Max = 300,
	Default = 50,
	Callback = function(v)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = v
		end
	end,
})
playerTab:AddButton({
	Title = "Reset movement",
	Callback = function()
		walkSlider.Set(16)
		jumpSlider.Set(50)
		Zenless:Notify({ Title = "Player", Content = "Movement reset.", Type = "success", Duration = 2 })
	end,
})

visualsTab:AddSection("WORLD")
visualsTab:AddToggle({
	Title = "Full bright",
	Default = false,
	Callback = function(on)
		local lighting = game:GetService("Lighting")
		if on then
			lighting.Brightness = 3
			lighting.ClockTime = 14
			lighting.GlobalShadows = false
		else
			lighting.Brightness = 1
			lighting.GlobalShadows = true
		end
	end,
})
visualsTab:AddSlider({
	Title = "Field of view",
	Min = 40,
	Max = 120,
	Default = 70,
	Callback = function(v)
		workspace.CurrentCamera.FieldOfView = v
	end,
})

extrasTab:AddSection("LIBRARY API")
extrasTab:AddInfoGrid({
	{ label = "Version", value = Zenless.Version },
	{ label = "Accent", value = "Silver" },
	{ label = "Mode", value = "Demo" },
	{ label = "Brand", value = "ZENLESS" },
})
extrasTab:AddButton({
	Title = "Celebrate",
	Primary = true,
	Callback = function()
		Zenless.Window.Celebrate()
	end,
})

settingsTab:AddSection("INTERFACE")
settingsTab:AddKeybind({
	Title = "Hide / show key",
	Default = Enum.KeyCode.RightShift,
	Callback = function(k)
		Zenless.Window.SetToggleKey(k)
		Zenless:Notify({ Title = "Keybind", Content = "Hide key is now " .. k.Name, Type = "success", Duration = 2 })
	end,
})
settingsTab:AddThemePresets()
settingsTab:AddColorpicker({
	Title = "Accent color",
	Default = Theme.Accent,
	Callback = function(c)
		Zenless:SetAccent(c)
	end,
})
settingsTab:AddDivider()
settingsTab:AddButton({
	Title = "Destroy GUI",
	Primary = true,
	Callback = destroyGui,
})

bootLibrary(homeTab)
Zenless:Notify({
	Title = "ZENLESS",
	Content = "Demo mode. Use AimbotExample.lua for a real hub script.",
	Type = "success",
	Duration = 3,
})

return Zenless
end)()
