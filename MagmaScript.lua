--==================================================
-- MAGMASCRIPT
-- LocalScript: StarterPlayer > StarterPlayerScripts
--==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

pcall(function()
	RunService:UnbindFromRenderStep("MagmaAim")
end)
local oldGui = PlayerGui:FindFirstChild("MagmaScript")
if oldGui then oldGui:Destroy() end

-- STATE
local ESPOn = false
local ChamsOn = true
local BoxOn = true
local HPBarOn = true
local NamesOn = true
local DistOn = true
local TracersOn = false

local FlyOn = false
local LockOn = false
local FlySpeed = 60        -- type any number you want, no limit

local AimOn = false
local ShowFOV = true
local TeamCheck = true
local WallCheck = true
local AimHead = true
local AimFOV = 70          -- small circle
local AimStrength = 35     -- 60 or more = instant snap
local Prediction = 0.06    -- leads moving targets (seconds)

local Animated = true
local MinimizeKey = Enum.KeyCode.LeftControl

-- COLORS (galaxy)
local ACCENT = Color3.fromRGB(140, 90, 255)
local CYAN = Color3.fromRGB(90, 210, 255)
local PINK = Color3.fromRGB(255, 110, 210)
local BG = Color3.fromRGB(8, 6, 22)
local CARD = Color3.fromRGB(24, 17, 58)
local OFF = Color3.fromRGB(70, 62, 108)
local WHITE = Color3.fromRGB(245, 247, 255)
local MUTED = Color3.fromRGB(160, 154, 200)

local HP_GREEN = Color3.fromRGB(0, 230, 90)
local HP_YELLOW = Color3.fromRGB(255, 225, 40)
local HP_ORANGE = Color3.fromRGB(255, 140, 0)
local HP_RED = Color3.fromRGB(255, 45, 45)

--==================================================
-- HELPERS
--==================================================
local Anims = {}
local Conns = {}

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

--==================================================
-- GUI ROOT
--==================================================
local GUI = new("ScreenGui", {
	Name = "MagmaScript",
	ResetOnSpawn = false,
	DisplayOrder = 999,
	IgnoreGuiInset = true,
}, PlayerGui)

local TracerLayer = new("Frame", {
	Name = "Tracers",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, GUI)

-- Aim circle (small, center of screen)
local Circle = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(AimFOV * 2, AimFOV * 2),
	BackgroundTransparency = 1,
	Visible = false,
}, GUI)
round(Circle, 1000)
local CircleStroke = new("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.2 }, Circle)

-- M icon (fixed, can't be moved)
local Icon = new("TextButton", {
	Size = UDim2.fromOffset(48, 48),
	Position = UDim2.new(0, 14, 0.5, -24),
	BackgroundColor3 = WHITE,
	Text = "",
	AutoButtonColor = false,
}, GUI)
round(Icon, 14)
new("UIGradient", {
	Color = ColorSequence.new(ACCENT, Color3.fromRGB(50, 90, 230)),
	Rotation = 45,
}, Icon)
local IconStroke = new("UIStroke", { Color = CYAN, Thickness = 2, Transparency = 0.15 }, Icon)
loop(IconStroke, { Color = PINK }, 1.6)
new("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "M",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBlack,
	TextSize = 26,
}, Icon)

-- Fly UP / DOWN pad (only visible while flying)
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
		BackgroundColor3 = BG,
		BackgroundTransparency = 0.1,
		Text = text,
		TextColor3 = CYAN,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		AutoButtonColor = false,
	}, FlyPad)
	round(b, 33)
	new("UIStroke", { Color = ACCENT, Thickness = 2 }, b)

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
	Position = UDim2.fromScale(0.54, 0.5),
	Size = UDim2.fromScale(0.58, 0.7),
	BackgroundColor3 = BG,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, GUI)
