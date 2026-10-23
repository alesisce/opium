--[[
	OpiumUI — librería de interfaz para Roblox
	Compacta, plana, esquinas de 4px. Sin dependencias.

	API rápida:
		local UI = require(ruta.al.modulo)

		local Win = UI.Window{
			Title = "Opium",
			Subtitle = "v1",
			Width = 400,          -- tamaño (o Size = UDim2)
			Height = 440,
			MinWidth = 340,
			MinHeight = 220,
			Resizable = true,
			AnimateTabs = true,   -- transición al cambiar de pestaña
			Position = UDim2.fromOffset(60, 60),
			ToggleKey = Enum.KeyCode.RightShift,

			-- Colores por ventana (todos opcionales):
			PrimaryColor = Color3.fromHex("#C25A52"),
			BgColor = Color3.fromHex("#141519"),
			HeaderColor = Color3.fromHex("#17181D"),
			SidebarColor = Color3.fromHex("#101114"),
			InputColor = Color3.fromHex("#101114"),
			RaisedColor = Color3.fromHex("#1B1D22"),
			HoverColor = Color3.fromHex("#23262C"),
			PressedColor = Color3.fromHex("#2A2D34"),
			BorderColor = Color3.fromHex("#262930"),
			TrackColor = Color3.fromHex("#2E3138"),
			TextColor = Color3.fromHex("#E7E8EA"),
			MutedColor = Color3.fromHex("#8B8F98"),
			DimColor = Color3.fromHex("#5B5F68"),
		}

		local Tab = Win:Tab("Main")
		local Sec = Tab:Section("Movement")

		-- Grupos de tabs en la sidebar:
		local group = Win:TabGroup("Settings")
		local tab2 = group:Tab("Audio")   -- aparece bajo "SETTINGS"
		tab2:SetAnimation(false)          -- sin transición en este tab
		-- Win:Tab("Suelto") sigue funcionando sin grupo

		local btn = Sec:Button("Texto", function() end)
		local tog = Sec:Toggle("Activo", true, function(state) end)
		local sli = Sec:Slider("Velocidad", 0, 200, 16, function(value) end)
		local inp = Sec:Input("Filtro", "escribe...", function(text) end)
		local dd  = Sec:Dropdown("Modo", {"A", "B"}, "A", function(value) end)
		local st  = Sec:Stat("FPS", "—")
		Sec:Label("Nota")
		Sec:Divider()

		-- Handles:
		tog:Set(false)          -- cambia el valor y dispara callback
		tog:Set(false, true)    -- cambia sin disparar
		tog:Get()
		st("60")                -- los handles son callables

		Sec:SetVisible(false)   -- oculta toda la sección

		-- Config (JSON en el workspace del executor):
		Win:GetValues()                    -- { ["Main/Movement/Activo"] = false, ... }
		Win:SetValues(datos, true)         -- true = disparar callbacks
		Win:SaveConfig("opium_config.json")
		Win:LoadConfig("opium_config.json")

		-- Notificaciones nativas (stack de 4, 2.6s por defecto):
		Win:Notify("Guardado")
		Win:Notify("Error al guardar", { Type = "error", Duration = 4 })
		Win:Notify("Cargado", 3)  -- duración en segundos

		-- Tema en vivo:
		Win:SetTheme{ PrimaryColor = Color3.fromHex("#6C8EBF") }
		Win:SetTheme(otraVentana)
		local tema = Win:GetTheme()

		Win:Toggle()
		Win:SetVisible(false)
		Win:SetSize(500, 600)
		Win:Destroy()

	Defaults globales: UI.Theme (cámbialos antes de crear la ventana).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- ── Tema ─────────────────────────────────────────────────────────────────────

local Theme = {
	radius = 4,

	ui = Color3.fromHex("#141519"),
	header = Color3.fromHex("#17181D"),
	sidebar = Color3.fromHex("#101114"),
	input = Color3.fromHex("#101114"),
	raised = Color3.fromHex("#1B1D22"),
	hover = Color3.fromHex("#23262C"),
	pressed = Color3.fromHex("#2A2D34"),
	border = Color3.fromHex("#262930"),
	track = Color3.fromHex("#2E3138"),

	text = Color3.fromHex("#E7E8EA"),
	muted = Color3.fromHex("#8B8F98"),
	dim = Color3.fromHex("#5B5F68"),
	accent = Color3.fromHex("#C25A52"),

	font = Enum.Font.GothamMedium,
	mono = Enum.Font.Code,
}

local UI = { Theme = Theme }

local NOTIFY_COLORS = {
	info = nil,
	success = Color3.fromHex("#7CB08A"),
	error = Color3.fromHex("#C96B63"),
	warning = Color3.fromHex("#C3A05C"),
}

-- Propiedades de color aceptadas por UI.Window -> clave interna del tema.
local COLOR_PROPS = {
	PrimaryColor = "accent",
	BgColor = "ui",
	HeaderColor = "header",
	SidebarColor = "sidebar",
	InputColor = "input",
	RaisedColor = "raised",
	HoverColor = "hover",
	PressedColor = "pressed",
	BorderColor = "border",
	TrackColor = "track",
	TextColor = "text",
	MutedColor = "muted",
	DimColor = "dim",
}

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function new(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or Theme.radius)
	c.Parent = inst
	return c
end

-- Esquinas independientes: topLeft, topRight, bottomRight, bottomLeft.
local function cornerSides(inst, topLeft, topRight, bottomRight, bottomLeft)
	local c = Instance.new("UICorner")
	c.TopLeftRadius = UDim.new(0, topLeft or 0)
	c.TopRightRadius = UDim.new(0, topRight or 0)
	c.BottomRightRadius = UDim.new(0, bottomRight or 0)
	c.BottomLeftRadius = UDim.new(0, bottomLeft or 0)
	c.Parent = inst
	return c
end

local function stroke(inst, color, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or Theme.border
	s.Thickness = thickness or 1
	s.Parent = inst
	return s
end

local function pad(inst, top, right, bottom, left)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
		Parent = inst,
	})
end

local function text(props, theme)
	theme = theme or Theme
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Font = props.Font or theme.font
	props.TextSize = props.TextSize or 12
	props.TextColor3 = props.TextColor3 or theme.text
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
	return new("TextLabel", props)
end

local function fire(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(callback, table.unpack(args, 1, args.n))
		if not ok then
			warn("[OpiumUI] " .. tostring(err))
		end
	end)
end

local function tween(inst, props, duration)
	local info = TweenInfo.new(duration or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(inst, info, props):Play()
end

local function row(parent, height)
	return new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Parent = parent,
	})
