local rs = game:GetService("RunService")
local mps = game:GetService('MarketplaceService')

local owner = game.Players.LocalPlayer
local mouse = owner:GetMouse()

local MusicVisualizer = owner.PlayerGui:WaitForChild('MusicVisualizer')

local windows = require(MusicVisualizer.Windows)
local audio = MusicVisualizer.AudioPlayer
local sound = MusicVisualizer.Sound

local analyzer = audio.AudioAnalyzer
local audiofader = audio.AudioFader

local ui = MusicVisualizer.UI
local bg = ui.BG_Gradient
local bgGlow = ui.BG_Glow
local title = ui.Title
local lineSpectrum = ui.LineSpectrum
local spectrum = ui.Spectrum
local controls = ui.Controls
local interactionui = controls.Interaction
local sliders = controls.Sliders
local slider = sliders.Slider
local dropdown = interactionui.Dropdown
local timeui = ui.TimePosition
local timebar = timeui.Timebar
local marker = timebar.Marker
local monitorsui = ui.Monitors

BANDS = 10

local lastBands = BANDS
local last_time = 0.01

AUDIO_ID = 9061578134
COLOR1 = '0,255,0'
COLOR2 = '255,255,0'

BG_GRADIENT = true
BG_GLOW = true
LINESPECTRUM = false
SPECTRUM = true
BORDER = true
RMSLEVEL = true
RAINBOW_1 = false
RAINBOW_2 = false

INTENSITY, MIN_INTENSITY, MAX_INTENSITY = 10,0,100
BOUNCE, MIN_BOUNCE, MAX_BOUNCE = 2,0,5
VOLUME, MIN_VOLUME, MAX_VOLUME = 1,0,3
BANDS, MIN_BANDS, MAX_BANDS = 128,0,512
CONTROL1, MIN_CONTROL1, MAX_CONTROL1 = 1,0,10
CONTROL2, MIN_CONTROL2, MAX_CONTROL2 = 1,0,10

NAME = nil
WINDOW = windows.hamming

local bars = {}
local points = {}
local lines = {}
local visualizers = {}

local xValues = {}
local yValues = {}

local controls = {
	'AUDIO_ID',
	'COLOR1',
	'COLOR2',
}
local switch_controls = {
	'BG_GRADIENT',
	'BG_GLOW',
	'LINESPECTRUM',
	'SPECTRUM',
	'BORDER',
	'RMSLEVEL',
	'RAINBOW_1',
	'RAINBOW_2'
}
local slider_controls = {
	'INTENSITY',
	'BOUNCE',
	'VOLUME',
	'BANDS',
	'CONTROL1',
	'CONTROL2',
}
local monitors = {
	'RmsLevel'
}
local ui_gradients = {}

local function lerp(a, b, t)
	return a + (b-a) * t
end

local function inverseLerp(a, b, x)
	return (x-a)/(b-a)
end

local function plotLine(Line,PointA, PointB)
	local Distance = math.sqrt(math.pow(PointA.X-PointB.X, 2) + math.pow(PointA.Y-PointB.Y, 2))
	local Center = Vector2.new((PointA.X + PointB.X)/2, (PointA.Y + PointB.Y)/2)	
	local Rotation = math.atan2(PointA.Y - PointB.Y, PointA.X - PointB.X)
	local LineThickness = 1

	Line.Visible = true
	Line.Size = UDim2.new(0, Distance, 0, LineThickness)
	Line.AnchorPoint = Vector2.new(0.5,0.5)
	Line.Position = UDim2.new(0, Center.X, 0, Center.Y)
	Line.Rotation = math.deg(Rotation)
end

local function createBars(amount)
	for i,v in bars do
		v:Destroy()
	end

	bars = {}

	for i=1,amount do
		local bar = spectrum.BarTemplate:Clone()
		bar.Name = 'Bar'
		bar.Size = UDim2.new(0,math.ceil(spectrum.AbsoluteSize.X/amount),0,0)
		bar.AnchorPoint = Vector2.new(0.5,0)
		bar.Visible = true
		bar.Parent = spectrum

		table.insert(bars,bar)
	end
end

