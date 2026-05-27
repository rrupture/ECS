--!strict

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local toolbar = plugin:CreateToolbar("bsECS")
local toggleButton = toolbar:CreateButton("Inspector", "bsECS Runtime Inspector", "rbxassetid://4458901886")
local widget = plugin:CreateDockWidgetPluginGui(
	"bsECSInspector",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 940, 560, 620, 420)
)
widget.Title = "bsECS Runtime Inspector"

local P = {
	bg0 = Color3.fromRGB(17, 18, 22),
	bg1 = Color3.fromRGB(24, 26, 31),
	bg2 = Color3.fromRGB(31, 34, 41),
	bg3 = Color3.fromRGB(43, 49, 61),
	line = Color3.fromRGB(49, 54, 66),
	blue = Color3.fromRGB(96, 168, 255),
	blue2 = Color3.fromRGB(45, 86, 145),
	green = Color3.fromRGB(104, 219, 139),
	yellow = Color3.fromRGB(240, 200, 91),
	red = Color3.fromRGB(235, 95, 95),
	purple = Color3.fromRGB(184, 145, 255),
	text = Color3.fromRGB(224, 227, 234),
	mid = Color3.fromRGB(142, 148, 160),
	dim = Color3.fromRGB(82, 88, 102),
}

local function apply(instance: Instance, props: { [string]: any }): any
	for k, v in pairs(props) do
		(instance :: any)[k] = v
	end
	return instance
end

local function frame(props: { [string]: any }): Frame
	return apply(Instance.new("Frame"), props)
end

local function label(props: { [string]: any }): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Font = Enum.Font.Gotham
	item.TextSize = 11
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.TextColor3 = P.text
	return apply(item, props)
end

local function button(props: { [string]: any }): TextButton
	local item = Instance.new("TextButton")
	item.BorderSizePixel = 0
	item.AutoButtonColor = false
	item.Font = Enum.Font.Gotham
	item.TextSize = 11
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextColor3 = P.text
	return apply(item, props)
end

local function textBox(props: { [string]: any }): TextBox
	local item = Instance.new("TextBox")
	item.BackgroundColor3 = P.bg0
	item.BorderSizePixel = 0
	item.ClearTextOnFocus = false
	item.Font = Enum.Font.Code
	item.TextSize = 10
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextColor3 = P.yellow
	item.PlaceholderColor3 = P.dim
	apply(item, props)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = item
	return item
end

local function scroll(props: { [string]: any }): ScrollingFrame
	local item = Instance.new("ScrollingFrame")
	item.BorderSizePixel = 0
	item.ScrollBarThickness = 4
	item.ScrollBarImageColor3 = P.line
	item.CanvasSize = UDim2.fromOffset(0, 0)
	item.AutomaticCanvasSize = Enum.AutomaticSize.Y
	item.BackgroundColor3 = P.bg1
	apply(item, props)

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = item

	return item
end