end

local function resolveTheme(props)
	local theme = {}
	for key, value in Theme do
		theme[key] = value
	end
	for prop, key in COLOR_PROPS do
		local value = props[prop]
		if value ~= nil then
			theme[key] = value
		end
	end
	return theme
end

-- Recoge solo colores de una tabla de props, de un tema o de otra ventana.
local function collectColors(input)
	local colors = {}
	if type(input) ~= "table" then
		return colors
	end
	if type(input.theme) == "table" then
		input = input.theme
	end
	for key, value in input do
		if typeof(value) == "Color3" then
			colors[COLOR_PROPS[key] or key] = value
		end
	end
	return colors
end

-- Repinta los descendientes sustituyendo los colores antiguos por los nuevos.
local function repaint(inst, remap)
	if inst:IsA("GuiObject") then
		local newBackground = remap[inst.BackgroundColor3:ToHex()]
		if newBackground then
			inst.BackgroundColor3 = newBackground
		end

		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			local newText = remap[inst.TextColor3:ToHex()]
			if newText then
				inst.TextColor3 = newText
			end
		end

		if inst:IsA("TextBox") then
			local newPlaceholder = remap[inst.PlaceholderColor3:ToHex()]
			if newPlaceholder then
				inst.PlaceholderColor3 = newPlaceholder
			end
		end

		if inst:IsA("ScrollingFrame") then
			local newScroll = remap[inst.ScrollBarImageColor3:ToHex()]
			if newScroll then
				inst.ScrollBarImageColor3 = newScroll
			end
		end

		local strokeInst = inst:FindFirstChildOfClass("UIStroke")
		if strokeInst then
			local newStroke = remap[strokeInst.Color:ToHex()]
			if newStroke then
				strokeInst.Color = newStroke
			end
		end
	end

	for _, child in inst:GetChildren() do
		repaint(child, remap)
	end
end