local function createLines(amount)
	for i,v in lines do
		v:Destroy()
	end

	lines = {}

	for i=1,amount do
		local line = lineSpectrum.LineTemplate:Clone()
		line.Name = 'Line'
		line.Size = UDim2.new(0,math.ceil(spectrum.AbsoluteSize.X/amount),0,1)
		line.Visible = false
		line.Parent = lineSpectrum

		table.insert(lines,line)
	end
end

for i,v in ui:GetDescendants() do
	if v:IsA('TextLabel') or v:IsA('TextBox') or v:IsA('TextButton') then
		v.Font = title.Font
	end
	if v:IsA('UIGradient') then
		if #v.Color.Keypoints > 2 then continue end
		v.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,Color3.fromRGB(unpack(string.split(COLOR1,',')))),
			ColorSequenceKeypoint.new(1,Color3.fromRGB(unpack(string.split(COLOR2,','))))
		})

		table.insert(ui_gradients,v)
	end
end

table.insert(visualizers,lineSpectrum)
table.insert(visualizers,spectrum)
table.insert(visualizers,bg)
table.insert(visualizers,bgGlow)

bg.Visible = true

marker.ImageButton.MouseEnter:Connect(function()
	marker.ImageButton.BackgroundColor3 = Color3.fromRGB(100,100,100)
end)

marker.ImageButton.MouseLeave:Connect(function()
	marker.ImageButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
end)

local connection = nil
marker.ImageButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		connection = rs.RenderStepped:Connect(function()
			local timepos = audio.TimePosition
			local timelength = audio.TimeLength
			local x = math.clamp(inverseLerp(timebar.AbsolutePosition.X,timebar.AbsoluteSize.X+timebar.AbsolutePosition.X,mouse.X),0,1)
			local newtime = lerp(0,timelength,x)

			audio.TimePosition = newtime
			sound.TimePosition = newtime
			marker.Size = UDim2.fromScale(x,1)
			timeui.TextLabel.Text = string.format("%i:%02i", timepos / 60, timepos % 60) ..' / ' .. string.format("%i:%02i", timelength / 60, timelength % 60)
		end)
	end
end)

marker.ImageButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if connection then 
			connection:Disconnect() 
			connection = nil
		end
	end
end)

dropdown.MouseButton1Click:Connect(function()
	dropdown.ScrollingFrame.Visible = not dropdown.ScrollingFrame.Visible
	dropdown.ImageLabel.Rotation = dropdown.ScrollingFrame.Visible and 180 or 0
end)

task.spawn(function()
	while task.wait() do
		if connection then continue end
		local timepos = audio.TimePosition
		local timelength = audio.TimeLength
		marker.Size = UDim2.fromScale(inverseLerp(0,timelength,timepos),1)
		timeui.TextLabel.Text = string.format("%i:%02i", timepos / 60, timepos % 60) ..' / ' .. string.format("%i:%02i", timelength / 60, timelength % 60)
	end
end)

for i,v in windows do	
	local template = dropdown.ScrollingFrame.Dropdown:Clone()
	template.Name = i:upper()
	template.Text = i:upper()
	template.Visible = true
	template.Parent = dropdown.ScrollingFrame

	if WINDOW == v then
		template.BackgroundColor3 = Color3.fromRGB(30,30,30)
		dropdown.Text = "WINDOW: ".. i:upper()
	end

	template.MouseButton1Click:Connect(function()
		dropdown.Text = "WINDOW: ".. i:upper()

		for i,v in dropdown.ScrollingFrame:GetChildren() do
			if v.Name == 'Dropdown' or v.ClassName ~= 'TextButton' then continue end

			v.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
		end

		template.BackgroundColor3 = Color3.fromRGB(30,30,30)

		WINDOW = v

		local paramlength,variadic = debug.info(v,'a')

		for i,v in sliders:GetChildren() do
			if v.Name:find('CONTROL') then
				v.Visible = false

				if tonumber(v.Name:sub(-1,-1)) <= paramlength-1 then
					v.Visible = true
				end
			end
		end
	end)
end

