--!strict
-- ESPOutlineStatus.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

type StatusFn = (box: any) -> (string?)

type Box = {
	Object: Instance,
	Adornee: BasePart?,
	Player: Player?,

	Highlight: Highlight,
	Gui: BillboardGui,
	StatusLabel: TextLabel,

	StatusText: string?,
	StatusSupplier: StatusFn?,
	_nextT: number?,

	Remove: (self: Box) -> (),
	Update: (self: Box) -> (),
	
	Layer: string?
	
	--Color: Color3?,
	--ColorDynamic: ((box: Box) -> Color3)?,
}

local ESP = {
	Enabled = true,
	Color = Color3.fromRGB(255,170,0),
	TeamColor = true,
	Players = true,
	TeamMates = true,
	RichText = true,

	MaxBillboardDistance = 500,
	StudsOffsetY = 5.5,         -- cao hơn đầu
	UpdateRate = 0,             -- 0 = mỗi frame

	Objects = setmetatable({}, {__mode="kv"}) :: {[Instance]: Box},
	Overrides = {} :: {
		GetTeam: ((p: Player?) -> Team?)?,
		IsTeamMate: ((p: Player?) -> boolean)?,
		GetPlrFromChar: ((char: Instance) -> Player?)?,
		GetColor: ((obj: Instance) -> Color3)?,
		UpdateAllow: ((box: Box) -> boolean)?,
	},
	StatusSep = "\n",
	StatusKVFormat = "%s: %s",
	
	Layers = {
		default = { Enabled = true },   -- mặc định
		-- bạn có thể khai báo sẵn:
		-- Pets   = { Enabled = true,  Color = nil },
		-- Fruits = { Enabled = true,  Color = nil },
	},

    Sources = {}, -- [layerName] = { {Parent=Instance, Options=table} , ... }

	_epoch = 0,
	_conns = {} :: { RBXScriptConnection },
	_stepped = nil :: RBXScriptConnection?,
}

local function primaryPart(obj: Instance): BasePart?
	if obj:IsA("Model") then
		return obj.PrimaryPart
			or (obj:FindFirstChild("Head") :: BasePart)
			or (obj:FindFirstChild("HumanoidRootPart") :: BasePart)
			or obj:FindFirstChildWhichIsA("BasePart")
	elseif obj:IsA("BasePart") then
		return obj
	end
	return nil
end

local function _getKeyFor(obj: Instance, layerProps: {[string]: any}?): string?
	-- cho phép custom selector, mặc định dùng obj.Name
	if layerProps and typeof(layerProps.NameSelector)=="function" then
		local ok, key = pcall(layerProps.NameSelector, obj)
		if ok and typeof(key)=="string" and key~="" then return key end
	end
	return obj and obj.Name or nil
end

local function _allowedByMap(obj: Instance, layerProps: {[string]: any}?): boolean
	local key = _getKeyFor(obj, layerProps)
	if not key then return false end               -- name=nil => loại
	local m = layerProps and layerProps.NameAllow
	if not m then return true end                  -- chưa set map => cho qua
	return m[key] == true                          -- chỉ true mới được
end

function ESP:_track(conn: RBXScriptConnection)
	table.insert(self._conns, conn)
	return conn
end

function ESP:_disconnectAll()
	for i = #self._conns, 1, -1 do
		local c = self._conns[i]
		if c then pcall(function() c:Disconnect() end) end
		self._conns[i] = nil
	end
	if self._stepped then
		pcall(function() self._stepped:Disconnect() end)
		self._stepped = nil
	end
	self._epoch += 1 -- hủy mọi vòng lặp đang chạy dựa trên epoch
end

function ESP:Bind()
	if self._stepped then return end
	local myEpoch = self._epoch
	self._stepped = RunService.Stepped:Connect(function()
		-- nếu bị reset giữa chừng thì dừng ngay
		if myEpoch ~= self._epoch then return end
		for _, box in pairs(ESP.Objects) do
			if myEpoch ~= self._epoch then return end
			local ok, err = pcall(function() box:Update() end)
			if not ok then warn("[ESP]", err) end
		end
	end)
end

function ESP:SuspendUpdates()
	self:_disconnectAll() -- ngắt toàn bộ connections, tăng epoch
end

function ESP:ResumeUpdates()
	self:Bind()
end

function ESP:HideAll()
	self.Enabled = false
	for _, box in pairs(self.Objects) do
		box.Highlight.Enabled = false
		box.Gui.Enabled = false
	end
end

function ESP:ShowAll()
	self.Enabled = true
	for _, box in pairs(self.Objects) do
		box.Highlight.Enabled = true
		box.Gui.Enabled = true
	end
end

function ESP:Clear()
	for _, box in pairs(self.Objects) do
		box:Remove()
	end
	self.Objects = setmetatable({}, {__mode="kv"})