-- ── Handles ──────────────────────────────────────────────────────────────────

local Component = {}
Component.__index = Component

Component.__call = function(self, value, silent)
	self:Set(value, silent)
end

function Component:Get()
	return self._value
end

function Component:Set(value, silent)
	if self._apply then
		self._apply(value, silent and true or false)
	end
	return self
end

function Component:SetVisible(value)
	if self.instance then
		self.instance.Visible = value and true or false
	end
	return self
end

function Component:Destroy()
	if self.instance then
		self.instance:Destroy()
	end
end

local function makeHandle(instance, apply, value, kind)
	return setmetatable({
		instance = instance,
		kind = kind,
		_value = value,
		_apply = apply,
	}, Component)
end

-- ── Ventana ──────────────────────────────────────────────────────────────────

local Window, Tab, Section, TabGroup

Window = {}
Window.__index = Window

function UI.Window(props)
	props = props or {}
	local self = setmetatable({ _conns = {}, _tabs = {}, _components = {}, _keyCounts = {}, _sidebarOrder = 0, _notifications = {} }, Window)
	local theme = resolveTheme(props)
	self.theme = theme
	self._minWidth = props.MinWidth or 340
	self._minHeight = props.MinHeight or 220
	self._animateTabs = props.AnimateTabs ~= false

	-- Contenedor: CoreGui en ejecutores, PlayerGui en juegos normales.
	local parent
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			parent = hui
		end
	end
	if not parent then
		parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	local gui = new("ScreenGui", {
		Name = "OpiumUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = parent,
	})
	self.gui = gui

	local root = new("Frame", {
		Name = "Window",
		BackgroundColor3 = theme.ui,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromOffset(props.Width or 400, props.Height or 440),
		Position = props.Position or UDim2.fromOffset(60, 60),
		ClipsDescendants = true,
		Parent = gui,
	})
	corner(root, 8)
	stroke(root, theme.border)
	self.root = root

	-- Cabecera (28px) ---------------------------------------------------------
	local header = new("Frame", {
		Name = "Header",
		BackgroundColor3 = theme.header,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28),
		Parent = root,
	})
	cornerSides(header, 8, 8, 0, 0)

	text({
		Text = props.Title or "Opium",
		TextSize = 11,
		Size = UDim2.new(1, -110, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	}, theme)

	if props.Subtitle then
		text({
			Text = props.Subtitle,
			TextSize = 9,
			TextColor3 = theme.dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(0, 64, 1, 0),
			Position = UDim2.new(1, -94, 0, 0),
			Parent = header,
		}, theme)
	end

	local close = new("TextButton", {
		Text = "×",
		Font = theme.font,
		TextSize = 13,
		TextColor3 = theme.muted,
		BackgroundColor3 = theme.hover,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -24, 0, 5),
		Parent = header,
	})
	corner(close, 3)
	close.MouseEnter:Connect(function()
		tween(close, { BackgroundTransparency = 0, TextColor3 = theme.text }, 0.08)
	end)
	close.MouseLeave:Connect(function()
		tween(close, { BackgroundTransparency = 1, TextColor3 = theme.muted }, 0.08)
	end)
	close.Activated:Connect(function()
		root.Visible = false
	end)

	new("Frame", {
		BackgroundColor3 = theme.border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		Parent = header,
	})

	-- Arrastrar ---------------------------------------------------------------
	local dragging, dragStart, startPos
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	self:_track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
			local x = math.clamp(startPos.X.Offset + delta.X, 80 - root.AbsoluteSize.X, viewport.X - 80)
			local y = math.clamp(startPos.Y.Offset + delta.Y, 0, viewport.Y - 28)
			root.Position = UDim2.new(0, x, 0, y)
		end
	end))

	-- Redimensionar -----------------------------------------------------------
	if props.Resizable ~= false then
		local grip = new("Frame", {
			Name = "ResizeGrip",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.new(1, -22, 1, -22),
			Parent = root,
		})

		for index = 1, 3 do
			new("Frame", {
				BackgroundColor3 = theme.dim,
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(index * 4 + 2, 1),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -3, 1, -3 - (index - 1) * 4),
				Parent = grip,
			})
		end

		local resizing, resizeStart, startSize
		grip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				resizeStart = input.Position
				startSize = root.AbsoluteSize
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						resizing = false
					end
				end)
			end
		end)

		self:_track(UserInputService.InputChanged:Connect(function(input)
			if not resizing then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - resizeStart
				self:SetSize(startSize.X + delta.X, startSize.Y + delta.Y)
			end
		end))
	end

	-- Cuerpo ------------------------------------------------------------------
	local body = new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -28),
		Position = UDim2.fromOffset(0, 28),
		Parent = root,
	})

	local sidebar = new("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = theme.sidebar,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 125, 1, 0),
		Parent = body,
	})
	cornerSides(sidebar, 0, 0, 0, 8)

	new("Frame", {
		BackgroundColor3 = theme.border,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		Parent = sidebar,
	})

	local sidebarList = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = sidebar,
	})

	new("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebarList,
	})
	pad(sidebarList, 6, 6, 6, 6)

	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -125, 1, 0),
		Position = UDim2.fromOffset(125, 0),
		Parent = body,
	})

	self._sidebarList = sidebarList
	self._content = content

	-- Atajo de teclado --------------------------------------------------------
	if props.ToggleKey then
		self:_track(UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.KeyCode == props.ToggleKey and not UserInputService:GetFocusedTextBox() then
				root.Visible = not root.Visible
			end
		end))
	end

	return self