for i,v in controls do
	local template = interactionui.Template:Clone()
	template.Name = v
	template.PlaceholderText = v..': '..getfenv()[v]
	template.Visible = true
	template.Parent = interactionui

	if v:find('COLOR') then
		template.PlaceholderColor3 = Color3.fromRGB(unpack(string.split(getfenv()[v],',')))
		
		task.spawn(function()
			while task.wait() do
				if template:IsFocused() == false then
					local r,g,b = unpack(string.split(getfenv()[v],','))
					
					r = math.floor(r)
					g = math.floor(g)
					b = math.floor(b)
					
					template.PlaceholderText = `{v}: {r},{g},{b}`
					template.PlaceholderColor3 = Color3.fromRGB(unpack(string.split(getfenv()[v],',')))
				end
			end
		end)
	end

	template.FocusLost:Connect(function(enter)
		if enter then
			if v:find('COLOR') then
				if not template.Text:match("^%d+,%d+,%d+$") then
					template.Text = ''

					return
				end

				template.PlaceholderColor3 = Color3.fromRGB(unpack(string.split(template.Text,',')))
			end

			getfenv()[v] = template.Text
			template.PlaceholderText = template.Text
		end
		template.Text = ''
	end)
end

for i,v in switch_controls do
	local template = interactionui.Switch:Clone()
	template.Name = v
	template.TextLabel.Text = v
	template.Visible = true
	template.Parent = interactionui

	local buttons = template.Buttons

	if getfenv()[v] then
		buttons.On.TextColor3 = Color3.fromRGB(0,255,0)
		buttons.Off.TextColor3 = Color3.fromRGB(70,0,0)
	else
		buttons.On.TextColor3 = Color3.fromRGB(0,70,0)
		buttons.Off.TextColor3 = Color3.fromRGB(255,0,0)
	end

	buttons.On.MouseButton1Click:Connect(function()
		getfenv()[v] = true
		buttons.On.TextColor3 = Color3.fromRGB(0,255,0)
		buttons.Off.TextColor3 = Color3.fromRGB(70,0,0)
	end)
	buttons.Off.MouseButton1Click:Connect(function()
		getfenv()[v] = false
		buttons.On.TextColor3 = Color3.fromRGB(0,70,0)
		buttons.Off.TextColor3 = Color3.fromRGB(255,0,0)
	end)
end

for i,v in slider_controls do
	local default,min,max = getfenv()[v], getfenv()['MIN_'..v], getfenv()['MAX_'..v]
	local connection = nil

	local template = sliders.Slider:Clone()
	template.Name = v
	template.TextBox.PlaceholderText = v .. '\n' .. string.format("%.2f",getfenv()[v])
	template.Visible = true
	template.Parent = sliders

	local paramlength,variadic = debug.info(WINDOW,'a')

	if v:find('CONTROL') then
		template.Visible = false

		if tonumber(v:sub(-1,-1)) <= paramlength-1 then
			template.Visible = true
		end
	end
	local background = template.Background.SliderBG
	local bar = background.Bar
	local handle = bar.Handle
	local increment = background.Increment

	for i=max,min,-1 do
		if max > 100 then
			if i ~= default and i % 100 ~= 0 then
				continue
			end
		elseif max > 10 then
			if i ~= default and i % 10 ~= 0 then
				continue
			end
		end

		local increment = increment:Clone()
		increment.Visible = true
		increment.Size = UDim2.new(1,0,0,background.AbsoluteSize.Y/max)
		increment.Name = i
		increment.Position = UDim2.new(0.5,0,0,background.AbsoluteSize.Y-(background.AbsoluteSize.Y/max)*i)
		increment.label1.Text = i
		increment.label2.Text = i
		increment.Parent = background

		if max > 10 then
			if i-1 == default or i+1 == default then
				increment:Destroy()
			end
		end

	end

	handle.Position = UDim2.new(0.5,0,0,background.AbsoluteSize.Y-(background.AbsoluteSize.Y/max)*default)

	template.TextBox.FocusLost:Connect(function(enter)
		if enter then
			if tonumber(template.TextBox.Text) then
				getfenv()[v] = math.clamp(tonumber(template.TextBox.Text),min,max)

				handle.Position = UDim2.new(0.5,0,0,background.AbsoluteSize.Y-(background.AbsoluteSize.Y/max)*getfenv()[v])

				template.TextBox.PlaceholderText = v .. '\n' .. string.format("%.2f",getfenv()[v])
			end
		end
		template.TextBox.Text = ''
	end)

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			connection = rs.RenderStepped:Connect(function()
				local y = math.clamp(inverseLerp(bar.AbsolutePosition.Y, bar.AbsoluteSize.Y + bar.AbsolutePosition.Y, mouse.Y), 0, 1)

				handle.Position = UDim2.fromScale(0.5, y)

				getfenv()[v] = lerp(max, min, y)
				template.TextBox.PlaceholderText = v .. '\n' .. string.format("%.2f", getfenv()[v])
			end)
		end
	end)


	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if connection then 
				connection:Disconnect() 
				connection = nil
			end
		end
	end)

	handle.MouseEnter:Connect(function()
		handle.BackgroundColor3 = Color3.fromRGB(100,100,100)
	end)

	handle.MouseLeave:Connect(function()
		handle.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	end)
