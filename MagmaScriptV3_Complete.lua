--==================================================
-- MAGMASCRIPT V3
-- Run in your executor, or as a LocalScript in StarterPlayerScripts
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

pcall(function()
	RunService:UnbindFromRenderStep("MagmaAim")
end)
for _, name in ipairs({ "MagmaScript", "MagmaScriptV3" }) do
	local old = PlayerGui:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

--==================================================
-- SETTINGS + SAVE SYSTEM
--==================================================
local Defaults = {
	-- esp
	esp = false, chams = true, box = true, hpbar = true, names = true, dist = true, tracers = false,
	-- movement
	fly = false, lockfly = false, flyspeed = 60,
	speedon = false, walkspeed = 32,
	jumpon = false, jumppower = 70,
	noclip = false,
	-- aim
	aim = false, showfov = true, aimhead = true, teamcheck = true, wallcheck = true,
	aimfov = 70, aimstrength = 45, prediction = 0.07,
	autonear = false, nearrange = 30,
	autoattack = false, attackrange = 12, attackrate = 0.12, autoequip = true,
	-- teleport
	tpeffect = true, showpin = true, dupin = false,
	-- settings
	animated = true, transparent = false, theme = "#8C5AFF", minkey = "LeftControl", autosave = false,
}

local S = {}
for k, v in pairs(Defaults) do
	S[k] = v
end

local SAVE_FILE = "MagmaScriptV3.json"
local Mem = (getgenv and getgenv()) or shared
local Store = { autosave = false, slot = 0, current = nil, slots = {} }
local Loading = false
local SaveQueued = false

local function readStore()
	local raw = nil
	if isfile and readfile then
		pcall(function()
			if isfile(SAVE_FILE) then
				raw = readfile(SAVE_FILE)
			end
		end)
	end
	raw = raw or Mem.MagmaScriptV3
	if type(raw) == "string" then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(data) == "table" then
			return data
		end
	end
	return nil
end

-- returns true only when the file was really written (false = session only)
local function writeStore()
	local ok, json = pcall(function()
		return HttpService:JSONEncode(Store)
	end)
	if not ok then
		return false
	end
	Mem.MagmaScriptV3 = json
	if writefile then
		return (pcall(function()
			writefile(SAVE_FILE, json)
		end))
	end
	return false
end

do
	local d = readStore()
	if d then
		Store.autosave = (d.autosave == true)
		Store.slot = tonumber(d.slot) or 0
		Store.current = (type(d.current) == "table") and d.current or nil
		Store.slots = (type(d.slots) == "table") and d.slots or {}
	end
end
S.autosave = Store.autosave

local function Snapshot()
	local t = {}
	for k in pairs(Defaults) do
		if k ~= "autosave" then
			t[k] = S[k]
		end
	end
	return t
end

local function QueueSave()
	if Loading or not Store.autosave or SaveQueued then
		return
	end
	SaveQueued = true
	task.delay(1, function()
		SaveQueued = false
		Store.current = Snapshot()
		writeStore()
	end)
end

--==================================================
-- THEME SYSTEM (everything recolors live)
--==================================================
local WHITE = Color3.fromRGB(245, 247, 255)
local MUTED = Color3.fromRGB(165, 160, 205)
local OFF = Color3.fromRGB(70, 64, 100)

local HP_GREEN = Color3.fromRGB(0, 230, 90)
local HP_YELLOW = Color3.fromRGB(255, 225, 40)
local HP_ORANGE = Color3.fromRGB(255, 140, 0)
local HP_RED = Color3.fromRGB(255, 45, 45)

local T = {}
local Binds, Pulses, Anims, Conns = {}, {}, {}, {}

local function dark(c, f)
	return c:Lerp(Color3.new(0, 0, 0), f)
end

local function computeTheme(hex)
	local ok, c = pcall(Color3.fromHex, hex)
	if not ok or typeof(c) ~= "Color3" then
		return false
	end
	local h, s, v = c:ToHSV()
	s = math.clamp(s, 0.35, 1)
	v = math.clamp(v, 0.6, 1)
	T.accent = Color3.fromHSV(h, s, v)
	T.second = Color3.fromHSV((h + 0.1) % 1, math.clamp(s * 0.85, 0.3, 1), 1)
	T.third = Color3.fromHSV((h - 0.1) % 1, math.clamp(s * 0.8, 0.3, 1), 1)
	T.card = dark(T.accent, 0.8)
	T.deep = dark(T.accent, 0.94)
	T.top = dark(T.accent, 0.76)
	T.bot = dark(T.second, 0.8)
	return true
end

local startTheme = (Store.autosave and Store.current and Store.current.theme) or Defaults.theme
if not computeTheme(startTheme) then
	computeTheme(Defaults.theme)
end

local function bind(obj, prop, fn)
	table.insert(Binds, { obj = obj, prop = prop, fn = fn })
	obj[prop] = fn()
	return obj
end

local function ApplyTheme()
	for _, b in ipairs(Binds) do
		pcall(function()
			b.obj[b.prop] = b.fn()
		end)
	end
end

--==================================================
-- HELPERS
--==================================================
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function round(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function tween(o, props, t)
	TweenService:Create(
		o,
		TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

local function loop(o, props, t, delay)
	local tw = TweenService:Create(
		o,
		TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, delay or 0),
		props
	)
	tw:Play()
	table.insert(Anims, tw)
	return tw
end

local function spin(o, props, t)
	local tw = TweenService:Create(
		o,
		TweenInfo.new(t, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
		props
	)
	tw:Play()
	table.insert(Anims, tw)
	return tw
end

local function hpColor(pct)
	if pct < 0.30 then return HP_RED end
	if pct < 0.50 then return HP_ORANGE end
	if pct < 0.80 then return HP_YELLOW end
	return HP_GREEN
end

local function stroke(parent, transparency, thickness, fn)
	local st = new("UIStroke", { Thickness = thickness or 1, Transparency = transparency or 0 }, parent)
	bind(st, "Color", fn or function()
		return T.accent
	end)
	return st
end

-- animated color pulse (accent <-> second), follows the theme
local function pulse(obj, prop)
	table.insert(Pulses, { obj = obj, prop = prop })
	obj[prop] = T.accent
end

local pulseClock = 0
table.insert(Conns, RunService.Heartbeat:Connect(function(dt)
	if not S.animated then return end
	pulseClock += dt
	local c = T.accent:Lerp(T.second, (math.sin(pulseClock * 2.2) + 1) / 2)
	for _, p in ipairs(Pulses) do
		p.obj[p.prop] = c
	end
end))

--==================================================
-- GUI ROOT
--==================================================
local GUI = new("ScreenGui", {
	Name = "MagmaScriptV3",
	ResetOnSpawn = false,
	DisplayOrder = 999,
	IgnoreGuiInset = true,
}, PlayerGui)

local TracerLayer = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, GUI)

-- teleport screen flash
local FlashFrame = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Active = false,
	ZIndex = 40,
}, GUI)

-- aim circle (small, center of screen)
local Circle = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(S.aimfov * 2, S.aimfov * 2),
	BackgroundTransparency = 1,
	Visible = false,
}, GUI)
round(Circle, 1000)
local CircleStroke = new("UIStroke", { Color = T.accent, Thickness = 1.2, Transparency = 0.1 }, Circle)

-- toast notifications
local function Toast(text)
	local t = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -50),
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(10, 8, 24),
		BackgroundTransparency = 0.08,
		Text = text,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		ZIndex = 50,
	}, GUI)
	round(t, 16)
	new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, t)
	new("UIStroke", { Color = T.accent, Thickness = 1.5, Transparency = 0.2 }, t)
	tween(t, { Position = UDim2.new(0.5, 0, 0, 16) }, 0.3)
	task.delay(2.2, function()
		tween(t, { Position = UDim2.new(0.5, 0, 0, -50), BackgroundTransparency = 1, TextTransparency = 1 }, 0.3)
		task.delay(0.35, function()
			t:Destroy()
		end)
	end)