end

function Window:_track(connection)
	self._conns[#self._conns + 1] = connection
	return connection
end

function Window:_register(handle, path, label)
	local base = tostring(path or "") .. tostring(label or "")
	local count = (self._keyCounts[base] or 0) + 1
	self._keyCounts[base] = count
	handle.key = count > 1 and (base .. "#" .. count) or base
	handle.window = self
	self._components[#self._components + 1] = handle
	return handle
end

function Window:Toggle()
	self.root.Visible = not self.root.Visible
end

function Window:SetVisible(value)
	self.root.Visible = value and true or false
end

function Window:SetSize(width, height)
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	width = math.clamp(width, self._minWidth, viewport.X - 40)
	height = math.clamp(height, self._minHeight, viewport.Y - 40)
	self.root.Size = UDim2.fromOffset(width, height)
end

function Window:GetTheme()
	return self.theme
end

-- Acepta props de color (PrimaryColor, BgColor...), un tema o otra ventana.
function Window:SetTheme(input)
	local colors = collectColors(input)
	local theme = self.theme
	local remap = {}

	for key, value in colors do
		local old = theme[key]
		if typeof(old) == "Color3" then
			remap[old:ToHex()] = value
		end
		theme[key] = value
	end

	repaint(self.gui, remap)
end

-- Valores actuales de todos los controles (Stat queda fuera).
function Window:GetValues()
	local values = {}
	for _, handle in self._components do
		if handle.kind ~= "stat" and handle.key then
			values[handle.key] = handle:Get()
		end
	end
	return values
end

function Window:SetValues(values, fireCallbacks)
	if type(values) ~= "table" then
		return false
	end
	for _, handle in self._components do
		local value = values[handle.key]
		if value ~= nil and handle._apply then
			handle:Set(value, not fireCallbacks)
		end
	end
	return true
end

function Window:SaveConfig(path)
	path = path or "opium_config.json"
	local ok, err = pcall(function()
		writefile(path, HttpService:JSONEncode(self:GetValues()))
	end)
	return ok, err
end

function Window:LoadConfig(path, fireCallbacks)
	path = path or "opium_config.json"
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then
		return false, data
	end
	self:SetValues(data, fireCallbacks)
	return true
end

function Window:Destroy()
	for _, connection in self._conns do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self._conns)
	self.gui:Destroy()
end

function Window:_refreshTab(tab, animate)
	local theme = self.theme
	if tab._active then
		if animate then
			tween(tab.button, { BackgroundColor3 = theme.raised, BackgroundTransparency = 0 }, 0.12)
			tween(tab.label, { TextColor3 = theme.text }, 0.12)
		else
			tab.button.BackgroundColor3 = theme.raised
			tab.button.BackgroundTransparency = 0
			tab.label.TextColor3 = theme.text
		end
	else
		local transparency = tab._hover and 0.35 or 1
		if animate then
			tween(tab.button, {
				BackgroundColor3 = theme.hover,
				BackgroundTransparency = transparency,
			}, 0.12)
			tween(tab.label, { TextColor3 = theme.muted }, 0.12)
		else
			tab.button.BackgroundColor3 = theme.hover
			tab.button.BackgroundTransparency = transparency
			tab.label.TextColor3 = theme.muted
		end
	end
end

function Window:SetTabAnimation(value)
	self._animateTabs = value and true or false
	return self
end

function Window:_layoutNotifications()
	local count = #self._notifications
	for index, record in self._notifications do
		if record.frame then
			tween(record.frame, {
				Position = UDim2.new(1, -16, 1, -16 - (count - index) * 36),
			}, 0.12)
		end
	end
end

function Window:Notify(message, options)
	if type(options) == "number" then
		options = { Duration = options }
	end
	options = options or {}

	local theme = self.theme
	local duration = tonumber(options.Duration) or 2.6
	local kind = options.Type or "info"
	local accent = NOTIFY_COLORS[kind] or theme.muted

	if #self._notifications >= 4 then
		local oldest = self._notifications[1]
		if oldest and oldest.dismiss then
			oldest.dismiss()
		end
	end

	local toast = new("Frame", {
		Name = "Notification",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 16, 1, -16),
		Size = UDim2.new(0, 260, 0, 30),
		BackgroundColor3 = theme.raised,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = self.gui,
	})
	corner(toast)

	local toastStroke = stroke(toast, theme.border)
	toastStroke.Transparency = 1

	local bar = new("Frame", {
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, -12),
		Position = UDim2.new(0, 0, 0, 6),
		Parent = toast,
	})
	corner(bar, 1)

	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -22, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Font = theme.font,
		TextSize = 11,
		TextColor3 = theme.text,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = tostring(message),
		Parent = toast,
	})

	local record = { frame = toast }
	self._notifications[#self._notifications + 1] = record
	self:_layoutNotifications()

	local enter = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(toast, enter, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(toastStroke, enter, { Transparency = 0 }):Play()
	TweenService:Create(bar, enter, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(label, enter, { TextTransparency = 0 }):Play()

	local dismissed = false

	local function dismiss()
		if dismissed or not toast.Parent then
			return
		end
		dismissed = true

		for index, item in self._notifications do
			if item == record then
				table.remove(self._notifications, index)
				break
			end
		end
		self:_layoutNotifications()

		local out = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(toast, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastStroke, out, { Transparency = 1 }):Play()
		TweenService:Create(bar, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, out, { TextTransparency = 1 }):Play()

		task.delay(0.2, function()
			if toast.Parent then
				toast:Destroy()
			end
		end)
	end

	record.dismiss = dismiss
	task.delay(duration, dismiss)

	return record
end

function Window:_select(tab)
	for _, other in self._tabs do
		local active = other == tab
		if active and not other._active and self._animateTabs and other._animate ~= false then
			other.page.Position = UDim2.fromOffset(12, 0)
			tween(other.page, { Position = UDim2.fromOffset(0, 0) }, 0.18)
		end
		other._active = active
		other.page.Visible = active
		self:_refreshTab(other, true)
	end
end

function Window:_createTab(name)
	local theme = self.theme
	local order = self._sidebarOrder
	self._sidebarOrder += 1

	local button = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = theme.sidebar,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = order,
		Parent = self._sidebarList,
	})
	corner(button)

	local label = text({
		Text = name,
		TextSize = 12,
		TextColor3 = theme.muted,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	}, theme)

	local page = new("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme.border,
		Visible = false,
		Parent = self._content,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = page,
	})
	pad(page, 10, 12, 12, 10)

	local tab = {
		name = name,
		window = self,
		theme = theme,
		button = button,
		label = label,
		page = page,
		_active = false,
		_hover = false,
		_animate = true,
		_order = 0,
	}

	button.MouseEnter:Connect(function()
		tab._hover = true
		self:_refreshTab(tab, true)
	end)
	button.MouseLeave:Connect(function()
		tab._hover = false
		self:_refreshTab(tab, true)
	end)
	button.Activated:Connect(function()
		self:_select(tab)
	end)

	self._tabs[#self._tabs + 1] = tab
	if #self._tabs == 1 then
		self:_select(tab)
	end

	return setmetatable(tab, Tab)
end

function Window:Tab(name)
	return self:_createTab(name)
end

function Window:TabGroup(label)
	local theme = self.theme
	local order = self._sidebarOrder
	self._sidebarOrder += 1

	local header = new("Frame", {
		Name = "Group",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = self._sidebarList,
	})

	text({
		Text = string.upper(label),
		TextSize = 9,
		TextColor3 = theme.dim,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	}, theme)

	return setmetatable({
		window = self,
		label = label,
	}, TabGroup)
end

-- ── Pestaña ──────────────────────────────────────────────────────────────────

Tab = {}
Tab.__index = Tab

function Tab:Section(title)
	local theme = self.theme
	local path = tostring(self.name) .. "/" .. tostring(title or "General") .. "/"
	local frame = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self._order,
		Parent = self.page,
	})
	self._order += 1

	new("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})

	if self._order > 1 then
		new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 6),
			LayoutOrder = -2,
			Parent = frame,
		})
	end

	if title then
		local header = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			LayoutOrder = -1,
			Parent = frame,
		})

		new("Frame", {
			BackgroundColor3 = theme.border,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.new(0, 0, 0.5, 0),
			Parent = header,
		})

		local headerLabel = text({
			Text = string.upper(title),
			TextSize = 10,
			TextColor3 = theme.muted,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = header,
		}, theme)
		headerLabel.BackgroundColor3 = theme.ui
		headerLabel.BackgroundTransparency = 0
		pad(headerLabel, 0, 6, 0, 0)
	end

	return setmetatable({
		frame = frame,
		window = self.window,
		theme = theme,
		path = path,
		title = title,
		_order = 0,
	}, Section)
