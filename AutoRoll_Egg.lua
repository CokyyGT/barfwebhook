-- ══════════════════════════════════════════════════════
--      B.A.R.F Auto Roll + Auto Egg | COMBINED
-- ══════════════════════════════════════════════════════

-- Cleanup
if game.CoreGui:FindFirstChild("AutoRollUI") then
    game.CoreGui.AutoRollUI:Destroy()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer
local Request = request or http_request or (syn and syn.request) or (http and http.request)

local Running = false
local TotalRolls = 0
local TotalBought = 0
local TotalEggBought = 0
local StartTime = os.time()
local myPlot = nil
local rollPrompt = nil
local petMerchant = nil
local ActiveMode = "Roll" -- Roll atau Egg

-- ══════════════════════════════════════════════════════
--           CONFIG
-- ══════════════════════════════════════════════════════
local TARGET_RARITIES = {
    Common=false, Uncommon=false, Rare=false, Epic=false,
    Legendary=false, Secret=false, Prismatic=false, Divine=false,
    Exotic=false, Transcended=false, Celestial=false, Eternal=false
}

local TARGET_EGGS = {
    Common=false, Uncommon=false, Rare=false, Epic=false,
    Legendary=false, Secret=false, Prismatic=false, Divine=false,
    Exotic=false, Transcended=false, Celestial=false, Eternal=false
}

local WEBHOOK = ""
local WEBHOOK_ENABLED = false
local ROLL_DELAY = 0.5
local STABLE_TIME = 0.8

-- ══════════════════════════════════════════════════════
--           COLORS
-- ══════════════════════════════════════════════════════
local C = {
    bg = Color3.fromRGB(13, 13, 25),
    panel = Color3.fromRGB(20, 20, 38),
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
    return string.format("%02d:%02d:%02d", math.floor(e/3600), math.floor((e%3600)/60), e%60)
end

local function SendWebhook(title, desc, color)
    if not WEBHOOK_ENABLED or WEBHOOK == "" or not Request then return end
    pcall(function()
        Request({
            Url = WEBHOOK, Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({embeds={{
                title = title, description = desc, color = color,
                footer = {text = "⏱ "..GetUptime().." • 🕐 "..GetWIB()}
            }}})
        })
    end)
end

-- ══════════════════════════════════════════════════════
--           ROLL MODE
-- ══════════════════════════════════════════════════════
local function FindPlot()
    myPlot = nil; rollPrompt = nil
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

local function ScanSeeds()
    local seeds = {}
    for _, v in ipairs(workspace:GetChildren()) do
        local pp = v:FindFirstChild("BuySeed", true)
        if pp and pp:IsA("ProximityPrompt") then
            local rarity = nil
            for _, d in ipairs(v:GetDescendants()) do
                if d:IsA("StringValue") and d.Name:lower():find("rarity") then
                    rarity = d.Value; break
                end
            end
            if rarity and TARGET_RARITIES[rarity] then
                table.insert(seeds, {name=v.Name, rarity=rarity, prompt=pp})
            end
        end
    end
    return seeds
end

-- ══════════════════════════════════════════════════════
--           EGG MODE
-- ══════════════════════════════════════════════════════
local function FindPetMerchant()
    petMerchant = workspace:FindFirstChild("PetMerchant") 
                  or workspace:FindFirstChild("petmerchant")
                  or workspace:FindFirstChild("Pet Merchant")
    return petMerchant ~= nil
end

local function ScanEggs()
    local results = {}
    if not petMerchant then return results end
    
    for i = 1, 5 do
        local stock = petMerchant:FindFirstChild("Podium"..i.."Stock")
        local lever = petMerchant:FindFirstChild("Podium"..i.."Lever")
        
        if stock and lever then
            local eggName = nil
            for _, d in ipairs(stock:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then
                    eggName = d.Text; break
                end
            end
            
            local pp = lever:FindFirstChildWhichIsA("ProximityPrompt", true)
            
            if eggName and pp then
                table.insert(results, {
                    podium = i,
                    eggName = eggName,
                    prompt = pp,
                })
            end
        end
    end
    return results
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
local MC = Instance.new("UICorner", Main)
MC.CornerRadius = UDim.new(0, 10)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
Header.BorderSizePixel = 0
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎰 Auto Roll/Egg"
Title.TextColor3 = C.text
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0.5, -12)
CloseBtn.BackgroundColor3 = C.red
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextSize = 11
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Tab buttons
local TabRoll = Instance.new("TextButton")
TabRoll.Size = UDim2.new(0.5, -2, 0, 30)
TabRoll.Position = UDim2.new(0, 0, 1, -70)
TabRoll.BackgroundColor3 = C.accent
TabRoll.BorderSizePixel = 0
TabRoll.Text = "🎰 Roll"
TabRoll.TextSize = 11
TabRoll.Font = Enum.Font.GothamBold
TabRoll.Parent = Main

local TabEgg = Instance.new("TextButton")
TabEgg.Size = UDim2.new(0.5, -2, 0, 30)
TabEgg.Position = UDim2.new(0.5, 2, 1, -70)
TabEgg.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
TabEgg.BorderSizePixel = 0
TabEgg.Text = "🥚 Egg"
TabEgg.TextSize = 11
TabEgg.Font = Enum.Font.GothamBold
TabEgg.Parent = Main

-- Content
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, 0, 1, -100)
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
local LP = Instance.new("UIPadding", Content)
LP.PaddingLeft = UDim.new(0, 8)
LP.PaddingRight = UDim.new(0, 8)
LP.PaddingTop = UDim.new(0, 6)