end

-- M icon (fixed, cannot be moved)
local Icon = new("TextButton", {
	Size = UDim2.fromOffset(48, 48),
	Position = UDim2.new(0, 14, 0.5, -24),
	BackgroundColor3 = WHITE,
	Text = "",
	AutoButtonColor = false,
}, GUI)
round(Icon, 14)
local IconGradient = new("UIGradient", { Rotation = 45 }, Icon)
bind(IconGradient, "Color", function()
	return ColorSequence.new(T.accent, T.second)
end)
local IconStroke = new("UIStroke", { Thickness = 2, Transparency = 0.1 }, Icon)
pulse(IconStroke, "Color")
new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "M",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
}, Icon)

-- teleport quick buttons (show only when a pin exists)
local function quickButton(text, yOffset, c1, c2)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(48, 30),
		Position = UDim2.new(0, 14, 0.5, yOffset),
		BackgroundColor3 = WHITE,
		Text = text,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		AutoButtonColor = false,
		Visible = false,
	}, GUI)
	round(b, 10)
	local g = new("UIGradient", { Rotation = 45 }, b)
	bind(g, "Color", function()
		return ColorSequence.new(c1(), c2())
	end)
	new("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.55 }, b)
	return b
end

local TPButton = quickButton("TP", 32, function() return T.second end, function() return T.accent end)
local TP2Button = quickButton("TP2", 68, function() return Color3.fromRGB(255, 110, 210) end, function() return T.third end)

-- fly UP / DOWN pad (only visible while flying)
local FlyPad = new("Frame", {
	Size = UDim2.fromOffset(66, 140),
	Position = UDim2.new(1, -86, 0.5, -70),
	BackgroundTransparency = 1,
	Visible = false,
}, GUI)

local UpHeld, DownHeld = false, false

local function holdButton(text, y, setter)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(66, 66),
		Position = UDim2.fromOffset(0, y),
		BackgroundColor3 = Color3.fromRGB(8, 6, 22),
		BackgroundTransparency = 0.12,
		Text = text,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		AutoButtonColor = false,
	}, FlyPad)
	round(b, 33)
	bind(b, "TextColor3", function()
		return T.second
	end)
	stroke(b, 0, 2)

	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setter(true)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1 then
			setter(false)
		end
	end)
end
holdButton("UP", 0, function(v) UpHeld = v end)
holdButton("DOWN", 74, function(v) DownHeld = v end)

--==================================================
-- WINDOW
--==================================================
local Main = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.55, 0.5),
	Size = UDim2.fromScale(0.6, 0.74),
	BackgroundColor3 = Color3.fromRGB(8, 6, 22),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, GUI)
round(Main, 12)
local Constraint = new("UISizeConstraint", {
	MinSize = Vector2.new(400, 260),
	MaxSize = Vector2.new(720, 460),
}, Main)
local MainScale = new("UIScale", { Scale = 0 }, Main)
local MainStroke = new("UIStroke", { Thickness = 1.6, Transparency = 0.05 }, Main)
pulse(MainStroke, "Color")

-- galaxy background
local Galaxy = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, Main)
round(Galaxy, 12)

local GalaxyGradient = new("UIGradient", {}, Galaxy)
bind(GalaxyGradient, "Color", function()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.top),
		ColorSequenceKeypoint.new(0.5, T.deep),
		ColorSequenceKeypoint.new(1, T.bot),
	})
end)
spin(GalaxyGradient, { Rotation = 360 }, 26)

local function nebula(fn, size, x, y, dx, dy, t)
	local n = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(x, y),
		BackgroundTransparency = 0.85,
		BorderSizePixel = 0,
	}, Galaxy)
	round(n, 1000)
	bind(n, "BackgroundColor3", fn)
	loop(n, { Position = UDim2.fromScale(x + dx, y + dy) }, t)
end
nebula(function() return T.accent end, 280, -0.12, -0.05, 0.28, 0.12, 9)
nebula(function() return T.second end, 250, 0.55, 0.45, -0.22, -0.16, 11)
nebula(function() return T.third end, 190, 0.2, 0.65, 0.3, -0.12, 13)

for i = 1, 40 do
	local size = math.random(1, 3)
	local star = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(math.random(2, 98) / 100, math.random(2, 98) / 100),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, Galaxy)
	round(star, 2)
	if i % 5 == 0 then
		bind(star, "BackgroundColor3", function() return T.second end)
	else
		star.BackgroundColor3 = WHITE
	end
	loop(star, { BackgroundTransparency = 0.9 }, 0.8 + math.random() * 1.8, math.random() * 2)
end

task.spawn(function()
	while GUI.Parent do
		task.wait(2.5 + math.random() * 4)
		if GUI.Parent and S.animated and Main.Visible then
			local sx = math.random(0, 60) / 100
			local s = new("Frame", {
				Size = UDim2.fromOffset(40, 2),
				Position = UDim2.fromScale(sx, -0.05),
				Rotation = 35,
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
			}, Galaxy)
			new("UIGradient", { Transparency = NumberSequence.new(1, 0) }, s)
			TweenService:Create(
				s,
				TweenInfo.new(1.1, Enum.EasingStyle.Linear),
				{ Position = UDim2.fromScale(sx + 0.5, 1.05), BackgroundTransparency = 1 }
			):Play()
			task.delay(1.2, function()
				s:Destroy()
			end)
		end
	end
end)

--==================================================
-- TITLE BAR
--==================================================
local TitleBar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundColor3 = Color3.fromRGB(4, 3, 14),
	BackgroundTransparency = 0.4,
	BorderSizePixel = 0,
}, Main)
round(TitleBar, 12)

new("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.9,
	BorderSizePixel = 0,
}, TitleBar)

local TitleLeft = new("Frame", {
	Position = UDim2.fromOffset(14, 0),
	Size = UDim2.new(1, -130, 1, 0),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
}, TitleBar)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, TitleLeft)

local Title = new("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	Text = "MagmaScript V3",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
}, TitleLeft)
local TitleGradient = new("UIGradient", {}, Title)
bind(TitleGradient, "Color", function()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.6, T.second),
		ColorSequenceKeypoint.new(1, T.third),
	})
end)

-- ms checker
local PingPill = new("Frame", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(54, 20),
	BackgroundColor3 = Color3.fromRGB(8, 6, 22),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
}, TitleLeft)
round(PingPill, 10)
stroke(PingPill, 0.5, 1)

local PingText = new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "-- ms",
	TextColor3 = HP_GREEN,
	Font = Enum.Font.GothamBold,
	TextSize = 11,
}, PingPill)

-- text on the side of the ms
local LinkText = new("TextLabel", {
	LayoutOrder = 3,
	Size = UDim2.fromOffset(0, 20),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1,
	RichText = true,
	Text = 'Magma Link<font size="8">™</font>: Costom',
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
}, TitleLeft)
local LinkGradient = new("UIGradient", {}, LinkText)
bind(LinkGradient, "Color", function()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.accent),
		ColorSequenceKeypoint.new(0.5, T.second),
		ColorSequenceKeypoint.new(1, T.third),
	})
end)
spin(LinkGradient, { Rotation = 360 }, 4)

-- window buttons (drawn with frames)
local function ctrlButton(x, hoverFn, draw)
	local b = new("TextButton", {
		Position = UDim2.new(1, x, 0, 0),
		Size = UDim2.fromOffset(38, 40),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, TitleBar)
	bind(b, "BackgroundColor3", hoverFn)
	draw(b)
	b.MouseEnter:Connect(function()
		tween(b, { BackgroundTransparency = 0.55 }, 0.12)
	end)
	b.MouseLeave:Connect(function()
		tween(b, { BackgroundTransparency = 1 }, 0.12)
	end)
	return b
end

local function accentFn()
	return T.accent
end

local MinBtn = ctrlButton(-114, accentFn, function(b)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(11, 2),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, b)
end)