end

function ESP:Destroy()
	self:HideAll()
	self:Clear()
	self:_disconnectAll()
end

function ESP:GetPlrFromChar(char: Instance): Player?
	local f = self.Overrides.GetPlrFromChar
	if f then return f(char) end
	return Players:GetPlayerFromCharacter(char)
end

function ESP:GetTeam(p: Player?): Team?
	local f = self.Overrides.GetTeam
	if f then return f(p) end
	return p and p.Team
end

function ESP:IsTeamMate(p: Player?): boolean
	local f = self.Overrides.IsTeamMate
	if f then return f(p) end
	return self:GetTeam(p) == self:GetTeam(LocalPlayer)
end

function ESP:GetColor(obj: Instance): Color3
	local f = self.Overrides.GetColor
	if f then return f(obj) end
	local pl = self:GetPlrFromChar(obj)
	if pl and self.TeamColor and pl.Team then
		return pl.Team.TeamColor.Color
	end
	return self.Color
end

function ESP:Toggle(on: boolean)
	self.Enabled = on
	for _, box in pairs(self.Objects) do
		box.Highlight.Enabled = on
		box.Gui.Enabled = on
	end
end

function ESP:GetBox(obj: Instance): Box?
	return self.Objects[obj]
end

-- API status
function ESP:SetStatus(obj: Instance, text: string?)
	local box = self.Objects[obj]
	if not box then return end
	box.StatusText = text
end

function ESP:SetStatusSupplier(obj: Instance, fn: StatusFn?)
	local box = self.Objects[obj]
	if not box then return end
	box.StatusSupplier = fn
end

-- UI
local function buildGui(offsetY: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ESP_Status"
	gui.Size = UDim2.fromOffset(140, 40)
	gui.AlwaysOnTop = true
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 0

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Status"
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 16)
	lbl.Position = UDim2.fromOffset(0, 0)
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.Font = Enum.Font.SourceSansBold
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.new(1,1,1)
	lbl.TextStrokeTransparency = 0.3
	lbl.Parent = gui
	lbl.RichText = true
	lbl.RichText = (ESP.RichText ~= false)
	lbl.TextWrapped = true

    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.Size = UDim2.new(1, 0, 0, 0)

	return gui, lbl
end

-- Box
local boxMT = {} ; boxMT.__index = boxMT

function boxMT:Remove()
	if self.Highlight then self.Highlight:Destroy() end
	if self.Gui then self.Gui:Destroy() end
	ESP.Objects[self.Object] = nil
end

function boxMT:Update()
	if ESP.Overrides.UpdateAllow and not ESP.Overrides.UpdateAllow(self) then
		self.Highlight.Enabled = false
		self.Gui.Enabled = false
		return
	end
	if not ESP.Enabled then
		self.Highlight.Enabled = false
		self.Gui.Enabled = false
		return
	end

	self.Adornee = primaryPart(self.Object)
	if not self.Adornee or (not workspace:IsAncestorOf(self.Adornee)) then
		self.Highlight.Enabled = false
		self.Gui.Enabled = false
		return
	end

	if self.Player then
		if not ESP.Players or (not ESP.TeamMates and ESP:IsTeamMate(self.Player)) then
			self.Highlight.Enabled = false
			self.Gui.Enabled = false
			return
		end
	end
	
	-- Lấy cấu hình layer
	local layer = ESP.Layers[self.Layer or "default"] or { Enabled = true }

	-- Bị tắt bởi layer
	if not layer.Enabled or not ESP.Enabled then
		self.Highlight.Enabled = false
		self.Gui.Enabled = false
		return
	end

	local col = self.Color
	if not col and self.ColorDynamic then
		local ok, dyn = pcall(self.ColorDynamic, self)
		if ok and typeof(dyn) == "Color3" then col = dyn end
	end
	if not col and layer.Color then col = layer.Color end
	if not col then col = ESP:GetColor(self.Object) end
	
	self.Highlight.OutlineColor = col
	self.Highlight.FillColor = col

	local cam = workspace.CurrentCamera
	local dist = (cam.CFrame.Position - self.Adornee.Position).Magnitude
	self.Gui.Enabled = dist <= ESP.MaxBillboardDistance
	self.Gui.Adornee = self.Adornee
	self.Highlight.Enabled = true

	-- status text (throttle)
	local now = time()
	if (ESP.UpdateRate or 0) <= 0 or not self._nextT or now >= self._nextT then
		local txt = self.StatusText
		if self.StatusSupplier then
			local ok, res = pcall(self.StatusSupplier, self)
			if ok and typeof(res) == "string" then txt = res end
		end
		self.StatusLabel.Text = txt or ""
		self.StatusLabel.TextColor3 = col
		self._nextT = now + (ESP.UpdateRate or 0)
	end