end

function Tab:SetAnimation(value)
	self._animate = value and true or false
	return self
end

-- ── Grupo de tabs ────────────────────────────────────────────────────────────

TabGroup = {}
TabGroup.__index = TabGroup

function TabGroup:Tab(name)
	return self.window:_createTab(name)
end

-- ── Sección ──────────────────────────────────────────────────────────────────

Section = {}
Section.__index = Section

function Section:_next()
	self._order += 1
	return self._order
end

function Section:SetVisible(value)
	self.frame.Visible = value and true or false
	return self
end

function Section:Button(labelText, callback)
	local T = self.theme
	local button = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = T.raised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = self:_next(),
		Parent = self.frame,
	})
	corner(button)
	stroke(button, T.border)

	text({
		Text = labelText,
		TextSize = 11,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	}, T)

	button.MouseEnter:Connect(function()
		tween(button, { BackgroundColor3 = T.hover }, 0.08)
	end)
	button.MouseLeave:Connect(function()
		tween(button, { BackgroundColor3 = T.raised }, 0.08)
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = T.pressed
	end)
	button.MouseButton1Up:Connect(function()
		tween(button, { BackgroundColor3 = T.hover }, 0.08)
	end)
	button.Activated:Connect(function()
		fire(callback)
	end)

	local handle = makeHandle(button, nil, nil, "button")
	handle.window = self.window
	return handle
