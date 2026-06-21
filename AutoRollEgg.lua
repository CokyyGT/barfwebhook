-- Cleanup
if game.CoreGui:FindFirstChild("AutoRollUI") then
    game.CoreGui.AutoRollUI:Destroy()
end

local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player  = Players.LocalPlayer
local Request = request
    or http_request
    or (syn and syn.request)
    or (http and http.request)
    or (fluxus and fluxus.request)

-- ══════════════════════════════════════
--           CONFIG
-- ══════════════════════════════════════
local RARITIES = {
    { name = "Common",      color = Color3.fromRGB(180,180,180), enabled = false },
    { name = "Uncommon",    color = Color3.fromRGB(100,200,100), enabled = false },
    { name = "Rare",        color = Color3.fromRGB(80,130,220),  enabled = false },
    { name = "Epic",        color = Color3.fromRGB(160,80,220),  enabled = false },
    { name = "Legendary",   color = Color3.fromRGB(255,180,30),  enabled = false },
    { name = "Secret",      color = Color3.fromRGB(220,60,60),   enabled = false },
    { name = "Prismatic",   color = Color3.fromRGB(100,220,220), enabled = false },
    { name = "Divine",      color = Color3.fromRGB(220,180,255), enabled = false },
    { name = "Exotic",      color = Color3.fromRGB(255,140,0),   enabled = false },
    { name = "Transcended", color = Color3.fromRGB(255,220,50),  enabled = true  },
    { name = "Celestial",   color = Color3.fromRGB(80,180,255),  enabled = true  },
    { name = "Eternal",     color = Color3.fromRGB(200,100,255), enabled = true  },
}

local EGG_RARITIES = {
    { name = "Common",    color = Color3.fromRGB(180,180,180), enabled = true },
    { name = "Rare",      color = Color3.fromRGB(80,130,220),  enabled = true },
    { name = "Epic",      color = Color3.fromRGB(160,80,220),  enabled = true },
    { name = "Legendary", color = Color3.fromRGB(255,180,30),  enabled = true },
}

local TARGET_RARITIES = {}
local TARGET_EGG_RARITIES = {}
local ROLL_DELAY = 2
local SEED_WAIT = 6
local EGG_DELAY = 3
local WEBHOOK_URL = ""

for _, r in ipairs(RARITIES) do
    TARGET_RARITIES[r.name] = r.enabled
end

for _, r in ipairs(EGG_RARITIES) do
    TARGET_EGG_RARITIES[r.name] = r.enabled
end

-- Load webhook from config
local function loadWebhookConfig()
    local ok, raw = pcall(function() return readfile("barf_webhook_config.json") end)
    if ok and raw then
        local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok2 and data and data.webhook_url then
            WEBHOOK_URL = data.webhook_url
        end
    end
end

-- Save webhook config
local function saveWebhookConfig()
    pcall(function() 
        writefile("barf_webhook_config.json", HttpService:JSONEncode({webhook_url = WEBHOOK_URL}))
    end)
end

loadWebhookConfig()

-- Load/Save config
local function LoadConfig()
    local ok, raw = pcall(readfile, "autoroll_config.json")
    if not ok or not raw then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or not data then return end
    if data.rarities then
        for _, r in ipairs(RARITIES) do
            if data.rarities[r.name] ~= nil then
                r.enabled = data.rarities[r.name]
                TARGET_RARITIES[r.name] = r.enabled
            end
        end
    end
    if data.egg_rarities then
        for _, r in ipairs(EGG_RARITIES) do
            if data.egg_rarities[r.name] ~= nil then
                r.enabled = data.egg_rarities[r.name]
                TARGET_EGG_RARITIES[r.name] = r.enabled
            end
        end
    end
    if data.roll_delay then ROLL_DELAY = data.roll_delay end
    if data.seed_wait then SEED_WAIT = data.seed_wait end
    if data.egg_delay then EGG_DELAY = data.egg_delay end
end