local MaxBtn = ctrlButton(-76, accentFn, function(b)
	local sq = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
	}, b)
	new("UIStroke", { Color = WHITE, Thickness = 1.5 }, sq)
end)

local CloseBtn = ctrlButton(-38, function()
	return HP_RED
end, function(b)
	for _, rot in ipairs({ 45, -45 }) do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(14, 2),
			Rotation = rot,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, b)
	end
end)

-- drag the window by the title bar
local dragging, dragStart, startPos = false, nil, nil

TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = Main.Position
	end
end)

table.insert(Conns, UIS.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseMovement) then
		local d = input.Position - dragStart
		Main.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y
		)
	end
end))

table.insert(Conns, UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end))

--==================================================
-- BODY: SIDEBAR + CONTENT
--==================================================
local Body = new("Frame", {
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, 0, 1, -40),
	BackgroundTransparency = 1,
}, Main)

local Sidebar = new("ScrollingFrame", {
	Size = UDim2.new(0, 136, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Body)
new("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, Sidebar)
new("UIPadding", {
	PaddingTop = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
	PaddingBottom = UDim.new(0, 8),
}, Sidebar)

local Divider = new("Frame", {
	Position = UDim2.fromOffset(136, 8),
	Size = UDim2.new(0, 1, 1, -16),
	BackgroundTransparency = 0.75,
	BorderSizePixel = 0,
}, Body)
bind(Divider, "BackgroundColor3", function()
	return T.accent
end)

-- profile card
local Profile = new("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
}, Sidebar)
round(Profile, 8)
bind(Profile, "BackgroundColor3", function()
	return T.card
end)
stroke(Profile, 0.6, 1)

local Avatar = new("ImageLabel", {
	Position = UDim2.fromOffset(8, 7),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = OFF,
	BorderSizePixel = 0,
}, Profile)
round(Avatar, 16)

new("TextLabel", {
	Position = UDim2.fromOffset(46, 7),
	Size = UDim2.new(1, -50, 0, 16),
	BackgroundTransparency = 1,
	Text = Player.DisplayName,
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, Profile)

new("TextLabel", {
	Position = UDim2.fromOffset(46, 24),
	Size = UDim2.new(1, -50, 0, 14),
	BackgroundTransparency = 1,
	Text = "V3 user",
	TextColor3 = MUTED,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Profile)

task.spawn(function()
	local ok, img = pcall(function()
		return Players:GetUserThumbnailAsync(
			Player.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size100x100
		)
	end)
	if ok and Avatar.Parent then
		Avatar.Image = img
	end
end)

-- search box
local SearchBox = new("TextBox", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 0.35,
	TextColor3 = WHITE,
	PlaceholderColor3 = MUTED,
	PlaceholderText = "Search...",
	Text = "",
	ClearTextOnFocus = false,
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)
round(SearchBox, 8)
bind(SearchBox, "BackgroundColor3", function()
	return T.card
end)
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, SearchBox)
local SearchStroke = stroke(SearchBox, 0.6, 1)
SearchBox.Focused:Connect(function()
	tween(SearchStroke, { Transparency = 0 }, 0.12)
end)
SearchBox.FocusLost:Connect(function()
	tween(SearchStroke, { Transparency = 0.6 }, 0.12)
end)

-- content area
local Content = new("Frame", {
	Position = UDim2.fromOffset(137, 0),
	Size = UDim2.new(1, -137, 1, 0),
	BackgroundTransparency = 1,
}, Body)

local PageTitle = new("TextLabel", {
	Position = UDim2.fromOffset(16, 6),
	Size = UDim2.new(1, -32, 0, 34),
	BackgroundTransparency = 1,
	Text = "Main",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamMedium,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Content)

--==================================================
-- PAGES + TABS
--==================================================
local Pages, Tabs = {}, {}
local ActivePage

local function newPage(name)
	local frame = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, Content)
	bind(frame, "ScrollBarImageColor3", function()
		return T.accent
	end)
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 14),
	}, frame)

	local page = { frame = frame, items = {}, order = 0 }
	Pages[name] = page
	return page
end

local MainPage = newPage("Main")
local VisualsPage = newPage("Visuals")
local AimPage = newPage("Aim")
local TeleportPage = newPage("Teleport")
local SettingsPage = newPage("Settings")

local function OpenPage(name)
	ActivePage = name
	for n, page in pairs(Pages) do
		if n == name then
			page.frame.Position = UDim2.fromOffset(16, 44)
			page.frame.Visible = true
			tween(page.frame, { Position = UDim2.fromOffset(0, 44) }, 0.22)
		else
			page.frame.Visible = false
		end
	end
	for n, t in pairs(Tabs) do
		local on = (n == name)
		tween(t.button, { BackgroundTransparency = on and 0.72 or 1 }, 0.15)
		tween(t.label, { TextColor3 = on and WHITE or MUTED }, 0.15)
		tween(t.bar, { Size = UDim2.fromOffset(3, on and 16 or 0) }, 0.15)
	end
	PageTitle.Text = name
	Pages[name].frame.CanvasPosition = Vector2.zero
end

for i, name in ipairs({ "Main", "Visuals", "Aim", "Teleport", "Settings" }) do
	local button = new("TextButton", {
		LayoutOrder = 10 + i,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, Sidebar)
	round(button, 6)
	bind(button, "BackgroundColor3", function()
		return T.accent
	end)

	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BorderSizePixel = 0,
	}, button)
	round(bar, 2)
	bind(bar, "BackgroundColor3", function()
		return T.second
	end)

	local label = new("TextLabel", {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -16, 1, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = MUTED,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, button)

	Tabs[name] = { button = button, label = label, bar = bar }
	button.Activated:Connect(function()
		OpenPage(name)
	end)
end

local function applySearch()
	local q = SearchBox.Text:lower()
	for _, page in pairs(Pages) do
		for _, it in ipairs(page.items) do
			it.frame.Visible = (q == "") or (it.title:find(q, 1, true) ~= nil)
		end
	end
end
SearchBox:GetPropertyChangedSignal("Text"):Connect(applySearch)

--==================================================
-- ROW BUILDERS (every control registers itself so
-- setups / presets / save can set it by key)
--==================================================
local Reg = {}

local function makeSection(page, text)
	page.order += 1
	local lbl = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = page.order,
	}, page.frame)
	bind(lbl, "TextColor3", function()
		return T.second
	end)
	table.insert(page.items, { frame = lbl, title = " " })
end