end

function Section:Toggle(labelText, default, callback)
	local T = self.theme
	local button = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = self:_next(),
		Parent = self.frame,
	})

	text({
		Text = labelText,
		TextSize = 11,
		Size = UDim2.new(1, -40, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = button,
	}, T)

	local track = new("Frame", {
		BackgroundColor3 = T.track,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(30, 14),
		Position = UDim2.new(1, -30, 0.5, -7),
		Parent = button,
	})
	corner(track)

	local knob = new("Frame", {
		BackgroundColor3 = T.text,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(10, 10),
		Position = UDim2.fromOffset(2, 2),
		Parent = track,
	})
	corner(knob, 2)

	local state = default and true or false
	local handle

	local function render(animate)
		local target = state and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2)
		local color = state and T.accent or T.track
		if animate then
			tween(knob, { Position = target })
			tween(track, { BackgroundColor3 = color })
		else
			knob.Position = target
			track.BackgroundColor3 = color
		end
	end

	local function apply(value, silent)
		state = value and true or false
		handle._value = state
		render(true)
		if not silent then
			fire(callback, state)
		end
	end

	handle = makeHandle(button, apply, state, "toggle")
	self.window:_register(handle, self.path, labelText)

	render(false)

	button.Activated:Connect(function()
		apply(not state, false)
	end)

	return handle