-- Roll rarity buttons
local RollSection = Instance.new("TextLabel")
RollSection.Size = UDim2.new(1, 0, 0, 20)
RollSection.BackgroundTransparency = 1
RollSection.Text = "TARGET RARITY"
RollSection.TextColor3 = C.muted
RollSection.TextSize = 10
RollSection.Font = Enum.Font.GothamBold
RollSection.LayoutOrder = 1
RollSection.Parent = Content

local rarities = {"Common","Uncommon","Rare","Epic","Legendary","Secret","Prismatic","Divine","Exotic","Transcended","Celestial","Eternal"}
local order = 2
for _, rarity in ipairs(rarities) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
    btn.BorderSizePixel = 0
    btn.Text = rarity
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.TextColor3 = C.muted
    btn.LayoutOrder = order
    btn.Parent = Content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    btn.MouseButton1Click:Connect(function()
        TARGET_RARITIES[rarity] = not TARGET_RARITIES[rarity]
        btn.BackgroundColor3 = TARGET_RARITIES[rarity] and C.accent or Color3.fromRGB(30, 30, 55)
        btn.TextColor3 = TARGET_RARITIES[rarity] and C.text or C.muted
    end)
    order = order + 1
end

-- Webhook input
local WebhookLabel = Instance.new("TextLabel")
WebhookLabel.Size = UDim2.new(1, 0, 0, 16)
WebhookLabel.BackgroundTransparency = 1
WebhookLabel.Text = "WEBHOOK URL"
WebhookLabel.TextColor3 = C.muted
WebhookLabel.TextSize = 10
WebhookLabel.Font = Enum.Font.GothamBold
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
WebhookInput.TextSize = 9
WebhookInput.Font = Enum.Font.Gotham
WebhookInput.LayoutOrder = order
WebhookInput.Parent = Content
Instance.new("UICorner", WebhookInput).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", WebhookInput).PaddingLeft = UDim.new(0, 6)
WebhookInput.FocusLost:Connect(function()
    WEBHOOK = WebhookInput.Text
    WEBHOOK_ENABLED = WEBHOOK ~= ""
end)
order = order + 1