local function newRow(page, class, title, sub)
	page.order += 1
	local props = {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = page.order,
	}
	if class == "TextButton" then
		props.Text = ""
		props.AutoButtonColor = false
	end
	local row = new(class, props, page.frame)
	round(row, 8)
	bind(row, "BackgroundColor3", function()
		return T.card
	end)
	local rowStroke = stroke(row, 0.8, 1)

	new("TextLabel", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -120, 0, 18),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local subLabel = new("TextLabel", {
		Position = UDim2.fromOffset(12, 27),
		Size = UDim2.new(1, -120, 0, 14),
		BackgroundTransparency = 1,
		Text = sub,
		TextColor3 = MUTED,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	row.MouseEnter:Connect(function()
		tween(rowStroke, { Transparency = 0.35 }, 0.15)
	end)
	row.MouseLeave:Connect(function()
		tween(rowStroke, { Transparency = 0.8 }, 0.15)
	end)

	table.insert(page.items, { frame = row, title = (title .. " " .. sub):lower() })
	return row, subLabel
end

-- switch row
local function makeToggle(page, key, title, sub, onChange)
	local state = S[key]
	local row = newRow(page, "TextButton", title, sub)

	local track = new("Frame", {
		Size = UDim2.fromOffset(42, 22),
		Position = UDim2.new(1, -54, 0.5, -11),
		BorderSizePixel = 0,
	}, row)
	round(track, 11)
	bind(track, "BackgroundColor3", function()
		return state and T.accent or OFF
	end)

	local knob = new("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)
	round(knob, 8)

	local function set(v)
		state = v and true or false
		S[key] = state
		tween(track, { BackgroundColor3 = state and T.accent or OFF })
		tween(knob, { Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) })
		onChange(state)
	end
	Reg[key] = set

	row.Activated:Connect(function()
		set(not state)
		QueueSave()
	end)
end

-- input row (type a value). parse(text) returns the value, or nil if invalid
local function makeBox(page, key, title, sub, parse, onChange)
	local row = newRow(page, "Frame", title, sub)

	local box = new("TextBox", {
		Position = UDim2.new(1, -110, 0.5, -14),
		Size = UDim2.fromOffset(98, 28),
		BackgroundColor3 = Color3.fromRGB(8, 6, 24),
		BackgroundTransparency = 0.15,
		TextColor3 = WHITE,
		PlaceholderColor3 = MUTED,
		Text = tostring(S[key]),
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
	}, row)
	round(box, 6)
	local boxStroke = stroke(box, 0.55, 1)

	local function set(v)
		S[key] = v
		box.Text = tostring(v)
		onChange(v)
	end
	Reg[key] = set

	box.Focused:Connect(function()
		tween(boxStroke, { Transparency = 0 }, 0.12)
	end)
	box.FocusLost:Connect(function()
		tween(boxStroke, { Transparency = 0.55 }, 0.12)
		local v = parse(box.Text)
		if v ~= nil then
			set(v)
			QueueSave()
		else
			box.Text = tostring(S[key])
		end
	end)
end

-- button row. onClick may return a short message to show on the button
local function makeButton(page, title, sub, label, onClick)
	local row = newRow(page, "Frame", title, sub)

	local btn = new("TextButton", {
		Position = UDim2.new(1, -110, 0.5, -14),
		Size = UDim2.fromOffset(98, 28),
		BackgroundTransparency = 0.1,
		Text = label,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
	}, row)
	round(btn, 6)
	bind(btn, "BackgroundColor3", function()
		return T.accent
	end)

	btn.Activated:Connect(function()
		local msg = onClick()
		if msg then
			btn.Text = msg
			task.delay(1.3, function()
				if btn.Parent then
					btn.Text = label
				end
			end)
		end
	end)
end

local function numParse(min)
	return function(text)
		local v = tonumber(text)
		if v and v == v and math.abs(v) ~= math.huge and v >= min then
			return v
		end
		return nil
	end
end

local function keyParse(text)
	local ok, key = pcall(function()
		return Enum.KeyCode[text]
	end)
	if ok and key then
		return text
	end
	return nil
end

local function hexParse(text)
	local h = text:gsub("#", ""):gsub("%s", "")
	if #h == 6 and h:match("^%x+$") then
		return "#" .. h:upper()
	end
	return nil
end
--==================================================
-- WINDOW OPEN / CLOSE / MAXIMIZE
--==================================================
local WindowOpen = true
local MinimizeKey = Enum.KeyCode.LeftControl

local function SetOpen(v)
	WindowOpen = v
	if v then
		Main.Visible = true
		TweenService:Create(
			MainScale,
			TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	else
		tween(MainScale, { Scale = 0 }, 0.18)
		task.delay(0.18, function()
			if not WindowOpen then
				Main.Visible = false
			end
		end)
	end
end

Icon.Activated:Connect(function()
	SetOpen(not WindowOpen)
end)
MinBtn.Activated:Connect(function()
	SetOpen(false)
end)

local Maxed = false
MaxBtn.Activated:Connect(function()
	Maxed = not Maxed
	Constraint.MaxSize = Maxed and Vector2.new(4000, 4000) or Vector2.new(720, 460)
	tween(Main, {
		Size = Maxed and UDim2.fromScale(0.9, 0.88) or UDim2.fromScale(0.6, 0.74),
		Position = Maxed and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.55, 0.5),
	}, 0.28)
end)

table.insert(Conns, UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == MinimizeKey then
		SetOpen(not WindowOpen)
	end
end))

--==================================================
-- PING (ms) CHECKER
--==================================================
local PingMs = 0

task.spawn(function()
	while GUI.Parent do
		local ok, v = pcall(function()
			return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		PingMs = ok and math.floor(v + 0.5) or 0
		PingText.Text = PingMs .. " ms"
		PingText.TextColor3 = PingMs < 80 and HP_GREEN or (PingMs < 150 and HP_YELLOW or HP_RED)
		task.wait(0.5)
	end
end)

--==================================================
-- ESP (chams + box + HP bar + name + distance + tracers)
--==================================================
local Tracked = {}

local function RemoveESP(player)
	local d = Tracked[player]
	if not d then return end
	Tracked[player] = nil
	d.conn:Disconnect()
	d.pulse:Cancel()
	d.hl:Destroy()
	d.box:Destroy()
	d.info:Destroy()
	d.tracer:Destroy()
end

local function RefreshESP()
	for _, d in pairs(Tracked) do
		d.refresh()
	end
end

local function BuildESP(player, char)
	RemoveESP(player)

	local hum = char:WaitForChild("Humanoid", 5)
	local root = char:WaitForChild("HumanoidRootPart", 5)
	if not hum or not root then return end
	if player.Character ~= char then return end

	-- full-body glow that pulses
	local hl = new("Highlight", {
		Name = "MS_Chams",
		FillTransparency = 0.55,
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Adornee = char,
		Enabled = false,
	}, char)
	local pulseTween = TweenService:Create(
		hl,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ FillTransparency = 0.8 }
	)
	pulseTween:Play()
	if not S.animated then
		pulseTween:Pause()
	end

	-- box + vertical HP bar (sized in studs, so it scales with distance)
	local box = new("BillboardGui", {
		Name = "MS_Box",
		Size = UDim2.fromScale(4, 6),
		StudsOffset = Vector3.new(0, -0.1, 0),
		AlwaysOnTop = true,
		Adornee = root,
		Enabled = false,
	}, char)

	local boxFrame = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
	}, box)
	local boxStroke = new("UIStroke", { Thickness = 1.5 }, boxFrame)

	local hpBg = new("Frame", {
		Position = UDim2.new(0, -7, 0, 0),
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, box)
	local hpFill = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, hpBg)

	-- name + HP number + distance above the head
	local info = new("BillboardGui", {
		Name = "MS_Info",
		Size = UDim2.fromOffset(150, 34),
		StudsOffset = Vector3.new(0, 3.8, 0),
		AlwaysOnTop = true,
		Adornee = root,
		Enabled = false,
	}, char)

	local nameLabel = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = player.DisplayName,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextStrokeTransparency = 0.35,
	}, info)

	local infoLabel = new("TextLabel", {
		Position = UDim2.fromOffset(0, 17),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextStrokeTransparency = 0.35,
	}, info)

	-- tracer line (drawn on screen)
	local tracer = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 1.5),
		BorderSizePixel = 0,
		Visible = false,
	}, TracerLayer)

	local d = { hl = hl, box = box, info = info, tracer = tracer, pulse = pulseTween, root = root, dist = 0 }

	d.update = function()
		local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		local c = hpColor(pct)
		hl.FillColor = c
		hl.OutlineColor = c
		boxFrame.BackgroundColor3 = c
		boxStroke.Color = c
		hpFill.BackgroundColor3 = c
		hpFill.Size = UDim2.fromScale(1, pct)
		tracer.BackgroundColor3 = c
		infoLabel.TextColor3 = c

		local text = math.ceil(hum.Health) .. " HP"
		if S.dist then
			text ..= "  |  " .. d.dist .. "m"
		end
		infoLabel.Text = text
	end

	d.refresh = function()
		hl.Enabled = S.esp and S.chams
		box.Enabled = S.esp and (S.box or S.hpbar)
		boxFrame.Visible = S.box
		hpBg.Visible = S.hpbar
		info.Enabled = S.esp and (S.names or S.hpbar or S.dist)
		nameLabel.Visible = S.names
		infoLabel.Visible = S.hpbar or S.dist
		if not (S.esp and S.tracers) then
			tracer.Visible = false
		end
		d.update()
	end

	d.conn = hum.HealthChanged:Connect(d.update)
	Tracked[player] = d
	d.refresh()