round(Main, 10)
local Constraint = new("UISizeConstraint", {
	MinSize = Vector2.new(400, 250),
	MaxSize = Vector2.new(700, 440),
}, Main)
local MainScale = new("UIScale", { Scale = 0 }, Main)
local MainStroke = new("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.1 }, Main)
loop(MainStroke, { Color = CYAN }, 3)

-- galaxy background
local Galaxy = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, Main)
round(Galaxy, 10)

local GalaxyGradient = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 12, 64)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(7, 5, 24)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 15, 88)),
	}),
}, Galaxy)
spin(GalaxyGradient, { Rotation = 360 }, 24)

local function nebula(color, size, x, y, dx, dy, t)
	local n = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(x, y),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
	}, Galaxy)
	round(n, 1000)
	loop(n, { Position = UDim2.fromScale(x + dx, y + dy) }, t)
end
nebula(Color3.fromRGB(130, 50, 220), 260, -0.1, 0.0, 0.25, 0.1, 9)
nebula(Color3.fromRGB(40, 110, 255), 240, 0.55, 0.45, -0.2, -0.15, 11)
nebula(Color3.fromRGB(255, 80, 190), 180, 0.2, 0.65, 0.3, -0.1, 13)

for i = 1, 35 do
	local size = math.random(1, 3)
	local star = new("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = UDim2.fromScale(math.random(2, 98) / 100, math.random(2, 98) / 100),
		BackgroundColor3 = (i % 5 == 0) and CYAN or WHITE,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, Galaxy)
	round(star, 2)
	loop(star, { BackgroundTransparency = 0.9 }, 0.8 + math.random() * 1.8, math.random() * 2)
end

task.spawn(function()
	while GUI.Parent do
		task.wait(2.5 + math.random() * 4)
		if GUI.Parent and Animated and Main.Visible then
			local sx = math.random(0, 60) / 100
			local s = new("Frame", {
				Size = UDim2.fromOffset(38, 2),
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
	Size = UDim2.new(1, 0, 0, 38),
	BackgroundColor3 = Color3.fromRGB(4, 3, 14),
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
}, Main)
round(TitleBar, 10)

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
	Text = "MagmaScript",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
}, TitleLeft)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.6, CYAN),
		ColorSequenceKeypoint.new(1, PINK),
	}),
}, Title)

-- ms checker
local PingPill = new("Frame", {
	LayoutOrder = 2,
	Size = UDim2.fromOffset(58, 20),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
}, TitleLeft)
round(PingPill, 10)
new("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.5 }, PingPill)

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
	Text = "Magma Link: Costom",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
}, TitleLeft)
local LinkGradient = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, ACCENT),
		ColorSequenceKeypoint.new(0.5, CYAN),
		ColorSequenceKeypoint.new(1, PINK),
	}),
}, LinkText)
spin(LinkGradient, { Rotation = 360 }, 4)

-- window buttons (drawn with frames)
local function ctrlButton(x, hoverColor, draw)
	local b = new("TextButton", {
		Position = UDim2.new(1, x, 0, 0),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = hoverColor,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, TitleBar)
	draw(b)
	b.MouseEnter:Connect(function()
		tween(b, { BackgroundTransparency = 0.6 }, 0.12)
	end)
	b.MouseLeave:Connect(function()
		tween(b, { BackgroundTransparency = 1 }, 0.12)
	end)
	return b
end

local MinBtn = ctrlButton(-114, ACCENT, function(b)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(11, 2),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, b)
end)

local MaxBtn = ctrlButton(-76, ACCENT, function(b)
	local sq = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
	}, b)
	new("UIStroke", { Color = WHITE, Thickness = 1.5 }, sq)
end)

local CloseBtn = ctrlButton(-38, HP_RED, function(b)
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
	Position = UDim2.fromOffset(0, 38),
	Size = UDim2.new(1, 0, 1, -38),
	BackgroundTransparency = 1,
}, Main)