local function line(parent: Instance, x: number, y: number, w: number, h: number)
	frame({
		Position = UDim2.new(0, x, 0, y),
		Size = UDim2.new(0, w, 0, h),
		BackgroundColor3 = P.line,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

local root = frame({
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = P.bg0,
	BorderSizePixel = 0,
	Parent = widget,
})

local topbar = frame({
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = P.bg1,
	BorderSizePixel = 0,
	Parent = root,
})

line(root, 0, 34, 5000, 1)

local statusDot = frame({
	Size = UDim2.fromOffset(8, 8),
	Position = UDim2.fromOffset(11, 13),
	BackgroundColor3 = P.dim,
	BorderSizePixel = 0,
	Parent = topbar,
})
apply(Instance.new("UICorner"), {
	CornerRadius = UDim.new(1, 0),
	Parent = statusDot,
})

local statusLabel = label({
	Size = UDim2.new(1, -40, 1, 0),
	Position = UDim2.fromOffset(28, 0),
	Text = "bsECS  |  waiting for runtime",
	TextColor3 = P.mid,
	TextSize = 12,
	Font = Enum.Font.GothamMedium,
	Parent = topbar,
})

local body = frame({
	Size = UDim2.new(1, 0, 1, -35),
	Position = UDim2.fromOffset(0, 35),
	BackgroundColor3 = P.bg0,
	BorderSizePixel = 0,
	Parent = root,
})

local sidebarWidth = 170
local detailWidth = 250

local sidebar = scroll({
	Size = UDim2.new(0, sidebarWidth, 1, 0),
	BackgroundColor3 = P.bg1,
	Parent = body,
})

local tablePanel = frame({
	Size = UDim2.new(1, -sidebarWidth - detailWidth - 2, 1, 0),
	Position = UDim2.new(0, sidebarWidth + 1, 0, 0),
	BackgroundColor3 = P.bg1,
	BorderSizePixel = 0,
	Parent = body,
})

local detailPanel = frame({
	Size = UDim2.new(0, detailWidth, 1, 0),
	Position = UDim2.new(1, -detailWidth, 0, 0),
	BackgroundColor3 = P.bg1,
	BorderSizePixel = 0,
	Parent = body,
})

line(body, sidebarWidth, 0, 1, 5000)
line(body, 0, 0, 5000, 0)
frame({
	Size = UDim2.new(0, 1, 1, 0),
	Position = UDim2.new(1, -detailWidth - 1, 0, 0),
	BackgroundColor3 = P.line,
	BorderSizePixel = 0,
	Parent = body,
})

local tableHeader = frame({
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundColor3 = P.bg2,
	BorderSizePixel = 0,
	Parent = tablePanel,
})
line(tablePanel, 0, 26, 5000, 1)

local function col(text: string, x: number, width: number)
	label({
		Size = UDim2.new(0, width, 1, 0),
		Position = UDim2.fromOffset(x, 0),
		Text = text,
		TextColor3 = P.mid,
		TextSize = 10,
		Font = Enum.Font.GothamMedium,
		Parent = tableHeader,
	})
end

col("  ID", 0, 74)
col("LABEL", 74, 150)
col("COMPONENT DATA", 224, 420)

local tableScroll = scroll({
	Size = UDim2.new(1, 0, 1, -27),
	Position = UDim2.fromOffset(0, 27),
	BackgroundColor3 = P.bg1,
	Parent = tablePanel,
})

local detailHeader = frame({
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundColor3 = P.bg2,
	BorderSizePixel = 0,
	Parent = detailPanel,
})
line(detailPanel, 0, 30, 5000, 1)

local detailTitle = label({
	Size = UDim2.new(1, -12, 1, 0),
	Position = UDim2.fromOffset(10, 0),
	Text = "Entity",
	TextColor3 = P.blue,
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	Parent = detailHeader,
})

local detailScroll = scroll({
	Size = UDim2.new(1, 0, 1, -31),
	Position = UDim2.fromOffset(0, 31),
	BackgroundColor3 = P.bg1,
	Parent = detailPanel,
})

local selectedId: string? = nil
local lastSnap: any = nil
local dirty = false

local function clear(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function entityData(raw: any): any
	return raw.components and raw or {
		id = tonumber(raw.id),
		label = "Entity",
		signature = "",
		components = raw,
	}
end

local function componentNames(components: any): { string }
	local names = {}
	for name in pairs(components or {}) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

local function entityRows(snap: any): { any }
	local out = {}

	for id, raw in pairs(snap.entities or {}) do
		local data = entityData(raw)
		out[#out + 1] = {
			id = id,
			data = data,
		}
	end

	table.sort(out, function(a, b)
		return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
	end)

	return out
end

local function section(parent: Instance, order: number, text: string)
	local row = frame({
		Size = UDim2.new(1, 0, 0, 21),
		BackgroundColor3 = P.bg2,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	})
	label({
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.fromOffset(9, 0),
		Text = text,
		TextColor3 = P.blue,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		Parent = row,
	})
end

local function sideRow(order: number, left: string, right: string, color: Color3?)
	local row = frame({
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = P.bg1,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = sidebar,
	})
	label({
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Text = left,
		TextColor3 = P.mid,
		TextSize = 10,
		Parent = row,
	})
	label({
		Size = UDim2.new(0, 58, 1, 0),
		Position = UDim2.new(1, -62, 0, 0),
		Text = right,
		TextColor3 = color or P.text,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})
end

local function renderSidebar(snap: any, visibleCount: number)
	clear(sidebar)

	local order = 0
	order += 1
	section(sidebar, order, "WORLD")
	order += 1
	sideRow(order, "Entities", tostring(snap.entityCount or 0), P.green)
	order += 1
	sideRow(order, "Rows", tostring(visibleCount), P.yellow)
	order += 1
	sideRow(order, "Systems", tostring(snap.systemCount or 0), P.blue)

	order += 1
	section(sidebar, order, "SCHEDULER")
	for _, timing in ipairs(snap.systemTimings or {}) do
		local ms = timing.ms or 0
		local color = if ms > 1 then P.red elseif ms > 0.1 then P.yellow else P.green
		order += 1
		sideRow(order, timing.name or "System", string.format("%.3fms", ms), color)
	end

	order += 1
	section(sidebar, order, "COMPONENTS")
	local comps = {}
	for name, count in pairs(snap.components or {}) do
		comps[#comps + 1] = { name = name, count = count }
	end
	table.sort(comps, function(a, b)
		if a.count == b.count then
			return a.name < b.name
		end
		return a.count > b.count
	end)
	for _, comp in ipairs(comps) do
		order += 1
		sideRow(order, comp.name, tostring(comp.count), P.purple)
	end
end

local function preview(components: any): string
	local parts = {}
	local priority = { "Health", "Position", "Velocity", "Dead" }

	for _, name in ipairs(priority) do
		if components[name] ~= nil then
			parts[#parts + 1] = name .. "=" .. tostring(components[name])
		end
	end

	if #parts == 0 then
		for _, name in ipairs(componentNames(components)) do
			parts[#parts + 1] = name .. "=" .. tostring(components[name])
			if #parts == 3 then
				break
			end
		end
	end

	return table.concat(parts, "   ")
end

local function sendEdit(entity: string, component: string, value: string)
	local editInput = ReplicatedStorage:FindFirstChild("ECSEditInput")
	if not editInput or not editInput:IsA("StringValue") then
		return
	end

	editInput.Value = HttpService:JSONEncode({
		entity = tonumber(entity),
		component = component,
		value = value,
		t = os.clock(),
	})
end

local function renderDetail(entry: any?)
	clear(detailScroll)

	if not entry then
		detailTitle.Text = "Entity"
		label({
			Size = UDim2.new(1, -18, 0, 22),
			Position = UDim2.fromOffset(10, 0),
			Text = "No matching entity.",
			TextColor3 = P.mid,
			LayoutOrder = 1,
			Parent = detailScroll,
		})
		return
	end

	local id = entry.id
	local data = entry.data
	local components = data.components or {}
	local types = data.types or {}
	local editable = data.editable or {}
	detailTitle.Text = "Entity #" .. id

	local order = 0
	for _, name in ipairs(componentNames(components)) do
		order += 1
		local head = frame({
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = P.bg2,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = detailScroll,
		})
		label({
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			Text = name .. "  [" .. tostring(types[name] or "?") .. "]",
			TextColor3 = P.blue,
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			Parent = head,
		})

		order += 1
		if editable[name] then
			local box = textBox({
				Size = UDim2.new(1, -18, 0, 24),
				Position = UDim2.fromOffset(10, 0),
				Text = tostring(components[name]),
				LayoutOrder = order,
				Parent = detailScroll,
			})
			box.FocusLost:Connect(function()
				sendEdit(id, name, box.Text)
			end)
		else
			label({
				Size = UDim2.new(1, -18, 0, 24),
				Position = UDim2.fromOffset(14, 0),
				Text = tostring(components[name]),
				TextColor3 = P.yellow,
				TextSize = 10,
				Font = Enum.Font.Code,
				LayoutOrder = order,
				Parent = detailScroll,
			})
		end
	end

	if data.relationships and #data.relationships > 0 then
		order += 1
		local head = frame({
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = P.bg2,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = detailScroll,
		})
		label({
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			Text = "Relationships",
			TextColor3 = P.purple,
			TextSize = 11,
			Font = Enum.Font.GothamMedium,
			Parent = head,
		})

		for _, rel in ipairs(data.relationships) do
			order += 1
			label({
				Size = UDim2.new(1, -18, 0, 20),
				Position = UDim2.fromOffset(14, 0),
				Text = rel,
				TextColor3 = P.mid,
				TextSize = 10,
				Font = Enum.Font.Code,
				LayoutOrder = order,
				Parent = detailScroll,
			})
		end
	end
end

local function renderTable(entries: { any })
	clear(tableScroll)

	for i, entry in ipairs(entries) do
		local id = entry.id
		local data = entry.data
		local selected = id == selectedId
		local components = data.components or {}

		local row = button({
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundColor3 = if selected then P.blue2 elseif i % 2 == 0 then P.bg1 else P.bg0,
			LayoutOrder = i,
			Text = "",
			Parent = tableScroll,
		})

		label({
			Size = UDim2.new(0, 72, 1, 0),
			Position = UDim2.fromOffset(4, 0),
			Text = "#" .. id,
			TextColor3 = if selected then P.text else P.mid,
			TextSize = 10,
			Font = Enum.Font.Code,
			Parent = row,
		})
		label({
			Size = UDim2.new(0, 146, 1, 0),
			Position = UDim2.fromOffset(74, 0),
			Text = data.label or ("Entity #" .. id),
			TextColor3 = P.text,
			TextSize = 10,
			Parent = row,
		})
		label({
			Size = UDim2.new(1, -230, 1, 0),
			Position = UDim2.fromOffset(224, 0),
			Text = preview(components),
			TextColor3 = P.yellow,
			TextSize = 10,
			Font = Enum.Font.Code,
			Parent = row,
		})

		row.MouseButton1Click:Connect(function()
			selectedId = id
			dirty = true
		end)
	end
end

local function render()
	local snap = lastSnap
	if not snap then
		return
	end

	local entries = entityRows(snap)
	local selectedEntry = nil

	if #entries == 0 then
		selectedId = nil
	else
		local selectedVisible = false
		for _, entry in ipairs(entries) do
			if entry.id == selectedId then
				selectedVisible = true
				break
			end
		end
		if not selectedVisible then
			selectedId = entries[1].id
		end

		for _, entry in ipairs(entries) do
			if entry.id == selectedId then
				selectedEntry = entry
				break
			end
		end
	end

	renderSidebar(snap, #entries)
	renderTable(entries)
	renderDetail(selectedEntry)
end

local pollClock = 0
RunService.Heartbeat:Connect(function()
	if not widget.Enabled then
		return
	end

	local now = os.clock()
	if now - pollClock < 0.12 then
		return
	end
	pollClock = now

	local bridge = ReplicatedStorage:FindFirstChild("ECSDebugBridge")
	if not bridge or not bridge:IsA("StringValue") or bridge.Value == "" then
		statusDot.BackgroundColor3 = P.dim
		statusLabel.Text = "bsECS  |  waiting for runtime"
		statusLabel.TextColor3 = P.mid
		return
	end

	local ok, snap = pcall(HttpService.JSONDecode, HttpService, bridge.Value)
	if ok and snap and snap.entities then
		lastSnap = snap
		statusDot.BackgroundColor3 = P.green
		statusLabel.Text = string.format(
			"bsECS  |  %d entities  |  %d systems  |  live",
			snap.entityCount or 0,
			snap.systemCount or 0
		)
		statusLabel.TextColor3 = P.text
		dirty = true
	end

	if dirty then
		dirty = false
		render()
	end
end)

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