end

local function TrackESP(player)
	if player == Player then return end
	player.CharacterAdded:Connect(function(char)
		BuildESP(player, char)
	end)
	player.CharacterRemoving:Connect(function()
		RemoveESP(player)
	end)
	if player.Character then
		task.spawn(BuildESP, player, player.Character)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	TrackESP(p)
end
Players.PlayerAdded:Connect(TrackESP)
Players.PlayerRemoving:Connect(RemoveESP)

-- live distance + tracers
local ESPConn = RunService.RenderStepped:Connect(function()
	if not S.esp then return end

	local cam = Workspace.CurrentCamera
	if not cam then return end

	local vp = cam.ViewportSize
	local origin = Vector2.new(vp.X / 2, vp.Y)
	local camPos = cam.CFrame.Position

	for _, d in pairs(Tracked) do
		local root = d.root
		if root and root.Parent then
			if S.dist then
				local dist = math.floor((root.Position - camPos).Magnitude + 0.5)
				if dist ~= d.dist then
					d.dist = dist
					d.update()
				end
			end

			if S.tracers then
				local p, onScreen = cam:WorldToViewportPoint(root.Position)
				if onScreen then
					local b = Vector2.new(p.X, p.Y)
					local delta = b - origin
					d.tracer.Position = UDim2.fromOffset((origin.X + b.X) / 2, (origin.Y + b.Y) / 2)
					d.tracer.Size = UDim2.fromOffset(delta.Magnitude, 1.5)
					d.tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					d.tracer.Visible = true
				else
					d.tracer.Visible = false
				end
			else
				d.tracer.Visible = false
			end
		end
	end
end)

--==================================================
-- MOVEMENT: speed, jump, noclip, anti-push, fly
--==================================================
local Character, Humanoid, Root
local OrigWalk, OrigJump = 16, 50
local MoveConns = {}
local LockPos
local FlyConn, FlyAttach, FlyVel, FlyAlign

-- collision manager: noclip (and lock fly) turn collisions off, then restore
local Disabled = {}

table.insert(Conns, RunService.Stepped:Connect(function()
	if not Character then return end
	if S.noclip or (S.fly and S.lockfly) then
		for _, p in ipairs(Character:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				Disabled[p] = true
				p.CanCollide = false
			end
		end
	elseif next(Disabled) then
		for p in pairs(Disabled) do
			if p.Parent then
				p.CanCollide = true
			end
		end
		table.clear(Disabled)
	end
end))

local function SetAntiStun(on)
	if not (Humanoid and Humanoid.Parent) then return end
	pcall(function()
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not on)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not on)
	end)
end

local function ApplyMovement()
	if not (Humanoid and Humanoid.Parent) then return end
	if S.speedon then
		Humanoid.WalkSpeed = S.walkspeed
	end
	if S.jumpon then
		Humanoid.UseJumpPower = true
		Humanoid.JumpPower = S.jumppower
	end
end

-- every frame: nobody can slow, freeze, sit or push you
table.insert(Conns, RunService.Heartbeat:Connect(function()
	if not (Humanoid and Humanoid.Parent and Root and Root.Parent) then return end

	if S.speedon then
		if Humanoid.WalkSpeed ~= S.walkspeed then
			Humanoid.WalkSpeed = S.walkspeed
		end
		if not S.fly then
			if Humanoid.PlatformStand then
				Humanoid.PlatformStand = false
			end
			if Humanoid.Sit then
				Humanoid.Sit = false
			end
		end
		if Root.Anchored then
			Root.Anchored = false
		end
	end

	if S.jumpon and (not Humanoid.UseJumpPower or Humanoid.JumpPower ~= S.jumppower) then
		Humanoid.UseJumpPower = true
		Humanoid.JumpPower = S.jumppower
	end

	-- anti-push for ground noclip: cap sideways / upward speed, kill spin
	if S.noclip and not S.fly then
		local v = Root.AssemblyLinearVelocity
		local limit = math.max(Humanoid.WalkSpeed * 1.25, 30)
		local upLimit = math.max(Humanoid.JumpPower * 1.3, 60)
		local h = Vector3.new(v.X, 0, v.Z)
		local y = v.Y
		local changed = false
		if h.Magnitude > limit then
			h = h.Unit * limit
			changed = true
		end
		if y > upLimit then
			y = upLimit
			changed = true
		end
		if changed then
			Root.AssemblyLinearVelocity = Vector3.new(h.X, y, h.Z)
		end
		if Root.AssemblyAngularVelocity.Magnitude > 25 then
			Root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end))

-- fly (+ lock fly: position is forced every frame so nobody can push or fling you)
local function StopFly()
	if FlyConn then FlyConn:Disconnect() FlyConn = nil end
	if FlyVel then FlyVel:Destroy() FlyVel = nil end
	if FlyAlign then FlyAlign:Destroy() FlyAlign = nil end
	if FlyAttach then FlyAttach:Destroy() FlyAttach = nil end
	UpHeld, DownHeld = false, false
	FlyPad.Visible = false
	if Humanoid and Humanoid.Parent and Humanoid.Health > 0 then
		Humanoid.PlatformStand = false
		Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function StartFly()
	StopFly()
	if not (Humanoid and Root and Root.Parent) then return end

	Humanoid.PlatformStand = true
	LockPos = Root.Position
	FlyPad.Visible = true

	FlyAttach = new("Attachment", { Name = "MS_Attach" }, Root)
	FlyVel = new("LinearVelocity", {
		Attachment0 = FlyAttach,
		MaxForce = math.huge,
		RelativeTo = Enum.ActuatorRelativeTo.World,
		VectorVelocity = Vector3.zero,
	}, Root)
	FlyAlign = new("AlignOrientation", {
		Attachment0 = FlyAttach,
		Mode = Enum.OrientationAlignmentMode.OneAttachment,
		MaxTorque = math.huge,
		Responsiveness = 200,
	}, Root)

	FlyConn = RunService.Heartbeat:Connect(function(dt)
		if not (Root and Root.Parent and Humanoid and Humanoid.Health > 0) then return end

		local cam = Workspace.CurrentCamera
		local rel = cam.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
		local dir = cam.CFrame.LookVector * (-rel.Z) + cam.CFrame.RightVector * rel.X

		if UpHeld or UIS:IsKeyDown(Enum.KeyCode.E) then dir += Vector3.yAxis end
		if DownHeld or UIS:IsKeyDown(Enum.KeyCode.Q) then dir -= Vector3.yAxis end
		if dir.Magnitude > 1 then dir = dir.Unit end

		local vel = dir * S.flyspeed

		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		local yaw = CFrame.lookAt(Vector3.zero, flat.Unit)

		FlyVel.VectorVelocity = vel
		FlyAlign.CFrame = yaw

		if S.lockfly then
			LockPos = LockPos + vel * dt
			Root.CFrame = CFrame.new(LockPos) * yaw
			Root.AssemblyLinearVelocity = vel
			Root.AssemblyAngularVelocity = Vector3.zero
		else
			LockPos = Root.Position
		end
	end)
end

local function RefreshFly()
	if S.fly then
		StartFly()
	else
		StopFly()
	end
end

