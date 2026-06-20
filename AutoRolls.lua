-- ══════════════════════════════════════════════════════
--           B.A.R.F Auto Roll | SIMPLIFIED
-- ══════════════════════════════════════════════════════

-- Cleanup old
if game.CoreGui:FindFirstChild("AutoRollUI") then
    game.CoreGui.AutoRollUI:Destroy()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- HTTP Request
local Request = request or http_request or (syn and syn.request) or (http and http.request)

-- ══════════════════════════════════════════════════════
--           CONFIG
-- ══════════════════════════════════════════════════════
local WEBHOOK = ""
local WEBHOOK_ENABLED = false
local TARGET_RARITIES = {}
local ROLL_DELAY = 0.5
local STABLE_TIME = 0.8

local RARITIES = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary",
    "Secret", "Prismatic", "Divine", "Exotic", "Transcended",
    "Celestial", "Eternal"
}

for _, r in ipairs(RARITIES) do
    TARGET_RARITIES[r] = false
end

local Running = false
local TotalRolls = 0
local TotalBought = 0
local StartTime = os.time()
local myPlot = nil
local rollPrompt = nil

-- ══════════════════════════════════════════════════════
--           COLORS
-- ══════════════════════════════════════════════════════
local C = {
    bg = Color3.fromRGB(13, 13, 25),
    accent = Color3.fromRGB(88, 101, 242),
    green = Color3.fromRGB(87, 242, 135),
    red = Color3.fromRGB(237, 66, 69),
    gold = Color3.fromRGB(255, 200, 50),
    text = Color3.fromRGB(220, 220, 240),
    muted = Color3.fromRGB(120, 120, 160),
}

-- ══════════════════════════════════════════════════════
--           HELPERS
-- ══════════════════════════════════════════════════════
local function GetWIB()
    local u = DateTime.now():ToUniversalTime()
    return string.format("%02d:%02d WIB", (u.Hour+7)%24, u.Minute)
end

local function GetUptime()
    local e = os.time() - StartTime
    local h,m,s = math.floor(e/3600), math.floor((e%3600)/60), e%60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function ts()
    local u = DateTime.now():ToUniversalTime()
    return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ", u.Year,u.Month,u.Day,u.Hour,u.Minute,u.Second)
end

local function sendWebhook(title, desc, color)
    if not WEBHOOK_ENABLED or WEBHOOK == "" or not Request then return end
    pcall(function()
        Request({
            Url = WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({embeds={{
                title = title,
                description = desc,
                color = color,
                footer = {text = "⏱ "..GetUptime().." • 🕐 "..GetWIB()},
                timestamp = ts()
            }}})
        })
    end)
end

local function FindPlot()
    myPlot = nil
    rollPrompt = nil
    local map = workspace:FindFirstChild("Map")
    if not map then return false end
    local plots = map:FindFirstChild("Plots")
    if not plots then return false end
    
    for _, plot in ipairs(plots:GetChildren()) do
        if not plot.Name:match("^Plot") then continue end
        local rp = plot:FindFirstChild("RollPlatform")
        if rp then
            local lv = rp:FindFirstChild("Lever")
            if lv then
                -- Cari prompt
                local pp = lv:FindFirstChildWhichIsA("ProximityPrompt", true)
                if pp then
                    myPlot = plot
                    rollPrompt = pp
                    return true
                end
            end
        end
    end
    return false
end

local function GetSeedRarity(obj)
    for _, d in ipairs(obj:GetDescendants()) do
        if d:IsA("StringValue") and d.Name:lower():find("rarity") then
            return d.Value
        end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            for _, r in ipairs(RARITIES) do
                if d.Text:find(r) then return r end
            end
        end
    end
    return nil
end

local function ScanAndBuy()
    local bought = false
    for _, v in ipairs(workspace:GetChildren()) do
        local pp = v:FindFirstChild("BuySeed", true)
        if pp and pp:IsA("ProximityPrompt") then
            local rarity = GetSeedRarity(v)
            if rarity and TARGET_RARITIES[rarity] then
                -- Fire prompt multiple times
                for _ = 1, 5 do
                    pcall(function() fireproximityprompt(pp) end)
                    task.wait(0.1)
                end
                TotalBought = TotalBought + 1
                logAdd("✅ Beli "..v.Name.." ["..rarity.."]", C.green)
                sendWebhook("🌟 Seed Bought", v.Name.." • "..rarity, 16766720)
                bought = true
                break
            end
        end
    end
    return bought
end