-- Log
local LogBox = Instance.new("TextLabel")
LogBox.Size = UDim2.new(1, 0, 0, 60)
LogBox.BackgroundColor3 = C.panel
LogBox.BorderSizePixel = 0
LogBox.Text = "Ready!"
LogBox.TextColor3 = C.text
LogBox.TextSize = 9
LogBox.Font = Enum.Font.Gotham
LogBox.TextXAlignment = Enum.TextXAlignment.Left
LogBox.TextYAlignment = Enum.TextYAlignment.Top
LogBox.TextWrapped = true
LogBox.LayoutOrder = order
LogBox.Parent = Content
Instance.new("UICorner", LogBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", LogBox).PaddingLeft = UDim.new(0, 6)

local logLines = {}
local function logAdd(msg, color)
    table.insert(logLines, msg)
    if #logLines > 6 then table.remove(logLines, 1) end
    LogBox.Text = table.concat(logLines, "\n")
    LogBox.TextColor3 = color or C.text
end

-- Stats
local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(1, 0, 0, 30)
StatsFrame.BackgroundColor3 = C.panel
StatsFrame.BorderSizePixel = 0
StatsFrame.Parent = Main
StatsFrame.Position = UDim2.new(0, 0, 1, -70)

local Stats = Instance.new("UIListLayout", StatsFrame)
Stats.FillDirection = Enum.FillDirection.Horizontal
Stats.SortOrder = Enum.SortOrder.LayoutOrder
Stats.Padding = UDim.new(0, 4)
Instance.new("UIPadding", StatsFrame).PaddingLeft = UDim.new(0, 6)

local StatLabel = Instance.new("TextLabel")
StatLabel.Size = UDim2.new(0, 60, 1, 0)
StatLabel.BackgroundTransparency = 1
StatLabel.Text = "0 • 0 • 00:00:00"
StatLabel.TextSize = 10
StatLabel.Font = Enum.Font.GothamBold
StatLabel.TextColor3 = C.text
StatLabel.Parent = StatsFrame

task.spawn(function()
    while true do
        task.wait(1)
        StatLabel.Text = TotalRolls.." • "..TotalBought.." • "..GetUptime()
    end
end)

-- Run button
local RunBtn = Instance.new("TextButton")
RunBtn.Size = UDim2.new(1, -16, 0, 28)
RunBtn.Position = UDim2.new(0, 8, 1, -38)
RunBtn.BackgroundColor3 = C.accent
RunBtn.BorderSizePixel = 0
RunBtn.Text = "▶ Start"
RunBtn.TextSize = 12
RunBtn.Font = Enum.Font.GothamBold
RunBtn.Parent = Main
Instance.new("UICorner", RunBtn).CornerRadius = UDim.new(0, 8)

-- ══════════════════════════════════════════════════════
--           MAIN LOOPS
-- ══════════════════════════════════════════════════════
local function RollLoop()
    if not FindPlot() then
        logAdd("❌ Plot not found!", C.red)
        return
    end
    logAdd("✅ Roll mode started!", C.green)
    
    while Running and ActiveMode == "Roll" do
        local lastChange = os.clock()
        local connAdd = workspace.ChildAdded:Connect(function(v)
            if v:FindFirstChild("BuySeed", true) then lastChange = os.clock() end
        end)
        
        local ok = pcall(function() fireproximityprompt(rollPrompt) end)
        if ok then
            TotalRolls = TotalRolls + 1
            logAdd("Roll #"..TotalRolls, C.muted)
        end
        
        task.wait(0.5)
        local timeout = os.clock() + 30
        while os.clock() - lastChange < STABLE_TIME and os.clock() < timeout and Running do
            task.wait(0.05)
        end
        connAdd:Disconnect()
        
        local seeds = ScanSeeds()
        if #seeds > 0 then
            local seed = seeds[1]
            pcall(function() fireproximityprompt(seed.prompt) end)
            TotalBought = TotalBought + 1
            logAdd("✅ Beli "..seed.name, C.green)
        end
        
        task.wait(ROLL_DELAY)
    end
end

local function EggLoop()
    if not FindPetMerchant() then
        logAdd("❌ PetMerchant not found!", C.red)
        return
    end
    logAdd("✅ Egg mode started!", C.green)
    
    while Running and ActiveMode == "Egg" do
        local eggs = ScanEggs()
        for _, egg in ipairs(eggs) do
            if TARGET_EGGS[egg.eggName] then
                pcall(function() fireproximityprompt(egg.prompt) end)
                TotalEggBought = TotalEggBought + 1
                logAdd("✅ Beli "..egg.eggName, C.green)
            end
        end
        task.wait(1)
    end
end

-- ══════════════════════════════════════════════════════
--           BUTTONS
-- ══════════════════════════════════════════════════════
TabRoll.MouseButton1Click:Connect(function()
    ActiveMode = "Roll"
    TabRoll.BackgroundColor3 = C.accent
    TabEgg.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    logAdd("Switched to Roll mode", C.accent)
end)

TabEgg.MouseButton1Click:Connect(function()
    ActiveMode = "Egg"
    TabEgg.BackgroundColor3 = C.accent
    TabRoll.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
    logAdd("Switched to Egg mode", C.accent)
end)

RunBtn.MouseButton1Click:Connect(function()
    Running = not Running
    if Running then
        RunBtn.Text = "⏹ Stop"
        RunBtn.BackgroundColor3 = C.red
        if ActiveMode == "Roll" then
            task.spawn(RollLoop)
        else
            task.spawn(EggLoop)
        end
    else
        RunBtn.Text = "▶ Start"
        RunBtn.BackgroundColor3 = C.accent
    end
end)

print("✅ Auto Roll + Egg Loaded!")