local function SaveConfig()
    local rarityState = {}
    for _, r in ipairs(RARITIES) do rarityState[r.name] = r.enabled end
    local eggState = {}
    for _, r in ipairs(EGG_RARITIES) do eggState[r.name] = r.enabled end
    local data = {
        rarities = rarityState,
        egg_rarities = eggState,
        roll_delay = ROLL_DELAY,
        seed_wait = SEED_WAIT,
        egg_delay = EGG_DELAY,
    }
    pcall(function()
        writefile("autoroll_config.json", HttpService:JSONEncode(data))
    end)
end

LoadConfig()

-- ══════════════════════════════════════
--           STATE
-- ══════════════════════════════════════
local Running = false
local Mode = "Roll" -- Roll atau Egg
local TotalRolls = 0
local TotalBought = 0
local TotalEggBought = 0
local StartTime = os.time()
local myPlot = nil
local rollPrompt = nil
local petMerchant = nil

local function GetWIB()
    local u = DateTime.now():ToUniversalTime()
    return string.format("%02d:%02d WIB", (u.Hour+7)%24, u.Minute)
end

local function GetUptime()
    local e = os.time() - StartTime
    return string.format("%02d:%02d:%02d", math.floor(e/3600), math.floor((e%3600)/60), e%60)
end