end

-- Add
function ESP:Add(obj: Instance, options: {[string]: any}?): Box?
	options = options or {}
	if not obj.Parent and not options.RenderInNil then
		warn(obj, "has no parent")
		return nil
	end
	
	local layerName = typeof(options.Layer) == "string" and options.Layer or "default"

    local layerProps = self.Layers[layerName]
    if not _allowedByMap(obj, layerProps) then
        return nil
    end

	local pp = options.PrimaryPart or primaryPart(obj)
	local p: Player? = options.Player or self:GetPlrFromChar(obj)

	local h = Instance.new("Highlight")
	h.Name = "ESP_Highlight"
	h.FillTransparency = 0.8
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Enabled = self.Enabled
	h.Parent = obj

	local gui, lbl = buildGui(options.StudsOffsetY or self.StudsOffsetY)
	gui.Adornee = pp
	gui.Enabled = self.Enabled
	gui.Parent = obj

	local box = setmetatable({
		Object = obj,
		Adornee = pp,
		Player = p,

		Highlight = h,
		Gui = gui,
		StatusLabel = lbl,

		StatusText = typeof(options.Status) == "string" and options.Status or nil,
		StatusSupplier = options.StatusSupplier,

		Color = options.Color,
		ColorDynamic = options.ColorDynamic,
		
		Layer = layerName,
	}, boxMT)

	if self.Objects[obj] then
		self.Objects[obj]:Remove()
	end
	self.Objects[obj] = box

	-- cleanup
	ESP:_track(obj.AncestryChanged:Connect(function(_, parent)
		if parent == nil and ESP.AutoRemove ~= false then box:Remove() end
	end))
	ESP:_track(obj:GetPropertyChangedSignal("Parent"):Connect(function()
		if obj.Parent == nil and ESP.AutoRemove ~= false then box:Remove() end
	end))

	local hum = obj:FindFirstChildOfClass("Humanoid")
	if hum then
		ESP:_track(hum.Died:Connect(function()
			if ESP.AutoRemove ~= false then box:Remove() end
		end))
	end

	return box
end

-- Listener
function ESP:AddObjectListener(parent: Instance, options: {[string]: any})
	local function tryAdd(c: Instance)
		local okType = (not options.Type) or (typeof(options.Type) == "string" and c:IsA(options.Type))
		local okName = (not options.Name) or (typeof(options.Name) == "string" and c.Name == options.Name)
		if okType and okName then
			if not options.Validator or options.Validator(c) then
				local primary = if typeof(options.PrimaryPart) == "string"
					then (c:WaitForChild(options.PrimaryPart) :: any)
					elseif typeof(options.PrimaryPart) == "function"
					then options.PrimaryPart(c)
					else nil
				ESP:Add(c, {
					PrimaryPart = primary,
					RenderInNil = options.RenderInNil,
					Status = options.Status,
					StatusSupplier = options.StatusSupplier,
					StudsOffsetY = options.StudsOffsetY,
                    Layer         = typeof(options.Layer)=="string" and options.Layer or "default",
				})
                
                local layerName = typeof(options.Layer)=="string" and options.Layer or "default"
                ESP:DefineLayer(layerName)
                ESP.Sources[layerName] = ESP.Sources[layerName] or {}

                table.insert(ESP.Sources[layerName], { Parent = parent, Options = options })

				if options.OnAdded then task.spawn(options.OnAdded, ESP:GetBox(c)) end
			end
		end
	end

	if options.Recursive then
		ESP:_track(parent.DescendantAdded:Connect(tryAdd))
		for _, d in ipairs(parent:GetDescendants()) do task.spawn(tryAdd, d) end
	else
		ESP:_track(parent.ChildAdded:Connect(tryAdd))
		for _, ch in ipairs(parent:GetChildren()) do task.spawn(tryAdd, ch) end
	end
end

function ESP:SetColor(obj: Instance, color: Color3?)
	local box = self.Objects[obj]
	if not box then return end
	box.Color = color
end

function ESP:SetColorSupplier(obj: Instance, fn: ((box: Box)->Color3)?)
	local box = self.Objects[obj]
	if not box then return end
	box.ColorDynamic = fn
end

function ESP:FormatStatusKV(kv: {[string]: any}, opts: {[string]: any}?): string
	opts = opts or {}
	local sep = opts.sep or self.StatusSep
	local kvFmt = opts.kvFmt or self.StatusKVFormat
	local keyFmt = opts.keyFmt or "%s"
	local valFmt = opts.valFmt or "%s"

	local lines = {}

	-- nếu có order thì theo order, ngược lại duyệt key tăng dần cho ổn định
	local keys = {}
	if typeof(opts.order) == "table" then
		keys = opts.order
	else
		for k in pairs(kv) do table.insert(keys, k) end
		table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
	end

	for _, k in ipairs(keys) do
		local v = kv[k]
		if v ~= nil then
			local ks = string.format(keyFmt, tostring(k))
			local vs = string.format(valFmt, tostring(v))
			table.insert(lines, string.format(kvFmt, ks, vs))
		end
	end
	return table.concat(lines, sep)