local function SetupCharacter(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	Root = char:WaitForChild("HumanoidRootPart")
	table.clear(Disabled)

	for _, c in ipairs(MoveConns) do
		c:Disconnect()
	end
	table.clear(MoveConns)

	OrigWalk = Humanoid.WalkSpeed
	OrigJump = Humanoid.JumpPower

	-- if a game sets speed / jump back, we set ours again instantly
	table.insert(MoveConns, Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if S.speedon and Humanoid.WalkSpeed ~= S.walkspeed then
			Humanoid.WalkSpeed = S.walkspeed
		end
	end))
	table.insert(MoveConns, Humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
		if S.jumpon and Humanoid.JumpPower ~= S.jumppower then
			Humanoid.UseJumpPower = true
			Humanoid.JumpPower = S.jumppower
		end
	end))
	table.insert(MoveConns, Humanoid.Died:Connect(StopFly))

	ApplyMovement()
	SetAntiStun(S.speedon)

	if S.fly then
		task.wait(0.3)
		StartFly()
	end
end

--==================================================
-- EFFECTS (rings, sparks, pillars, screen flash)
--==================================================
local function Ring(feet, color, size, t)
	local ring = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.15,
		Size = Vector3.new(0.25, 2, 2),
		CFrame = CFrame.new(feet + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	}, Workspace)
	TweenService:Create(
		ring,
		TweenInfo.new(t or 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.25, size, size), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, (t or 0.7) + 0.2)
end

local function Sparks(pos, color, count)
	local p = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = pos,
	}, Workspace)
	local pe = new("ParticleEmitter", {
		Color = ColorSequence.new(color, WHITE),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Lifetime = NumberRange.new(0.5, 1.0),
		Speed = NumberRange.new(12, 26),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		LightEmission = 1,
		Drag = 4,
	}, p)
	pe:Emit(count or 28)
	Debris:AddItem(p, 1.6)
end

local function Pillar(feet, color)
	local pl = new("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = 0.1,
		Size = Vector3.new(3, 0.3, 3),
		Position = feet + Vector3.new(0, 0.2, 0),
	}, Workspace)
	TweenService:Create(
		pl,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.4, 40, 0.4), Position = feet + Vector3.new(0, 20, 0), Transparency = 1 }
	):Play()
	Debris:AddItem(pl, 0.7)
end

local function ScreenFlash()
	FlashFrame.BackgroundColor3 = WHITE:Lerp(T.second, 0.35)
	FlashFrame.BackgroundTransparency = 0.5
	tween(FlashFrame, { BackgroundTransparency = 1 }, 0.45)
end

local function TeleportFX(from, to, color)
	local f1 = from - Vector3.new(0, 3, 0)
	local f2 = to - Vector3.new(0, 3, 0)
	-- leaving
	Ring(f1, T.second, 22, 0.6)
	Pillar(f1, T.second)
	Sparks(from, T.second, 36)
	-- arriving
	Ring(f2, color, 28, 0.85)
	Pillar(f2, color)
	Sparks(to, color, 40)
	ScreenFlash()
end

--==================================================
-- TELEPORT PINS (1 pin, or Pin 1 + Pin 2 with Dup In)
--==================================================
local Pins = {}
local PIN_COLORS = { Color3.fromRGB(90, 210, 255), Color3.fromRGB(255, 110, 210) }

local function RefreshTPButtons()
	TPButton.Visible = Pins[1] ~= nil
	TP2Button.Visible = S.dupin and (Pins[2] ~= nil)
end

local function ClearPin(i)
	local p = Pins[i]
	if p then
		p.part:Destroy()
		Pins[i] = nil
	end
	RefreshTPButtons()
end

local function RefreshPinVisibility()
	for _, p in pairs(Pins) do
		p.part.Transparency = S.showpin and 0.2 or 1
		p.gui.Enabled = S.showpin
		p.hl.Enabled = S.showpin
	end
end

local function MakePin(i, pos, quiet)
	ClearPin(i)
	local color = PIN_COLORS[i]
	local feet = pos - Vector3.new(0, 3, 0)

	-- glowing beacon that grows out of the ground (only you can see it)
	local part = new("Part", {
		Name = "MS_Pin",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = S.showpin and 0.2 or 1,
		Size = Vector3.new(0.8, 0.2, 0.8),
		Position = feet + Vector3.new(0, 0.1, 0),
	}, Workspace)
	TweenService:Create(
		part,
		TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.8, 18, 0.8), Position = feet + Vector3.new(0, 9, 0) }
	):Play()

	-- visible through walls
	local hl = new("Highlight", {
		FillColor = color,
		OutlineColor = WHITE,
		FillTransparency = 0.4,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Adornee = part,
		Enabled = S.showpin,
	}, part)

	local gui = new("BillboardGui", {
		Size = UDim2.fromOffset(130, 24),
		StudsOffset = Vector3.new(0, 12, 0),
		AlwaysOnTop = true,
		Adornee = part,
		Enabled = S.showpin,
	}, part)

	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "PIN",
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextStrokeTransparency = 0.3,
	}, gui)

	Pins[i] = { pos = pos, feet = feet, part = part, gui = gui, hl = hl, label = label }

	if not quiet and S.tpeffect then
		Ring(feet, color, 22, 0.8)
		Sparks(pos, color, 30)
	end
	RefreshTPButtons()
end

local function SetPin()
	if not (Root and Root.Parent) then
		return false
	end
	MakePin(1, Root.Position, false)
	return true
end

local function TeleportTo(i)
	local pin = Pins[i]
	if not pin then
		return false, (i == 2 and not S.dupin) and "DUP IN OFF" or "NO PIN"
	end
	if not (Root and Root.Parent and Humanoid and Humanoid.Health > 0) then
		return false, "TRY AGAIN"
	end

	local from = Root.Position
	local to = pin.pos

	if S.tpeffect then
		TeleportFX(from, to, PIN_COLORS[i])
	end

	Root.CFrame = CFrame.new(to) * Root.CFrame.Rotation
	Root.AssemblyLinearVelocity = Vector3.zero
	Root.AssemblyAngularVelocity = Vector3.zero
	LockPos = to -- so Lock Fly does not pull you back

	-- Dup In: the spot you just left becomes Pin 2
	if S.dupin and i == 1 then
		MakePin(2, from, true)
	end
	return true
end

TPButton.Activated:Connect(function()
	TeleportTo(1)
end)
TP2Button.Activated:Connect(function()
	TeleportTo(2)
end)

-- live distance + number on the pin markers
table.insert(Conns, RunService.RenderStepped:Connect(function()
	if not (Root and Root.Parent and S.showpin) then return end
	for i, p in pairs(Pins) do
		local d = math.floor((Root.Position - p.pos).Magnitude + 0.5)
		p.label.Text = (S.dupin and ("PIN " .. i) or "PIN") .. "  " .. d .. "m"
	end
end))

-- ambient pulse rings at every pin
task.spawn(function()
	while GUI.Parent do
		task.wait(1.7)
		if S.showpin and S.animated then
			for i, p in pairs(Pins) do
				Ring(p.feet, PIN_COLORS[i], 9, 1.1)
			end
		end
	end
end)

--==================================================
-- AIMBOT + AUTO NEAR + AUTO ATTACK
--==================================================
local AimParams = RaycastParams.new()
AimParams.FilterType = Enum.RaycastFilterType.Exclude

local CurrentTarget = nil
local NearMode = false
local LastAttack = 0

local function RefreshCircle()
	Circle.Visible = S.aim and S.showfov
	Circle.Size = UDim2.fromOffset(S.aimfov * 2, S.aimfov * 2)
end

local function aimPart(char)
	if S.aimhead then
		return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function isVisible(char, part)
	local cam = Workspace.CurrentCamera
	local ignore = { char }
	if Character then
		table.insert(ignore, Character)
	end
	AimParams.FilterDescendantsInstances = ignore
	local origin = cam.CFrame.Position
	return Workspace:Raycast(origin, part.Position - origin, AimParams) == nil
end