local Sidebar = new("ScrollingFrame", {
	Size = UDim2.new(0, 148, 1, 0),
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

new("Frame", {
	Position = UDim2.fromOffset(148, 6),
	Size = UDim2.new(0, 1, 1, -12),
	BackgroundColor3 = ACCENT,
	BackgroundTransparency = 0.7,
	BorderSizePixel = 0,
}, Body)

-- profile card
local Profile = new("Frame", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundColor3 = CARD,
	BackgroundTransparency = 0.35,
	BorderSizePixel = 0,
}, Sidebar)
round(Profile, 8)
new("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.65 }, Profile)

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
	Text = "MagmaScript",
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
	BackgroundColor3 = CARD,
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
new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, SearchBox)
local SearchStroke = new("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.65 }, SearchBox)
SearchBox.Focused:Connect(function()
	tween(SearchStroke, { Transparency = 0 }, 0.12)
end)
SearchBox.FocusLost:Connect(function()
	tween(SearchStroke, { Transparency = 0.65 }, 0.12)
end)

-- content area
local Content = new("Frame", {
	Position = UDim2.fromOffset(149, 0),
	Size = UDim2.new(1, -149, 1, 0),
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
-- PAGES + TABS + ROWS
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
		ScrollBarImageColor3 = ACCENT,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, Content)
	new("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	new("UIPadding", {
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 12),
	}, frame)

	local page = { frame = frame, items = {}, order = 0 }
	Pages[name] = page
	return page
end

local MainPage = newPage("Main")
local VisualsPage = newPage("Visuals")
local AimPage = newPage("Aim")
local SettingsPage = newPage("Settings")

local function OpenPage(name)
	ActivePage = name
	for n, page in pairs(Pages) do
		page.frame.Visible = (n == name)
	end
	for n, t in pairs(Tabs) do
		local on = (n == name)
		tween(t.button, { BackgroundTransparency = on and 0.75 or 1 }, 0.15)
		tween(t.label, { TextColor3 = on and WHITE or MUTED }, 0.15)
		tween(t.bar, { Size = UDim2.fromOffset(3, on and 16 or 0) }, 0.15)
	end
	PageTitle.Text = name
	Pages[name].frame.CanvasPosition = Vector2.zero
end

for i, name in ipairs({ "Main", "Visuals", "Aim", "Settings" }) do
	local button = new("TextButton", {
		LayoutOrder = 10 + i,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, Sidebar)
	round(button, 6)

	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(3, 0),
		BackgroundColor3 = CYAN,
		BorderSizePixel = 0,
	}, button)
	round(bar, 2)

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