-- ══════════════════════════════════════════════════════
--           UI
-- ══════════════════════════════════════════════════════
local PG = Player:WaitForChild("PlayerGui")
local SG = Instance.new("ScreenGui")
SG.Name = "AutoRollUI"
SG.ResetOnSpawn = false
SG.Parent = PG

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 300, 0, 500)
Main.Position = UDim2.new(0.5, -150, 0.5, -250)
Main.BackgroundColor3 = C.bg
Main.BorderSizePixel = 0
Main.Parent = SG
local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 10)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎰 Auto Roll"
Title.TextColor3 = C.text
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0.5, -12)
CloseBtn.BackgroundColor3 = C.red
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = C.text
CloseBtn.TextSize = 11
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header
local CloseCorner = Instance.new("UICorner", CloseBtn)
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Content
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -95)
Content.Position = UDim2.new(0, 0, 0, 40)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 2
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main

local List = Instance.new("UIListLayout", Content)
List.SortOrder = Enum.SortOrder.LayoutOrder
List.Padding = UDim.new(0, 4)
local ListPad = Instance.new("UIPadding", Content)
ListPad.PaddingLeft = UDim.new(0, 8)
ListPad.PaddingRight = UDim.new(0, 8)
ListPad.PaddingTop = UDim.new(0, 6)