-- player inside the aim circle
local function evaluateCircle(p, maxDist)
	if p == Player then return nil end
	if S.teamcheck and p.Team ~= nil and p.Team == Player.Team then return nil end

	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local part = char and aimPart(char)
	if not (hum and part and hum.Health > 0) then return nil end

	local cam = Workspace.CurrentCamera
	local pos, onScreen = cam:WorldToViewportPoint(part.Position)
	if not onScreen then return nil end

	local center = cam.ViewportSize / 2
	local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
	if d > maxDist then return nil end

	if S.wallcheck and not isVisible(char, part) then return nil end
	return part, d
end

-- player within range (studs) of me
local function evaluateNear(p, range)
	if p == Player then return nil end
	if S.teamcheck and p.Team ~= nil and p.Team == Player.Team then return nil end
	if not (Root and Root.Parent) then return nil end

	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local part = char and aimPart(char)
	if not (hum and root and part and hum.Health > 0) then return nil end

	local d = (root.Position - Root.Position).Magnitude
	if d > range then return nil end

	if S.wallcheck and not isVisible(char, part) then return nil end
	return part, d
end

local function nearestWithin(range)
	local best, bestPlayer = math.huge, nil
	for _, p in ipairs(Players:GetPlayers()) do
		local pt, d = evaluateNear(p, range)
		if pt and d < best then
			best = d
			bestPlayer = p
		end
	end
	return bestPlayer
end

RunService:BindToRenderStep("MagmaAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not (S.aim or S.autonear) then
		CurrentTarget = nil
		NearMode = false
		return
	end

	local cam = Workspace.CurrentCamera
	if not cam then return end

	local prev = CurrentTarget
	local target, part, near = nil, nil, false

	-- 1) auto near: anyone close to me gets locked first
	if S.autonear then
		if prev and NearMode then
			local pt = evaluateNear(prev, S.nearrange * 1.2)
			if pt then
				target, part = prev, pt
			end
		end
		if not target then
			local best = math.huge
			for _, p in ipairs(Players:GetPlayers()) do
				local pt, d = evaluateNear(p, S.nearrange)
				if pt and d < best then
					best = d
					target, part = p, pt
				end
			end
		end
		near = (target ~= nil)
	end

	-- 2) aimbot circle (sticky lock)
	if not target and S.aim then
		if prev and not NearMode then
			local pt = evaluateCircle(prev, S.aimfov * 1.4)
			if pt then
				target, part = prev, pt
			end
		end
		if not target then
			local best = math.huge
			for _, p in ipairs(Players:GetPlayers()) do
				local pt, d = evaluateCircle(p, S.aimfov)
				if pt and d < best then
					best = d
					target, part = p, pt
				end
			end
		end
	end

	NearMode = near
	CurrentTarget = target

	if Circle.Visible then
		CircleStroke.Color = target and T.second or T.accent
	end
	if not (target and part) then return end

	-- lead moving targets (+ half of your ping)
	local pingExtra = math.clamp(PingMs / 1000 * 0.5, 0, 0.15)
	local aimPos = part.Position + part.AssemblyLinearVelocity * (S.prediction + pingExtra)
	local goal = CFrame.lookAt(cam.CFrame.Position, aimPos)

	local strength = S.aimstrength * (near and 1.4 or 1)
	if strength >= 60 then
		cam.CFrame = goal
	else
		local alpha = 1 - math.exp(-strength * dt)
		cam.CFrame = cam.CFrame:Lerp(goal, alpha)
	end
end)

-- auto attack: swings your tool fast at anyone inside attack range
local function getTool()
	if not Character then return nil end
	local tool = Character:FindFirstChildOfClass("Tool")
	if tool then return tool end
	if S.autoequip and Humanoid then
		local bp = Player:FindFirstChildOfClass("Backpack")
		local t = bp and bp:FindFirstChildOfClass("Tool")
		if t then
			Humanoid:EquipTool(t)
		end
	end
	return nil
end

table.insert(Conns, RunService.Heartbeat:Connect(function()
	if not S.autoattack then return end
	local now = os.clock()
	if now - LastAttack < S.attackrate then return end
	if not (Character and Humanoid and Humanoid.Health > 0 and Root) then return end

	if not nearestWithin(S.attackrange) then return end

	local tool = getTool()
	if tool then
		LastAttack = now
		pcall(function()
			tool:Activate()
		end)
	end
end))
--==================================================
-- PAGES CONTENT: MAIN, VISUALS, AIM, TELEPORT, SETTINGS
--==================================================
local function ApplyTransparency()
	local tr = S.transparent and 0.45 or 0
	Main.BackgroundTransparency = tr
	Galaxy.BackgroundTransparency = tr
end

local function ApplyAnimated()
	for _, tw in ipairs(Anims) do
		pcall(function()
			if S.animated then
				tw:Play()
			else
				tw:Pause()
			end
		end)
	end
	for _, d in pairs(Tracked) do
		if d.pulse then
			pcall(function()
				if S.animated then
					d.pulse:Play()
				else
					d.pulse:Pause()
				end
			end)
		end
	end
end

local function ApplyMinKey(keyName)
	local ok, kc = pcall(function()
		return Enum.KeyCode[keyName]
	end)
	if ok and kc then
		MinimizeKey = kc
	end
end

local function ApplyAllSettings()
	Loading = true
	for k, fn in pairs(Reg) do
		if S[k] ~= nil then
			pcall(fn, S[k])
		end
	end
	RefreshESP()
	RefreshFly()
	ApplyMovement()
	SetAntiStun(S.speedon)
	RefreshCircle()
	RefreshPinVisibility()
	RefreshTPButtons()
	ApplyTransparency()
	ApplyAnimated()
	ApplyMinKey(S.minkey)
	Loading = false
end

local function LoadSnapshot(snap)
	if type(snap) ~= "table" then return false end
	for k, v in pairs(Defaults) do
		if k ~= "autosave" then
			S[k] = (snap[k] ~= nil) and snap[k] or v
		end
	end
	if computeTheme(S.theme) then
		ApplyTheme()
	end
	ApplyAllSettings()
	return true
end

-- MAIN PAGE
makeSection(MainPage, "MOVEMENT")
makeToggle(MainPage, "fly", "Fly", "Toggle free flight with UP/DOWN pad", function()
	RefreshFly()
end)
makeToggle(MainPage, "lockfly", "Lock Fly", "Force position each frame to resist push/fling", function()
	if S.fly then
		StartFly()
	end
end)
makeBox(MainPage, "flyspeed", "Fly Speed", "Flight velocity in studs/sec (min 1)", numParse(1), function() end)

makeToggle(MainPage, "speedon", "Speed Hack", "Keep custom walk speed and resist slow/stun", function(v)
	SetAntiStun(v)
	ApplyMovement()
end)
makeBox(MainPage, "walkspeed", "Walk Speed", "Target walk speed in studs/sec (min 0)", numParse(0), function()
	ApplyMovement()
end)

makeToggle(MainPage, "jumpon", "Jump Power", "Keep custom jump power enabled", function()
	ApplyMovement()
end)
makeBox(MainPage, "jumppower", "Jump Power Value", "Target jump power (min 0)", numParse(0), function()
	ApplyMovement()
end)

makeToggle(MainPage, "noclip", "Noclip", "Disable character collisions and cap push velocity", function() end)

-- VISUALS PAGE
makeSection(VisualsPage, "PLAYER ESP")
makeToggle(VisualsPage, "esp", "Master ESP", "Enable ESP visuals on other players", function()
	RefreshESP()
end)
makeToggle(VisualsPage, "chams", "Chams", "Highlight player characters through walls", function()
	RefreshESP()
end)
makeToggle(VisualsPage, "box", "Box ESP", "Show 3D bounding box around players", function()
	RefreshESP()
end)
makeToggle(VisualsPage, "hpbar", "HP Bar & Health", "Show health bar and HP numbers", function()
	RefreshESP()
end)
makeToggle(VisualsPage, "names", "Names", "Show player display names above head", function()
	RefreshESP()
end)
makeToggle(VisualsPage, "dist", "Distance", "Show distance in studs/meters on info tag", function()
	RefreshESP()
end)
makeToggle(VisualsPage, "tracers", "Tracers", "Draw lines from bottom center to players", function()
	RefreshESP()
end)