-- row base (title + description)
local function newRow(page, class, title, sub)
	page.order += 1
	local row = new(class, {
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		LayoutOrder = page.order,
	}, page.frame)
	if class == "TextButton" then
		row.Text = ""
		row.AutoButtonColor = false
	end
	round(row, 6)
	new("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.8 }, row)

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

	new("TextLabel", {
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

	table.insert(page.items, { frame = row, title = (title .. " " .. sub):lower() })
	return row
end

-- switch row
local function makeToggle(page, title, sub, default, onChange)
	local state = default
	local row = newRow(page, "TextButton", title, sub)

	local track = new("Frame", {
		Size = UDim2.fromOffset(42, 22),
		Position = UDim2.new(1, -54, 0.5, -11),
		BackgroundColor3 = state and ACCENT or OFF,
		BorderSizePixel = 0,
	}, row)
	round(track, 11)

	local knob = new("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)
	round(knob, 8)

	row.Activated:Connect(function()
		state = not state
		tween(track, { BackgroundColor3 = state and ACCENT or OFF })
		tween(knob, { Position = state and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3) })
		onChange(state)
	end)
end

-- input row (type a value). parse(text) returns the value or nil if invalid
local function makeBox(page, title, sub, default, parse, onChange)
	local current = default
	local row = newRow(page, "Frame", title, sub)

	local box = new("TextBox", {
		Position = UDim2.new(1, -110, 0.5, -14),
		Size = UDim2.fromOffset(98, 28),
		BackgroundColor3 = Color3.fromRGB(10, 8, 30),
		BackgroundTransparency = 0.2,
		TextColor3 = WHITE,
		PlaceholderColor3 = MUTED,
		Text = tostring(current),
		ClearTextOnFocus = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
	}, row)
	round(box, 6)
	local stroke = new("UIStroke", { Color = ACCENT, Thickness = 1, Transparency = 0.6 }, box)

	box.Focused:Connect(function()
		tween(stroke, { Transparency = 0 }, 0.12)
	end)
	box.FocusLost:Connect(function()
		tween(stroke, { Transparency = 0.6 }, 0.12)
		local v = parse(box.Text)
		if v ~= nil then
			current = v
			onChange(v)
		end
		box.Text = tostring(current)
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

--==================================================
-- WINDOW OPEN / CLOSE / MAXIMIZE
--==================================================
local WindowOpen = true

local function SetOpen(v)
	WindowOpen = v
	if v then
		Main.Visible = true
		TweenService:Create(
			MainScale,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
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
	Constraint.MaxSize = Maxed and Vector2.new(4000, 4000) or Vector2.new(700, 440)
	tween(Main, {
		Size = Maxed and UDim2.fromScale(0.9, 0.88) or UDim2.fromScale(0.58, 0.7),
		Position = Maxed and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.54, 0.5),
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
task.spawn(function()
	while GUI.Parent do
		local ok, v = pcall(function()
			return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		local ms = ok and math.floor(v + 0.5) or 0
		PingText.Text = ms .. " ms"
		PingText.TextColor3 = ms < 80 and HP_GREEN or (ms < 150 and HP_YELLOW or HP_RED)
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
	local pulse = TweenService:Create(
		hl,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ FillTransparency = 0.8 }
	)
	pulse:Play()
	if not Animated then pulse:Pause() end

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

	local d = { hl = hl, box = box, info = info, tracer = tracer, pulse = pulse, root = root, dist = 0 }

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
		if DistOn then
			text ..= "  |  " .. d.dist .. "m"
		end
		infoLabel.Text = text
	end

	d.refresh = function()
		hl.Enabled = ESPOn and ChamsOn
		box.Enabled = ESPOn and (BoxOn or HPBarOn)
		boxFrame.Visible = BoxOn
		hpBg.Visible = HPBarOn
		info.Enabled = ESPOn and (NamesOn or HPBarOn or DistOn)
		nameLabel.Visible = NamesOn
		infoLabel.Visible = HPBarOn or DistOn
		if not (ESPOn and TracersOn) then
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
	if not ESPOn then return end

	local cam = Workspace.CurrentCamera
	if not cam then return end

	local vp = cam.ViewportSize
	local origin = Vector2.new(vp.X / 2, vp.Y)
	local camPos = cam.CFrame.Position

	for _, d in pairs(Tracked) do
		local root = d.root
		if root and root.Parent then
			if DistOn then
				local dist = math.floor((root.Position - camPos).Magnitude + 0.5)
				if dist ~= d.dist then
					d.dist = dist
					d.update()
				end
			end

			if TracersOn then
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
-- FLY + LOCK FLY
--==================================================
local Character, Humanoid, Root
local FlyConn, FlyAttach, FlyVel, FlyAlign
local LockPos
local CollideCache = {}
local CollideOff = false

local function SetNoCollide(on)
	if on == CollideOff then return end
	CollideOff = on
	if on then
		CollideCache = {}
		if Character then
			for _, p in ipairs(Character:GetDescendants()) do
				if p:IsA("BasePart") then
					CollideCache[p] = p.CanCollide
					p.CanCollide = false
				end
			end
		end
	else
		for p, v in pairs(CollideCache) do
			if p and p.Parent then
				p.CanCollide = v
			end
		end
		CollideCache = {}
	end
end

local function StopFly()
	if FlyConn then FlyConn:Disconnect() FlyConn = nil end
	if FlyVel then FlyVel:Destroy() FlyVel = nil end
	if FlyAlign then FlyAlign:Destroy() FlyAlign = nil end
	if FlyAttach then FlyAttach:Destroy() FlyAttach = nil end
	SetNoCollide(false)
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

		local vel = dir * FlySpeed

		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		local yaw = CFrame.lookAt(Vector3.zero, flat.Unit)

		FlyVel.VectorVelocity = vel
		FlyAlign.CFrame = yaw

		if LockOn then
			-- LOCK FLY: position is forced every frame, so nobody can push or fling me
			SetNoCollide(true)
			LockPos = LockPos + vel * dt
			Root.CFrame = CFrame.new(LockPos) * yaw
			Root.AssemblyLinearVelocity = vel
			Root.AssemblyAngularVelocity = Vector3.zero
		else
			SetNoCollide(false)
			LockPos = Root.Position
		end
	end)
end

local function RefreshFly()
	if FlyOn then
		StartFly()
	else
		StopFly()
	end
end

local function SetupCharacter(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")
	Root = char:WaitForChild("HumanoidRootPart")
	CollideOff = false
	CollideCache = {}

	Humanoid.Died:Connect(StopFly)

	if FlyOn then
		task.wait(0.3)
		StartFly()
	end
end

if Player.Character then
	task.spawn(SetupCharacter, Player.Character)
end
Player.CharacterAdded:Connect(SetupCharacter)

--==================================================
-- AIMBOT (small circle, sticky lock, prediction, snap)
--==================================================
local AimParams = RaycastParams.new()
AimParams.FilterType = Enum.RaycastFilterType.Exclude

local CurrentTarget = nil

local function RefreshCircle()
	Circle.Visible = AimOn and ShowFOV
	Circle.Size = UDim2.fromOffset(AimFOV * 2, AimFOV * 2)
end

local function aimPart(char)
	if AimHead then
		return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	end
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
end

local function evaluate(p, maxDist)
	if p == Player then return nil end
	if TeamCheck and p.Team ~= nil and p.Team == Player.Team then return nil end

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

	if WallCheck then
		local ignore = { char }
		if Character then
			table.insert(ignore, Character)
		end
		AimParams.FilterDescendantsInstances = ignore
		local origin = cam.CFrame.Position
		if Workspace:Raycast(origin, part.Position - origin, AimParams) then
			return nil
		end
	end

	return part, d
end

RunService:BindToRenderStep("MagmaAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not AimOn then
		CurrentTarget = nil
		return
	end

	local cam = Workspace.CurrentCamera
	if not cam then return end

	-- stay locked on the current target while it is valid
	local part
	if CurrentTarget then
		part = evaluate(CurrentTarget, AimFOV * 2)
		if not part then
			CurrentTarget = nil
		end
	end

	-- otherwise pick the closest valid player to the center
	if not CurrentTarget then
		local bestDist = math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			local pt, d = evaluate(p, AimFOV)
			if pt and d < bestDist then
				bestDist = d
				CurrentTarget = p
				part = pt
			end
		end
	end

	CircleStroke.Color = CurrentTarget and CYAN or ACCENT
	if not (CurrentTarget and part) then return end

	local aimPos = part.Position + part.AssemblyLinearVelocity * Prediction
	local goal = CFrame.lookAt(cam.CFrame.Position, aimPos)

	if AimStrength >= 60 then
		cam.CFrame = goal
	else
		local alpha = 1 - math.exp(-AimStrength * dt)
		cam.CFrame = cam.CFrame:Lerp(goal, alpha)
	end
end)

--==================================================
-- THEME SETTINGS
--==================================================
local function SetAnimated(v)
	Animated = v
	for _, tw in ipairs(Anims) do
		if v then tw:Play() else tw:Pause() end
	end
	for _, d in pairs(Tracked) do
		if v then d.pulse:Play() else d.pulse:Pause() end
	end
end

local function SetTransparent(v)
	local t = v and 0.4 or 0
	Galaxy.BackgroundTransparency = t
	Main.BackgroundTransparency = t
end

--==================================================
-- CLEANUP
--==================================================
CloseBtn.Activated:Connect(function()
	GUI:Destroy()
end)

GUI.Destroying:Connect(function()
	pcall(function()
		RunService:UnbindFromRenderStep("MagmaAim")
	end)
	ESPConn:Disconnect()
	for _, c in ipairs(Conns) do
		c:Disconnect()
	end
	StopFly()
	for p in pairs(Tracked) do
		RemoveESP(p)
	end
end)

--==================================================
-- MENU ITEMS
--==================================================
-- MAIN
makeToggle(MainPage, "ESP", "players through walls: chams, box, HP, name", false, function(v)
	ESPOn = v
	RefreshESP()
end)

makeToggle(MainPage, "Fly", "move stick to fly where you look", false, function(v)
	FlyOn = v
	RefreshFly()
end)

makeToggle(MainPage, "Lock Fly", "nobody can move or fling you", false, function(v)
	LockOn = v
end)

makeBox(MainPage, "Fly Speed", "type any number, no limit", FlySpeed, numParse(0.01), function(v)
	FlySpeed = v
end)

makeToggle(MainPage, "Aimbot", "strong lock on heads inside the circle", false, function(v)
	AimOn = v
	if not v then CurrentTarget = nil end
	RefreshCircle()
end)

-- VISUALS
makeToggle(VisualsPage, "Chams", "glowing body, pulses, colored by HP", true, function(v)
	ChamsOn = v
	RefreshESP()
end)

makeToggle(VisualsPage, "Box", "box around each player", true, function(v)
	BoxOn = v
	RefreshESP()
end)

makeToggle(VisualsPage, "HP Bar", "side bar + HP number", true, function(v)
	HPBarOn = v
	RefreshESP()
end)

makeToggle(VisualsPage, "Names", "show player names", true, function(v)
	NamesOn = v
	RefreshESP()
end)

makeToggle(VisualsPage, "Distance", "show distance in meters", true, function(v)
	DistOn = v
	RefreshESP()
end)

makeToggle(VisualsPage, "Tracers", "line from the bottom of the screen", false, function(v)
	TracersOn = v
	RefreshESP()
end)

-- AIM
makeToggle(AimPage, "Show Circle", "draw the aim circle", true, function(v)
	ShowFOV = v
	RefreshCircle()
end)

makeToggle(AimPage, "Aim Head", "off = aim at the body", true, function(v)
	AimHead = v
end)

makeToggle(AimPage, "Team Check", "ignore your teammates", true, function(v)
	TeamCheck = v
end)

makeToggle(AimPage, "Wall Check", "only aim at players you can see", true, function(v)
	WallCheck = v
end)

makeBox(AimPage, "Aim Circle", "circle size, small = precise", AimFOV, numParse(10), function(v)
	AimFOV = v
	RefreshCircle()
end)

makeBox(AimPage, "Aim Strength", "60 or more = instant snap", AimStrength, numParse(0.1), function(v)
	AimStrength = v
end)

makeBox(AimPage, "Prediction", "lead for moving targets (seconds)", Prediction, numParse(0), function(v)
	Prediction = v
end)

-- SETTINGS
makeToggle(SettingsPage, "Animated Theme", "galaxy, stars and stroke animation", true, SetAnimated)

makeToggle(SettingsPage, "Transparency", "makes the interface transparent", false, SetTransparent)

makeBox(SettingsPage, "Minimize Bind", "PC key to hide / show the menu", "LeftControl", keyParse, function(name)
	MinimizeKey = Enum.KeyCode[name]
end)

--==================================================
-- START
--==================================================
OpenPage("Main")
SetOpen(true)

print("MAGMASCRIPT LOADED")