-- Rarity buttons
local order = 1
for _, rarity in ipairs(RARITIES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
    btn.BorderSizePixel = 0
    btn.Text = rarity
    btn.TextColor3 = C.muted
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = order
    btn.Parent = Content
    local BtnCorner = Instance.new("UICorner", btn)
    BtnCorner.CornerRadius = UDim.new(0, 6)
    
    btn.MouseButton1Click:Connect(function()
        TARGET_RARITIES[rarity] = not TARGET_RARITIES[rarity]
        btn.BackgroundColor3 = TARGET_RARITIES[rarity] and C.accent or Color3.fromRGB(30, 30, 55)
        btn.TextColor3 = TARGET_RARITIES[rarity] and C.text or C.muted
    end)
    
    order = order + 1
end

-- Webhook URL input
local WebhookLabel = Instance.new("TextLabel")
WebhookLabel.Size = UDim2.new(1, 0, 0, 16)
WebhookLabel.BackgroundTransparency = 1
WebhookLabel.Text = "Webhook URL"
WebhookLabel.TextColor3 = C.muted
WebhookLabel.TextSize = 10
WebhookLabel.Font = Enum.Font.GothamBold
WebhookLabel.TextXAlignment = Enum.TextXAlignment.Left
WebhookLabel.LayoutOrder = order
WebhookLabel.Parent = Content
order = order + 1

local WebhookInput = Instance.new("TextBox")
WebhookInput.Size = UDim2.new(1, 0, 0, 28)
WebhookInput.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
WebhookInput.BorderSizePixel = 0
WebhookInput.Text = WEBHOOK
WebhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
WebhookInput.PlaceholderColor3 = C.muted
WebhookInput.TextColor3 = C.text
WebhookInput.TextSize = 10
WebhookInput.Font = Enum.Font.Gotham
WebhookInput.LayoutOrder = order
WebhookInput.Parent = Content
local InputCorner = Instance.new("UICorner", WebhookInput)
InputCorner.CornerRadius = UDim.new(0, 6)
local InputPad = Instance.new("UIPadding", WebhookInput)
InputPad.PaddingLeft = UDim.new(0, 6)

WebhookInput.FocusLost:Connect(function()
    WEBHOOK = WebhookInput.Text
    WEBHOOK_ENABLED = WEBHOOK ~= ""
end)

order = order + 1

-- Log
local LogLabel = Instance.new("TextLabel")
LogLabel.Size = UDim2.new(1, 0, 0, 16)
LogLabel.BackgroundTransparency = 1
LogLabel.Text = "LOG"
LogLabel.TextColor3 = C.muted
LogLabel.TextSize = 10
LogLabel.Font = Enum.Font.GothamBold
LogLabel.LayoutOrder = order
LogLabel.Parent = Content
order = order + 1

local LogBox = Instance.new("TextLabel")
LogBox.Size = UDim2.new(1, 0, 0, 80)
LogBox.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
LogBox.BorderSizePixel = 0
LogBox.Text = ""
LogBox.TextColor3 = C.text
LogBox.TextSize = 9
LogBox.Font = Enum.Font.Gotham
LogBox.TextXAlignment = Enum.TextXAlignment.Left
LogBox.TextYAlignment = Enum.TextYAlignment.Top
LogBox.TextWrapped = true
LogBox.LayoutOrder = order
LogBox.Parent = Content
local LogCorner = Instance.new("UICorner", LogBox)
LogCorner.CornerRadius = UDim.new(0, 6)
local LogPad = Instance.new("UIPadding", LogBox)
LogPad.PaddingLeft = UDim.new(0, 6)
LogPad.PaddingTop = UDim.new(0, 4)

local logLines = {}
function logAdd(msg, color)
    table.insert(logLines, msg)
    if #logLines > 10 then table.remove(logLines, 1) end
    LogBox.Text = table.concat(logLines, "\n")
end

-- Stats
local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(1, 0, 0, 50)
StatsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
StatsFrame.BorderSizePixel = 0
StatsFrame.Parent = Main
StatsFrame.Position = UDim2.new(0, 0, 1, -95)

local StatsList = Instance.new("UIListLayout", StatsFrame)
StatsList.FillDirection = Enum.FillDirection.Horizontal
StatsList.SortOrder = Enum.SortOrder.LayoutOrder
StatsList.Padding = UDim.new(0, 8)
local StatsPad = Instance.new("UIPadding", StatsFrame)
StatsPad.PaddingLeft = UDim.new(0, 8)
StatsPad.PaddingTop = UDim.new(0, 4)

local RollsLabel = Instance.new("TextLabel")
RollsLabel.Size = UDim2.new(0, 70, 1, 0)
RollsLabel.BackgroundTransparency = 1
RollsLabel.Text = "Rolls: 0"
RollsLabel.TextColor3 = C.text
RollsLabel.TextSize = 11
RollsLabel.Font = Enum.Font.GothamBold
RollsLabel.Parent = StatsFrame

local BoughtLabel = Instance.new("TextLabel")
BoughtLabel.Size = UDim2.new(0, 70, 1, 0)
BoughtLabel.BackgroundTransparency = 1
BoughtLabel.Text = "Bought: 0"
BoughtLabel.TextColor3 = C.green
BoughtLabel.TextSize = 11
BoughtLabel.Font = Enum.Font.GothamBold
BoughtLabel.Parent = StatsFrame

local UptimeLabel = Instance.new("TextLabel")
UptimeLabel.Size = UDim2.new(0, 70, 1, 0)
UptimeLabel.BackgroundTransparency = 1
UptimeLabel.Text = "00:00:00"
UptimeLabel.TextColor3 = C.muted
UptimeLabel.TextSize = 11
UptimeLabel.Font = Enum.Font.Gotham
UptimeLabel.Parent = StatsFrame

task.spawn(function()
    while true do
        task.wait(1)
        UptimeLabel.Text = GetUptime()
    end
end)

-- Run button
local RunBtn = Instance.new("TextButton")
RunBtn.Size = UDim2.new(1, -16, 0, 38)
RunBtn.Position = UDim2.new(0, 8, 1, -45)
RunBtn.BackgroundColor3 = C.accent
RunBtn.BorderSizePixel = 0
RunBtn.Text = "▶ Start"
RunBtn.TextColor3 = C.text
RunBtn.TextSize = 12
RunBtn.Font = Enum.Font.GothamBold
RunBtn.Parent = Main
local RunCorner = Instance.new("UICorner", RunBtn)
RunCorner.CornerRadius = UDim.new(0, 8)

-- ══════════════════════════════════════════════════════
--           MAIN LOOP
-- ══════════════════════════════════════════════════════
local function RunLoop()
    if not FindPlot() then
        logAdd("❌ Plot not found!", C.red)
        Running = false
        RunBtn.Text = "▶ Start"
        RunBtn.BackgroundColor3 = C.accent
        return
    end
    
    logAdd("✅ Plot found!", C.green)
    logAdd("Auto roll started!", C.gold)
    sendWebhook("🎰 Auto Roll Started", "Rolling for: "..table.concat(RARITIES, ", "), 3066993)
    
    while Running do
        local lastChange = os.clock()
        
        local connAdd = workspace.ChildAdded:Connect(function(v)
            if v:FindFirstChild("BuySeed", true) then
                lastChange = os.clock()
            end
        end)
        
        local connRem = workspace.ChildRemoved:Connect(function(v)
            if v:FindFirstChild("BuySeed", true) then
                lastChange = os.clock()
            end
        end)
        
        -- Roll
        local ok = pcall(function() fireproximityprompt(rollPrompt) end)
        if ok then
            TotalRolls = TotalRolls + 1
            RollsLabel.Text = "Rolls: "..TotalRolls
            logAdd("Roll #"..TotalRolls, C.muted)
        end
        
        -- Wait for stable
        task.wait(0.5)
        local timeout = os.clock() + 30
        while os.clock() - lastChange < STABLE_TIME and os.clock() < timeout and Running do
            task.wait(0.05)
        end
        
        connAdd:Disconnect()
        connRem:Disconnect()
        
        -- Scan and buy
        ScanAndBuy()
        
        task.wait(ROLL_DELAY)
    end
    
    logAdd("Stopped.", C.red)
    sendWebhook("⏹ Auto Roll Stopped", "Rolls: "..TotalRolls.."\nBought: "..TotalBought, 15158332)
end

RunBtn.MouseButton1Click:Connect(function()
    Running = not Running
    if Running then
        RunBtn.Text = "⏹ Stop"
        RunBtn.BackgroundColor3 = C.red
        task.spawn(RunLoop)
    else
        RunBtn.Text = "▶ Start"
        RunBtn.BackgroundColor3 = C.accent
    end
end)

logAdd("Ready! Select rarity and start.", C.muted)
print("✅ Auto Roll Loaded!")