-- AIM PAGE
makeSection(AimPage, "AIMBOT & COMBAT")
makeToggle(AimPage, "aim", "Aimbot", "Smoothly aim camera toward targets in FOV circle", function()
	RefreshCircle()
end)
makeToggle(AimPage, "showfov", "Show FOV Circle", "Display aimbot FOV circle at screen center", function()
	RefreshCircle()
end)
makeBox(AimPage, "aimfov", "FOV Radius", "Aim circle radius in pixels (min 10)", numParse(10), function()
	RefreshCircle()
end)
makeBox(AimPage, "aimstrength", "Aim Strength", "Tracking speed (60+ is instant lock, min 1)", numParse(1), function() end)
makeBox(AimPage, "prediction", "Prediction", "Target velocity lead time in seconds (min 0)", numParse(0), function() end)
makeToggle(AimPage, "aimhead", "Aim Head", "Target Head first instead of HumanoidRootPart", function() end)
makeToggle(AimPage, "wallcheck", "Wall Check", "Only target players visible with clear line of sight", function() end)
makeToggle(AimPage, "teamcheck", "Team Check", "Ignore players on the same team", function() end)

makeSection(AimPage, "AUTO NEAR & AUTO ATTACK")
makeToggle(AimPage, "autonear", "Auto Near", "Prioritize locking onto nearest target in range", function() end)
makeBox(AimPage, "nearrange", "Near Range", "Auto-near lock radius in studs (min 1)", numParse(1), function() end)
makeToggle(AimPage, "autoattack", "Auto Attack", "Automatically activate equipped tool in range", function() end)
makeBox(AimPage, "attackrange", "Attack Range", "Auto-attack distance in studs (min 1)", numParse(1), function() end)
makeBox(AimPage, "attackrate", "Attack Delay", "Seconds between auto attacks (min 0.02)", numParse(0.02), function() end)
makeToggle(AimPage, "autoequip", "Auto Equip Tool", "Equip first tool from Backpack if none held", function() end)

-- TELEPORT PAGE
makeSection(TeleportPage, "TELEPORT PINS")
makeButton(TeleportPage, "Set Pin 1", "Save your current position as Pin 1", "SET PIN", function()
	if SetPin() then
		Toast("Pin 1 set")
		return "SET!"
	end
	return "NO CHAR"
end)
makeButton(TeleportPage, "Teleport to Pin 1", "Warp to Pin 1 (creates Pin 2 if Dup In is on)", "TP PIN 1", function()
	local ok, err = TeleportTo(1)
	if ok then
		Toast("Teleported to Pin 1")
		return "WARPED!"
	end
	return err or "FAILED"
end)
makeButton(TeleportPage, "Teleport to Pin 2", "Warp to Pin 2 when Dup In is active", "TP PIN 2", function()
	local ok, err = TeleportTo(2)
	if ok then
		Toast("Teleported to Pin 2")
		return "WARPED!"
	end
	return err or "FAILED"
end)
makeButton(TeleportPage, "Clear Pins", "Remove active teleport pins", "CLEAR", function()
	ClearPin(1)
	ClearPin(2)
	Toast("Pins cleared")
	return "CLEARED"
end)

makeSection(TeleportPage, "TELEPORT OPTIONS")
makeToggle(TeleportPage, "showpin", "Show Pin Beacons", "Display glowing pin markers and distance tags", function()
	RefreshPinVisibility()
end)
makeToggle(TeleportPage, "tpeffect", "Teleport Effects", "Play rings, sparks, pillars, and screen flash", function() end)
makeToggle(TeleportPage, "dupin", "Dup In (Pin 2)", "Place Pin 2 at your previous spot when using Pin 1", function()
	RefreshTPButtons()
end)

-- SETTINGS PAGE
makeSection(SettingsPage, "APPEARANCE & CONTROLS")
makeBox(SettingsPage, "theme", "Theme Hex", "6-digit hex color like #8C5AFF", hexParse, function(hex)
	if computeTheme(hex) then
		ApplyTheme()
	end
end)
makeToggle(SettingsPage, "animated", "Animations", "Enable UI color pulses, tweens, and pin rings", function()
	ApplyAnimated()
end)
makeToggle(SettingsPage, "transparent", "Transparent Window", "Make main window background semi-transparent", function()
	ApplyTransparency()
end)
makeBox(SettingsPage, "minkey", "Minimize Key", "Enum.KeyCode name (e.g. LeftControl, RightShift)", keyParse, function(k)
	ApplyMinKey(k)
end)

makeSection(SettingsPage, "CONFIG & CLEANUP")
makeToggle(SettingsPage, "autosave", "Auto Save", "Save settings automatically to config/memory", function(v)
	Store.autosave = v
	Store.current = Snapshot()
	writeStore()
end)
makeButton(SettingsPage, "Save Config", "Save current settings to slot/file now", "SAVE", function()
	Store.current = Snapshot()
	Store.slots[1] = Snapshot()
	local saved = writeStore()
	Toast(saved and "Config saved to file" or "Config saved for session")
	return saved and "SAVED!" or "CACHED!"
end)
makeButton(SettingsPage, "Load Config", "Restore saved settings if available", "LOAD", function()
	local d = readStore()
	if d then
		Store = d
	end
	local snap = Store.current or Store.slots[1]
	if snap and LoadSnapshot(snap) then
		Toast("Config loaded")
		return "LOADED!"
	end
	return "NONE"
end)
makeButton(SettingsPage, "Reset Defaults", "Restore all settings to default values", "RESET", function()
	LoadSnapshot(Defaults)
	Toast("Defaults restored")
	return "RESET!"
end)
makeButton(SettingsPage, "Unload Script", "Destroy GUI and clean up connections/loops", "UNLOAD", function()
	StopFly()
	ClearPin(1)
	ClearPin(2)
	for p in pairs(Tracked) do
		RemoveESP(p)
	end
	for _, c in ipairs(MoveConns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(MoveConns)
	for _, c in ipairs(Conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(Conns)
	if ESPConn then
		pcall(function() ESPConn:Disconnect() end)
	end
	pcall(function()
		RunService:UnbindFromRenderStep("MagmaAim")
	end)
	for _, tw in ipairs(Anims) do
		pcall(function() tw:Cancel() end)
	end
	table.clear(Anims)
	if GUI then
		GUI:Destroy()
	end
	return "DONE"
end)

CloseBtn.Activated:Connect(function()
	StopFly()
	ClearPin(1)
	ClearPin(2)
	for p in pairs(Tracked) do
		RemoveESP(p)
	end
	for _, c in ipairs(MoveConns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(MoveConns)
	for _, c in ipairs(Conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(Conns)
	if ESPConn then
		pcall(function() ESPConn:Disconnect() end)
	end
	pcall(function()
		RunService:UnbindFromRenderStep("MagmaAim")
	end)
	for _, tw in ipairs(Anims) do
		pcall(function() tw:Cancel() end)
	end
	table.clear(Anims)
	if GUI then
		GUI:Destroy()
	end
end)

--==================================================
-- INITIALIZE CHARACTER, PAGE & SAVED STATE
--==================================================
if Player.Character then
	task.spawn(SetupCharacter, Player.Character)
end
table.insert(Conns, Player.CharacterAdded:Connect(SetupCharacter))

if Store.autosave and Store.current then
	LoadSnapshot(Store.current)
else
	ApplyAllSettings()
end

OpenPage("Main")
SetOpen(true)