end

function ESP:SetStatusTable(obj: Instance, kv: {[string]: any}, opts: {[string]: any}?)
	local box = self:GetBox(obj)
	if not box then return end
	box.StatusSupplier = function(_)
		return ESP:FormatStatusKV(kv, opts)
	end
end

function ESP:SetLayerDropdown(name: string, allowMap: {[string]: boolean}?, opts: {[string]: any}?)
	-- opts: { rescan = true/false } mặc định true
	self:DefineLayer(name)
	local layer = self.Layers[name]
	layer.NameAllow = allowMap or {}

	-- 1) Xoá mọi box không còn hợp lệ
	for _, box in pairs(self.Objects) do
		if box.Layer == name then
			if not _allowedByMap(box.Object, layer) then
				box:Remove()
			end
		end
	end

	-- 2) Rescan nguồn để ADD lại những object nay đã hợp lệ
	local doRescan = if opts and opts.rescan==false then false else true
	if doRescan then
		local srcs = self.Sources[name] or {}
		for _, src in ipairs(srcs) do
			local parent = src.Parent
			local o = src.Options or {}
			if parent and parent.Parent then
				local iter = if o.Recursive then parent:GetDescendants() else parent:GetChildren()
				for _, c in ipairs(iter) do
					-- khớp filter listener (Type/Name/Validator)
					local okType = (not o.Type) or (typeof(o.Type)=="string" and c:IsA(o.Type))
					local okName = (not o.Name) or (typeof(o.Name)=="string" and c.Name==o.Name)
					local okValid = (not o.Validator) or o.Validator(c)
					if okType and okName and okValid then
						if _allowedByMap(c, layer) and not self.Objects[c] then
							-- dựng lại PrimaryPart như listener làm
							local primary =
								if typeof(o.PrimaryPart)=="string" then (c:FindFirstChild(o.PrimaryPart) :: any)
								elseif typeof(o.PrimaryPart)=="function" then o.PrimaryPart(c)
								else nil
							self:Add(c, {
								PrimaryPart = primary,
								RenderInNil = o.RenderInNil,
								Status = o.Status,
								StatusSupplier = o.StatusSupplier,
								StudsOffsetY = o.StudsOffsetY,
								Color = o.Color,
								ColorDynamic = o.ColorDynamic,
								Layer = layer and name or "default",
							})
						end
					end
				end
			end
		end
	end
end

function ESP:DefineLayer(name: string, props: {[string]: any}?)
	local l = self.Layers[name] or {}
	if props then for k, v in pairs(props) do l[k] = v end end
	if l.Enabled == nil then l.Enabled = true end
	self.Layers[name] = l
end

function ESP:ToggleLayer(name: string, on: boolean)
	self:DefineLayer(name) -- đảm bảo tồn tại
	self.Layers[name].Enabled = on
	-- áp ngay trạng thái cho các box cùng layer
	for _, box in pairs(self.Objects) do
		if box.Layer == name then
			box.Highlight.Enabled = on and self.Enabled
			box.Gui.Enabled = on and self.Enabled
		end
	end
end

function ESP:ShowLayer(name: string)  self:ToggleLayer(name, true)  end
function ESP:HideLayer(name: string)  self:ToggleLayer(name, false) end

function ESP:ClearLayer(name: string)
	for _, box in pairs(self.Objects) do
		if box.Layer == name then box:Remove() end
	end
end

-- Auto-track players
local function onChar(char: Model)
	local p = Players:GetPlayerFromCharacter(char)
	if not p or p == LocalPlayer then return end
	local function attach()
		local head = char:FindFirstChild("Head")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local ador = head or hrp
		if ador then
			ESP:Add(char, { PrimaryPart = ador })
		end
	end
	if char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") then
		attach()
	else
		ESP:_track(char.ChildAdded:Connect(function(c)
			if c.Name=="Head" or c.Name=="HumanoidRootPart" then attach() end
		end))
	end
end

-- local function onPlayer(p: Player)
-- 	ESP:_track(p.CharacterAdded:Connect(onChar))
-- 	if p.Character then task.spawn(onChar, p.Character) end
-- end
-- for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then onPlayer(p) end end
-- ESP:_track(Players.PlayerAdded:Connect(onPlayer))

-- Tick
ESP:Bind()

return ESP