end

function Section:Slider(labelText, min, max, default, callback)
	local T = self.theme
	local box = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = self:_next(),
		Parent = self.frame,
	})

	text({
		Text = labelText,
		TextSize = 11,
		Size = UDim2.new(1, -60, 0, 16),
		Parent = box,
	}, T)

	local valueLabel = text({
		Text = "",
		Font = T.mono,
		TextSize = 11,
		TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 60, 0, 16),
		Position = UDim2.new(1, -60, 0, 0),
		Parent = box,
	}, T)

	local rail = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 0, 18),
		Parent = box,
	})

	local line = new("Frame", {
		BackgroundColor3 = T.track,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 0.5, -1),
		Parent = rail,
	})
	corner(line, 2)

	local fill = new("Frame", {
		BackgroundColor3 = T.accent,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = line,
	})
	corner(fill, 2)

	local knob = new("Frame", {
		BackgroundColor3 = T.text,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(8, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Parent = rail,
	})
	corner(knob, 4)

	local value = default or min
	local handle

	local function format(number)
		if math.abs(number - math.floor(number + 0.5)) < 0.01 then
			return tostring(math.floor(number + 0.5))
		end
		return string.format("%.1f", number)
	end

	local function apply(alpha, notify)
		alpha = math.clamp(alpha, 0, 1)
		value = min + (max - min) * alpha
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = format(value)
		if notify then
			fire(callback, value)
		end
	end

	local initial = 0
	if max > min then
		initial = math.clamp((value - min) / (max - min), 0, 1)
	end
	apply(initial, false)

	local function setValue(newValue, silent)
		newValue = tonumber(newValue) or min
		local alpha = 0
		if max ~= min then
			alpha = (newValue - min) / (max - min)
		end
		apply(alpha, false)
		handle._value = value
		if not silent then
			fire(callback, value)
		end
	end

	handle = makeHandle(box, setValue, value, "slider")
	self.window:_register(handle, self.path, labelText)

	local dragging = false
	local function updateFromInput(input)
		local width = rail.AbsoluteSize.X
		if width <= 0 then
			return
		end
		apply((input.Position.X - rail.AbsolutePosition.X) / width, true)
		handle._value = value
	end

	rail.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input)
		end
	end)

	self.window:_track(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			updateFromInput(input)
		end
	end))

	self.window:_track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))

	return handle
end

function Section:Input(labelText, placeholder, callback)
	local T = self.theme
	local box = row(self.frame, 26)
	box.LayoutOrder = self:_next()

	text({
		Text = labelText,
		TextSize = 11,
		Size = UDim2.new(1, -160, 1, 0),
		Parent = box,
	}, T)

	local field = new("TextBox", {
		BackgroundColor3 = T.input,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 150, 0, 22),
		Position = UDim2.new(1, -150, 0.5, -11),
		Font = T.font,
		TextSize = 11,
		TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = placeholder or "",
		PlaceholderColor3 = T.dim,
		Text = "",
		ClearTextOnFocus = false,
		Parent = box,
	})
	corner(field)
	local fieldStroke = stroke(field, T.border)
	pad(field, 0, 6, 0, 6)

	local handle

	local function setValue(newValue, silent)
		local stringValue = tostring(newValue or "")
		field.Text = stringValue
		handle._value = stringValue
		if not silent then
			fire(callback, stringValue)
		end
	end

	handle = makeHandle(field, setValue, field.Text, "input")
	self.window:_register(handle, self.path, labelText)

	field.Focused:Connect(function()
		fieldStroke.Color = T.accent
	end)
	field.FocusLost:Connect(function()
		fieldStroke.Color = T.border
		handle._value = field.Text
		fire(callback, field.Text)
	end)

	return handle
end