end

for i,v in monitors do
	local template = monitorsui.Template:Clone()
	template.Name = v
	template.Title.Text = v
	template.Visible = true
	template.Parent = monitorsui

	local meter = template.Background.Meter
	local levels = template.Levels
	local lastx = 0

	table.insert(ui_gradients,meter.UIGradient)
	table.insert(visualizers,template)

	audio:GetPropertyChangedSignal('AssetId'):Connect(function()
		local succ,err = pcall(function()
			NAME = mps:GetProductInfo(AUDIO_ID).Name
		end)

		title.Text = NAME

		audio.TimePosition = 0
		lastx = 0
	end)

	rs.RenderStepped:Connect(function()
		local dt = rs.RenderStepped:Wait()

		if analyzer[v] > lastx then
			for i,v in levels:GetChildren() do
				if v.Name == 'Increment' or v:IsA('UIListLayout') then continue end
				v:Destroy()
			end
			for i=10,1,-1 do
				local increment = levels.Increment:Clone()
				increment.Name = tostring((analyzer[v]/10)*i):sub(1,4)
				increment.TextLabel.Text = tostring((analyzer[v]/10)*i):sub(1,4)
				increment.Visible = true
				increment.Parent = levels
			end

			meter.Size = UDim2.new(1,0,1,0)

			lastx = analyzer[v]
		else
			local y = math.clamp(inverseLerp(0,lastx,analyzer[v]),0,1)

			meter.Size = meter.Size:Lerp(UDim2.new(1,0,y,0),dt*3)
		end
	end)
end

createBars(BANDS)
createLines(BANDS)

sound:Play()
audio:Play()

local t = 0