-- ══════════════════════════════════════
--           WEBHOOK
-- ══════════════════════════════════════
local function SendWebhook(title, desc, color)
    if WEBHOOK_URL == "" or not Request then return end
    pcall(function()
        Request({
            Url = WEBHOOK_URL, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                embeds = {{
                    title = title,
                    description = desc,
                    color = color or 3066993,
                    footer = { text = "Build A Ring Farm" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            })
        })
    end)
end

-- ══════════════════════════════════════
--           FIND PLOT & EGG MERCHANT
-- ══════════════════════════════════════
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

local function FindEggMerchant()
    petMerchant = workspace:FindFirstChild("PetMerchant") 
                  or workspace:FindFirstChild("petmerchant")
                  or workspace:FindFirstChild("Pet Merchant")
    return petMerchant ~= nil
end

-- ══════════════════════════════════════
--           SCAN SEEDS & EGGS
-- ══════════════════════════════════════
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

local function ScanEggs()
    local eggs = {}
    if not petMerchant then return eggs end
    for i = 1, 5 do
        local stock = petMerchant:FindFirstChild("Podium"..i.."Stock")
        local lever = petMerchant:FindFirstChild("Podium"..i.."Lever")
        if stock and lever then
            local eggName = nil
            local eggRarity = nil
            for _, d in ipairs(stock:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then eggName = d.Text end
                if d:IsA("StringValue") and d.Name:lower():find("rarity") then eggRarity = d.Value end
            end
            local pp = lever:FindFirstChildWhichIsA("ProximityPrompt", true)
            if eggName and pp and eggRarity and TARGET_EGG_RARITIES[eggRarity] then
                table.insert(eggs, {podium=i, name=eggName, rarity=eggRarity, prompt=pp})
            end
        end
    end
    return eggs
end

-- ══════════════════════════════════════
--           UI
-- ══════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name = "AutoRollUI"
sg.ResetOnSpawn = false
sg.Parent = game.CoreGui

local C = {
    bg = Color3.fromRGB(15, 15, 20),
    surface = Color3.fromRGB(24, 24, 32),
    card = Color3.fromRGB(30, 30, 42),
    border = Color3.fromRGB(55, 55, 75),
    accent = Color3.fromRGB(99, 179, 237),
    green = Color3.fromRGB(72, 199, 142),
    text = Color3.fromRGB(225, 225, 235),
    muted = Color3.fromRGB(110, 110, 140),
    red = Color3.fromRGB(220, 80, 80),
    gold = Color3.fromRGB(255, 210, 60),
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function stroke(p, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thick or 1
    s.Parent = p
end

local function mkLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = props.font or Enum.Font.Gotham
    l.TextSize = props.size or 11
    l.TextColor3 = props.color or C.text
    l.Size = props.sz or UDim2.new(1,0,0,20)
    l.Position = props.pos or UDim2.new(0,0,0,0)
    l.Text = props.text or ""
    l.Parent = parent
    return l
end

local function mkBtn(parent, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = props.bg or C.card
    b.BorderSizePixel = 0
    b.Font = props.font or Enum.Font.GothamBold
    b.TextSize = props.size or 11
    b.TextColor3 = props.color or C.text
    b.Text = props.text or ""
    b.Size = props.sz or UDim2.new(1,0,0,30)
    b.Position = props.pos or UDim2.new(0,0,0,0)
    b.AutoButtonColor = false
    b.Parent = parent
    corner(b, props.r or 8)
    return b
end

-- Main frame
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 380, 0, 600)
main.Position = UDim2.new(0.5, -190, 0.5, -300)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Parent = sg
corner(main, 12)
stroke(main, C.border, 1)

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = C.surface
header.BorderSizePixel = 0
header.Parent = main
corner(header, 12)

mkLabel(header, {text="🎲 Auto Roll & Egg", font=Enum.Font.GothamBold, size=14, sz=UDim2.new(1,-100,1,0), pos=UDim2.new(0,14,0,0)})

local closeBtn = mkBtn(header, {text="✕", bg=C.red, size=12, sz=UDim2.new(0,26,0,26), pos=UDim2.new(1,-30,0.5,-13), r=6})
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- Tab buttons
local tabRoll = mkBtn(main, {text="🎰 Roll", bg=C.accent, size=11, sz=UDim2.new(0.5,-1,0,30), pos=UDim2.new(0,0,1,-70)})
local tabEgg = mkBtn(main, {text="🥚 Egg", bg=Color3.fromRGB(50,50,80), size=11, sz=UDim2.new(0.5,-1,0,30), pos=UDim2.new(0.5,1,1,-70)})

-- Content
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1,0,1,-100)
content.Position = UDim2.new(0,0,0,44)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 2
content.CanvasSize = UDim2.new(0,0,0,0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local contentList = Instance.new("UIListLayout", content)
contentList.Padding = UDim.new(0,6)
contentList.SortOrder = Enum.SortOrder.LayoutOrder
local contentPad = Instance.new("UIPadding", content)
contentPad.PaddingLeft = UDim.new(0,8)
contentPad.PaddingRight = UDim.new(0,8)
contentPad.PaddingTop = UDim.new(0,6)

-- ROLL TAB CONTENT
local function CreateRollTab()
    local section = Instance.new("Frame")
    section.BackgroundTransparency = 1
    section.Size = UDim2.new(1,0,0,0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = content
    
    mkLabel(section, {text="TARGET RARITY", size=10, color=C.muted, sz=UDim2.new(1,0,0,16)})
    
    for _, r in ipairs(RARITIES) do
        local btn = mkBtn(section, {text=r.name, bg=r.enabled and r.color or C.card, color=r.enabled and Color3.fromRGB(0,0,0) or C.muted, size=10, sz=UDim2.new(1,0,0,26)})
        btn.MouseButton1Click:Connect(function()
            r.enabled = not r.enabled
            TARGET_RARITIES[r.name] = r.enabled
            btn.BackgroundColor3 = r.enabled and r.color or C.card
            btn.TextColor3 = r.enabled and Color3.fromRGB(0,0,0) or C.muted
            SaveConfig()
        end)
    end
    
    return section
end

-- EGG TAB CONTENT
local function CreateEggTab()
    local section = Instance.new("Frame")
    section.BackgroundTransparency = 1
    section.Size = UDim2.new(1,0,0,0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.Parent = content
    
    mkLabel(section, {text="TARGET EGG RARITY", size=10, color=C.muted, sz=UDim2.new(1,0,0,16)})
    
    for _, r in ipairs(EGG_RARITIES) do
        local btn = mkBtn(section, {text=r.name, bg=r.enabled and r.color or C.card, color=r.enabled and Color3.fromRGB(0,0,0) or C.muted, size=10, sz=UDim2.new(1,0,0,26)})
        btn.MouseButton1Click:Connect(function()
            r.enabled = not r.enabled
            TARGET_EGG_RARITIES[r.name] = r.enabled
            btn.BackgroundColor3 = r.enabled and r.color or C.card
            btn.TextColor3 = r.enabled and Color3.fromRGB(0,0,0) or C.muted
            SaveConfig()
        end)
    end
    
    return section
end

local rollTab = CreateRollTab()
local eggTab = CreateEggTab()
eggTab.Visible = false

tabRoll.MouseButton1Click:Connect(function()
    Mode = "Roll"
    rollTab.Visible = true
    eggTab.Visible = false
    tabRoll.BackgroundColor3 = C.accent
    tabEgg.BackgroundColor3 = Color3.fromRGB(50,50,80)
end)

tabEgg.MouseButton1Click:Connect(function()
    Mode = "Egg"
    rollTab.Visible = false
    eggTab.Visible = true
    tabEgg.BackgroundColor3 = C.accent
    tabRoll.BackgroundColor3 = Color3.fromRGB(50,50,80)
end)

-- Stats
local statRolls = mkLabel(content, {text="Rolls: 0", size=11, color=C.accent})
local statEgg = mkLabel(content, {text="Eggs: 0", size=11, color=C.green})
local statUptime = mkLabel(content, {text="00:00:00", size=11, color=C.muted})

task.spawn(function()
    while true do
        task.wait(1)
        statRolls.Text = "Rolls: "..TotalRolls
        statEgg.Text = "Eggs: "..TotalEggBought
        statUptime.Text = GetUptime()
    end
end)

-- Run button
local runBtn = mkBtn(main, {text="▶ Start", bg=C.green, size=13, sz=UDim2.new(1,-16,0,36), pos=UDim2.new(0,8,1,-38)})

-- ══════════════════════════════════════
--           MAIN LOOPS
-- ══════════════════════════════════════
local function RollLoop()
    if not FindPlot() then
        Running = false
        return
    end
    
    while Running and Mode == "Roll" do
        local ok = pcall(function() fireproximityprompt(rollPrompt) end)
        if ok then
            TotalRolls = TotalRolls + 1
            local seeds = ScanSeeds()
            if #seeds > 0 then
                for _, seed in ipairs(seeds) do
                    pcall(function() fireproximityprompt(seed.prompt) end)
                    TotalBought = TotalBought + 1
                    SendWebhook("🌟 Seed Bought", seed.name.." - "..seed.rarity, 5763719)
                end
            end
        end
        task.wait(ROLL_DELAY)
    end
end

local function EggLoop()
    if not FindEggMerchant() then
        Running = false
        return
    end
    
    local lastEggSnapshot = ""
    local eggRestockDetected = false
    
    -- Monitor restock
    local function GetEggSnapshot()
        local snap = {}
        local eggs = ScanEggs()
        for _, egg in ipairs(eggs) do
            table.insert(snap, egg.name.."|"..egg.rarity)
        end
        return table.concat(snap, ",")
    end
    
    while Running and Mode == "Egg" do
        local currentSnapshot = GetEggSnapshot()
        
        -- Detect restock (snapshot berubah)
        if currentSnapshot ~= lastEggSnapshot and currentSnapshot ~= "" then
            eggRestockDetected = true
            lastEggSnapshot = currentSnapshot
        end
        
        -- Jika restock detected, tunggu delay 10 detik baru beli
        if eggRestockDetected then
            task.wait(10) -- Delay 10 detik
            
            if Running and Mode == "Egg" then
                local eggs = ScanEggs()
                for _, egg in ipairs(eggs) do
                    pcall(function() fireproximityprompt(egg.prompt) end)
                    TotalEggBought = TotalEggBought + 1
                    SendWebhook("🥚 Egg Bought", egg.name.." - "..egg.rarity, 16766720)
                end
            end
            
            eggRestockDetected = false
        end
        
        task.wait(1) -- Check restock setiap 1 detik
    end
end

runBtn.MouseButton1Click:Connect(function()
    Running = not Running
    if Running then
        runBtn.Text = "⏹ Stop"
        runBtn.BackgroundColor3 = C.red
        if Mode == "Roll" then
            task.spawn(RollLoop)
        else
            task.spawn(EggLoop)
        end
    else
        runBtn.Text = "▶ Start"
        runBtn.BackgroundColor3 = C.green
    end
end)

print("✅ Auto Roll & Egg Loaded!")