function Section:Dropdown(labelText, options, default, callback)
	local T = self.theme
	local wrap = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_next(),
		Parent = self.frame,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = wrap,
	})

	local head = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = T.raised,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 26),
		LayoutOrder = 0,
		Parent = wrap,
	})
	corner(head)
	stroke(head, T.border)

	text({
		Text = labelText,
		TextSize = 11,
		Size = UDim2.new(1, -128, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = head,
	}, T)

	local valueLabel = text({
		Text = "",
		TextSize = 11,
		TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 86, 1, 0),
		Position = UDim2.new(1, -112, 0, 0),
		Parent = head,
	}, T)

	local caret = new("Frame", {
		Name = "Caret",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.new(1, -22, 0.5, -4),
		Parent = head,
	})

	new("Frame", {
		BackgroundColor3 = T.dim,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(4, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(2.5, 4),
		Rotation = 45,
		Parent = caret,
	})

	new("Frame", {
		BackgroundColor3 = T.dim,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(4, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(5.5, 4),
		Rotation = -45,
		Parent = caret,
	})

	local optionsFrame = new("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		LayoutOrder = 1,
		Parent = wrap,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = optionsFrame,
	})

	local selected = default or options[1]
	local optionButtons = {}
	local handle

	local function refresh()
		valueLabel.Text = tostring(selected)
		for _, option in optionButtons do
			if option.value == selected then
				option.label.TextColor3 = T.accent
			else
				option.label.TextColor3 = T.text
			end
		end
	end

	local function selectValue(value, silent)
		selected = value
		handle._value = value
		refresh()
		optionsFrame.Visible = false
		tween(caret, { Rotation = 0 })
		if not silent then
			fire(callback, value)
		end
	end

	handle = makeHandle(head, selectValue, selected, "dropdown")
	self.window:_register(handle, self.path, labelText)

	for index, value in options do
		local option = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = T.raised,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 22),
			LayoutOrder = index,
			Parent = optionsFrame,
		})
		corner(option)

		local optionLabel = text({
			Text = tostring(value),
			TextSize = 11,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = option,
		}, T)

		option.MouseEnter:Connect(function()
			tween(option, { BackgroundTransparency = 0 }, 0.08)
		end)
		option.MouseLeave:Connect(function()
			tween(option, { BackgroundTransparency = 1 }, 0.08)
		end)
		option.Activated:Connect(function()
			selectValue(value, false)
		end)

		optionButtons[#optionButtons + 1] = { value = value, label = optionLabel }
	end

	refresh()

	local hovering = false

	head.MouseEnter:Connect(function()
		hovering = true
		tween(head, { BackgroundColor3 = T.hover }, 0.08)
	end)
	head.MouseLeave:Connect(function()
		hovering = false
		tween(head, { BackgroundColor3 = T.raised }, 0.08)
	end)
	optionsFrame.MouseEnter:Connect(function()
		hovering = true
	end)
	optionsFrame.MouseLeave:Connect(function()
		hovering = false
	end)

	head.Activated:Connect(function()
		optionsFrame.Visible = not optionsFrame.Visible
		tween(caret, { Rotation = optionsFrame.Visible and 180 or 0 })
	end)

	self.window:_track(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if optionsFrame.Visible and not hovering then
			optionsFrame.Visible = false
			tween(caret, { Rotation = 0 })
		end
	end))

	return handle
end

function Section:Stat(labelText, value)
	local T = self.theme
	local box = row(self.frame, 20)
	box.LayoutOrder = self:_next()

	text({
		Text = labelText,
		TextSize = 11,
		Size = UDim2.new(1, -130, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = box,
	}, T)

	local valueLabel = text({
		Text = value or "—",
		Font = T.mono,
		TextSize = 11,
		TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(0, 130, 1, 0),
		Position = UDim2.new(1, -130, 0, 0),
		Parent = box,
	}, T)

	local handle

	local function setValue(newValue)
		local stringValue = tostring(newValue)
		valueLabel.Text = stringValue
		handle._value = stringValue
	end

	handle = makeHandle(box, setValue, tostring(value or "—"), "stat")
	self.window:_register(handle, self.path, labelText)

	return handle
end

function Section:Label(body)
	local T = self.theme
	local label = text({
		Text = body,
		TextSize = 11,
		TextColor3 = T.muted,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = self:_next(),
		Parent = self.frame,
	}, T)

	local handle = makeHandle(label, nil, nil, "label")
	handle.window = self.window
	return handle
end

function Section:Divider()
	local T = self.theme
	local divider = new("Frame", {
		BackgroundColor3 = T.border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = self:_next(),
		Parent = self.frame,
	})

	local handle = makeHandle(divider, nil, nil, "divider")
	handle.window = self.window
	return handle
end

return UI