rs.RenderStepped:Connect(function()
	local dt = game["Run Service"].RenderStepped:Wait()

	local succ,err = pcall(function()
		audio.AssetId = 'rbxassetid://'..tostring(AUDIO_ID)
		sound.SoundId = 'rbxassetid://'..tostring(AUDIO_ID)
	end)

	local rawSpectrum = analyzer:GetSpectrum()
	local spectrumData

	if WINDOW == nil then 
		spectrumData = rawSpectrum
	else
		spectrumData = WINDOW(rawSpectrum, CONTROL1, CONTROL2)
	end

	local rms = analyzer.RmsLevel

	local loudness = sound.PlaybackLoudness/1000
	local spectrum_gradients = {}
	local height = 0
	local height2 = 0
	local peak_size = 0
	
	if RAINBOW_1 then
		local h,s,v = Color3.fromRGB(unpack(string.split(COLOR1,','))):ToHSV()
		
		h += t/1000
		
		if h >= 1 then h = 0.01 end

		local color = Color3.fromHSV(h,s,v)
		
		COLOR1 = `{color.R*255},{color.G*255},{color.B*255}`
	end
	if RAINBOW_2 then
		local h,s,v = Color3.fromRGB(unpack(string.split(COLOR2,','))):ToHSV()
		
		h += t/1000
		
		if h >= 1 then h = 0.01 end
		
		local color = Color3.fromHSV(h,s,v)
		
		COLOR2 = `{color.R*255},{color.G*255},{color.B*255}`
	end
	
	BANDS = math.floor(BANDS)
	audiofader.Volume = VOLUME

	if BANDS ~= lastBands then
		for i=1,BANDS do

			yValues[i] = 0
		end

		createBars(BANDS)
		createLines(BANDS)

		lastBands = BANDS
	end

	for i,v in visualizers do
		v.Visible = getfenv()[v.Name:upper()]
	end

	if BORDER then
		spectrum.BarTemplate.BorderSizePixel = 1

		for i,v in bars do
			v.BorderSizePixel = 1
		end
	else
		spectrum.BarTemplate.BorderSizePixel = 0

		for i,v in bars do
			v.BorderSizePixel = 0
		end
	end

	for i,v in spectrumData do
		if i>BANDS then
			break
		end

		local val = math.clamp(math.clamp(v*10000-5,0,5000)*INTENSITY,0,spectrum.AbsoluteSize.Y)
		local val2 = math.clamp(spectrumData[i+1]*10000*INTENSITY,0,spectrum.AbsoluteSize.Y)

		height = lerp(yValues[i],val,dt*BOUNCE)

		if i == 1 or i == BANDS or i % math.ceil(BANDS/20) == 0 then
			local ti = (i == BANDS and 1 or inverseLerp(0,BANDS,i-1)) or i
			local value = (inverseLerp(0,spectrum.AbsoluteSize.Y,height)) or i

			if #spectrum_gradients == 20 then
				table.remove(spectrum_gradients,20)
			end

			table.insert(spectrum_gradients,NumberSequenceKeypoint.new(ti,value))
		end

		if i<BANDS then
			height2 = lerp(yValues[i+1],val2,dt*BOUNCE)
		end

		yValues[i] = height
		yValues[i+1] = height2

		bars[i].Size = UDim2.new(0, bars[i].Size.X.Offset, 0, height)

		bars[i].UIGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,Color3.fromRGB(unpack(string.split(COLOR1,',')))),
			ColorSequenceKeypoint.new(1,Color3.fromRGB(unpack(string.split(COLOR2,','))))
		})

		if bars[i].AbsoluteSize.Y>peak_size then
			peak_size = bars[i].AbsoluteSize.Y
			t = inverseLerp(0,spectrum.AbsoluteSize.Y,peak_size)
		end

		if LINESPECTRUM then
			if i < #lines then
				local bar = bars[i]
				local nextBar = bars[i+1]

				local barAbsPos = {
					X = bar.AbsolutePosition.X+bar.AbsoluteSize.X/2,
					Y = ui.AbsoluteSize.Y-yValues[i],
				}
				local nextBarAbsPos = {
					X = nextBar.AbsolutePosition.X+nextBar.AbsoluteSize.X/2,
					Y = ui.AbsoluteSize.Y-yValues[i+1],
				}

				plotLine(lines[i],barAbsPos,nextBarAbsPos)
			end
		end
	end

	if BG_GLOW then
		bg.BackgroundColor3 = Color3.new(1,1,1)
		bgGlow.UIGradient.Transparency = NumberSequence.new(spectrum_gradients)
	else
		bg.BackgroundColor3 = Color3.fromRGB(50,50,50)
	end

	for i,v in ui_gradients do
		v.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,Color3.fromRGB(unpack(string.split(COLOR1,',')))),
			ColorSequenceKeypoint.new(1,Color3.fromRGB(unpack(string.split(COLOR2,','))))
		})
	end

	if tostring(t) ~= 'nan' then
		local _time = lerp(last_time,math.clamp(lerp(0.01,1,t/2),0.01,1),dt)
		local y = math.clamp(lerp(0,0.5,t),0,0.5)

		if BG_GRADIENT then
			bg.Size = UDim2.fromScale(1,y)
			bg.UIGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,Color3.fromRGB(unpack(string.split(COLOR1,',')))),
				ColorSequenceKeypoint.new(0.1,Color3.fromRGB(unpack(string.split(COLOR2,',')))),
				ColorSequenceKeypoint.new(0.99,Color3.fromRGB(0,0,0)),
				ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0)),
			})
		end

		last_time = _time
	end
end)

game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
