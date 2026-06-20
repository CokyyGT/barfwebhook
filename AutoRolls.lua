local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

-- ══════════════════════════════════════
--   HTTP REQUEST (multi executor)
-- ══════════════════════════════════════
local Request = request
    or http_request
    or (syn and syn.request)
    or (http and http.request)
    or (fluxus and fluxus.request)

-- ══════════════════════════════════════
--   FIRE PROMPT (Delta/Synapse/dll)
-- ══════════════════════════════════════
local HasFireProximity = (fireproximityprompt ~= nil)

local function WalkTo(position)
    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum:MoveTo(position)
    local t = 0
    while t < 5 do
        task.wait(0.1); t = t + 0.1
        if (hrp.Position - position).Magnitude < 5 then break end
    end
end

local function FirePrompt(prompt)
    if not prompt then return false end
    if HasFireProximity then
        local ok = pcall(fireproximityprompt, prompt, Player)
        if not ok then ok = pcall(fireproximityprompt, prompt) end
        return ok
    end
    -- Xeno dll: jalan ke posisi dulu
    local part = prompt.Parent
    local targetPos = nil
    if part and part:IsA("BasePart") then
        targetPos = part.Position
    elseif part then
        local bp = part:FindFirstChildOfClass("BasePart")
        if bp then targetPos = bp.Position end
    end
    if targetPos then WalkTo(targetPos) end
    local ok = pcall(function()
        local ti = prompt.Parent:FindFirstChild("TouchInterest")
        if ti then
            firetouchinterest(Player.Character.HumanoidRootPart, ti, 0)
        else error("no ti") end
    end)
    if ok then return true end
    return pcall(function() prompt.Triggered:Fire(Player) end)
end

-- ══════════════════════════════════════
--   CONFIG
-- ══════════════════════════════════════
local EGG_TYPES = {
    { name = "CommonEgg",      label = "Common Egg",      color = Color3.fromRGB(180,180,180), enabled = false },
    { name = "RareEgg",        label = "Rare Egg",        color = Color3.fromRGB(80,130,220),  enabled = false },
    { name = "EpicEgg",        label = "Epic Egg",        color = Color3.fromRGB(160,80,220),  enabled = false },
    { name = "LegendaryEgg",   label = "Legendary Egg",   color = Color3.fromRGB(255,180,30),  enabled = false },
    { name = "MythicalEgg",    label = "Mythical Egg",    color = Color3.fromRGB(220,60,60),   enabled = false },
    { name = "DivineEgg",      label = "Divine Egg",      color = Color3.fromRGB(220,180,255), enabled = true  },
    { name = "PrismaticEgg",   label = "Prismatic Egg",   color = Color3.fromRGB(100,220,220), enabled = true  },
}

local TARGET_EGGS    = {}
local CHECK_DELAY    = 5   -- cek tiap N detik
local WEBHOOK_URL    = ""
local WEBHOOK_ENABLED = false

for _, e in ipairs(EGG_TYPES) do
    TARGET_EGGS[e.name] = e.enabled
end

-- ══════════════════════════════════════
--   SAVE / LOAD CONFIG
-- ══════════════════════════════════════
local CONFIG_FILE = "autoegg_config.json"

local function SaveConfig()
    local eggState = {}
    for _, e in ipairs(EGG_TYPES) do eggState[e.name] = e.enabled end
    local data = {
        eggs            = eggState,
        check_delay     = CHECK_DELAY,
        webhook_url     = WEBHOOK_URL,
        webhook_enabled = WEBHOOK_ENABLED,
    }
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(data))
        end
    end)
end

local function LoadConfig()
    if not readfile then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not ok2 or not data then return end
    if data.eggs then
        for _, e in ipairs(EGG_TYPES) do
            if data.eggs[e.name] ~= nil then
                e.enabled = data.eggs[e.name]
                TARGET_EGGS[e.name] = e.enabled
            end
        end
    end
    if data.check_delay     then CHECK_DELAY     = data.check_delay     end
    if data.webhook_url     then WEBHOOK_URL     = data.webhook_url     end
    if data.webhook_enabled ~= nil then WEBHOOK_ENABLED = data.webhook_enabled end
end

LoadConfig()

-- ══════════════════════════════════════
--   STATE
-- ══════════════════════════════════════
local Running     = false
local TotalBought = 0
local StartTime   = os.time()

local function GetWIB()
    local u = DateTime.now():ToUniversalTime()
    return string.format("%02d:%02d WIB", (u.Hour+7)%24, u.Minute)
end

local function GetUptime()
    local e = os.time() - StartTime
    return string.format("%02d:%02d:%02d",
        math.floor(e/3600), math.floor((e%3600)/60), e%60)
end

-- ══════════════════════════════════════
--   WEBHOOK
-- ══════════════════════════════════════
local function SendWebhook(title, desc, color)
    if not WEBHOOK_ENABLED or WEBHOOK_URL == "" or not Request then return end
    pcall(function()
        Request({
            Url     = WEBHOOK_URL, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                embeds = {{
                    title = title, description = desc, color = color,
                    footer = { text = "Build A Ring Farm  •  Auto Egg" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            })
        })
    end)
end

local function SendEggBought(eggName, podium)
    SendWebhook("🥚  Egg Dibeli!", table.concat({
        "```",
        "🥚 Egg      : " .. eggName,
        "🏛 Podium   : " .. podium,
        "🛒 Total    : " .. TotalBought,
        "⏱ Uptime   : " .. GetUptime(),
        "🕐 Waktu    : " .. GetWIB(),
        "```"
    }, "\n"), 9699539)
end

-- ══════════════════════════════════════
--   SCAN PODIUMS
--   workspace > PetMerchant > Podium1Stock-Podium5Stock
--   workspace > PetMerchant > Podium1Lever-Podium5Lever
--              > PrompAttachment > EggShopPrompt
-- ══════════════════════════════════════
local function GetPetMerchant()
    return workspace:FindFirstChild("PetMerchant")
        or workspace:FindFirstChild("petmerchant")
        or workspace:FindFirstChild("Pet Merchant")
end

local function ScanPodiums()
    local results = {}
    local pm = GetPetMerchant()
    if not pm then return results end

    for i = 1, 5 do
        local stockObj = pm:FindFirstChild("Podium" .. i .. "Stock")
        local leverObj = pm:FindFirstChild("Podium" .. i .. "Lever")

        if stockObj and leverObj then
            -- Cari nama egg dari stock object
            local eggName = nil

            -- Cek langsung nama object atau child label
            local nameLbl = stockObj:FindFirstChild("EggName", true)
                         or stockObj:FindFirstChild("Name", true)
                         or stockObj:FindFirstChildWhichIsA("StringValue", true)
            if nameLbl then
                eggName = (nameLbl:IsA("StringValue") and nameLbl.Value)
                       or (nameLbl:IsA("TextLabel")   and nameLbl.Text)
            end

            -- Fallback: pakai nama object stockObj sendiri
            if not eggName or eggName == "" then
                -- Cek semua TextLabel di descendant
                for _, d in ipairs(stockObj:GetDescendants()) do
                    if d:IsA("TextLabel") and d.Text ~= "" then
                        eggName = d.Text; break
                    end
                end
            end

            -- Cari prompt di lever
            -- Cari prompt langsung di lever atau descendants
            local prompt = leverObj:FindFirstChildWhichIsA("ProximityPrompt", true)
            if not prompt then
                -- Cek attachment juga
                local pa = leverObj:FindFirstChild("PromptAttachment")
                          or leverObj:FindFirstChild("PrompAttachment")
                if pa then
                    prompt = pa:FindFirstChildWhichIsA("ProximityPrompt")
                end
            end

            if eggName and prompt then
                table.insert(results, {
                    podium  = i,
                    eggName = eggName,
                    prompt  = prompt,
                    stock   = stockObj,
                })
            end
        end
    end
    return results
end

-- ══════════════════════════════════════
--   UI
-- ══════════════════════════════════════
if game.CoreGui:FindFirstChild("AutoEggUI") then
    game.CoreGui.AutoEggUI:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name          = "AutoEggUI"
sg.ResetOnSpawn  = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent        = game.CoreGui

local C = {
    bg      = Color3.fromRGB(15,15,20),
    surface = Color3.fromRGB(24,24,32),
    card    = Color3.fromRGB(30,30,42),
    border  = Color3.fromRGB(55,55,75),
    accent  = Color3.fromRGB(99,179,237),
    green   = Color3.fromRGB(72,199,142),
    text    = Color3.fromRGB(225,225,235),
    muted   = Color3.fromRGB(110,110,140),
    red     = Color3.fromRGB(220,80,80),
    gold    = Color3.fromRGB(255,210,60),
    yellow  = Color3.fromRGB(255,185,40),
    white   = Color3.fromRGB(255,255,255),
    purple  = Color3.fromRGB(160,100,240),
}

local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
end
local function stroke(p, col, th)
    local s = Instance.new("UIStroke"); s.Color = col or C.border; s.Thickness = th or 1; s.Parent = p; return s
end
local function pad(p, all)
    local u = Instance.new("UIPadding")
    u.PaddingLeft = UDim.new(0,all); u.PaddingRight = UDim.new(0,all)
    u.PaddingTop  = UDim.new(0,all); u.PaddingBottom = UDim.new(0,all)
    u.Parent = p
end

local UI_W   = 360
local MINI_H = 44

local main = Instance.new("Frame")
main.Name             = "Main"
main.BackgroundColor3 = C.bg
main.BorderSizePixel  = 0
main.ClipsDescendants = true
main.Size             = UDim2.new(0, UI_W, 0, 500)
main.Position         = UDim2.new(0, 20, 0.5, -250)
main.Parent           = sg
corner(main, 12)
stroke(main, C.border)

-- Header
local header = Instance.new("Frame")
header.Size             = UDim2.new(1,0,0,44)
header.BackgroundColor3 = C.surface
header.BorderSizePixel  = 0
header.ZIndex           = 20
header.Parent           = main
corner(header, 12)

local hFill = Instance.new("Frame")
hFill.Size             = UDim2.new(1,0,0,12)
hFill.Position         = UDim2.new(0,0,1,-12)
hFill.BackgroundColor3 = C.surface
hFill.BorderSizePixel  = 0
hFill.ZIndex           = 19
hFill.Parent           = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size             = UDim2.new(1,-90,1,0)
titleLbl.Position         = UDim2.new(0,14,0,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text             = "🥚  Auto Buy Egg"
titleLbl.TextColor3       = C.white
titleLbl.TextSize         = 14
titleLbl.Font             = Enum.Font.GothamBold
titleLbl.TextXAlignment   = Enum.TextXAlignment.Left
titleLbl.ZIndex           = 21
titleLbl.Parent           = header

local statusDot = Instance.new("TextLabel")
statusDot.Size            = UDim2.new(0,12,0,12)
statusDot.Position        = UDim2.new(0,170,0.5,-6)
statusDot.BackgroundTransparency = 1
statusDot.Text            = "●"
statusDot.TextColor3      = C.muted
statusDot.TextSize        = 10
statusDot.Font            = Enum.Font.GothamBold
statusDot.ZIndex          = 21
statusDot.Parent          = header

local minBtn = Instance.new("TextButton")
minBtn.Size             = UDim2.new(0,26,0,26)
minBtn.Position         = UDim2.new(1,-60,0.5,-13)
minBtn.BackgroundColor3 = C.border
minBtn.BorderSizePixel  = 0
minBtn.Text             = "—"
minBtn.TextColor3       = C.text
minBtn.TextSize         = 12
minBtn.Font             = Enum.Font.GothamBold
minBtn.ZIndex           = 21
minBtn.Parent           = header
corner(minBtn, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size             = UDim2.new(0,26,0,26)
closeBtn.Position         = UDim2.new(1,-30,0.5,-13)
closeBtn.BackgroundColor3 = C.red
closeBtn.BorderSizePixel  = 0
closeBtn.Text             = "✕"
closeBtn.TextColor3       = C.white
closeBtn.TextSize         = 12
closeBtn.Font             = Enum.Font.GothamBold
closeBtn.ZIndex           = 21
closeBtn.Parent           = header
corner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- Scroll
local scroll = Instance.new("ScrollingFrame")
scroll.Size                   = UDim2.new(1,0,1,-44)
scroll.Position               = UDim2.new(0,0,0,44)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel        = 0
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = C.border
scroll.ScrollingDirection     = Enum.ScrollingDirection.Y
scroll.CanvasSize             = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.Parent                 = main

local contentList = Instance.new("UIListLayout")
contentList.Padding             = UDim.new(0,8)
contentList.FillDirection       = Enum.FillDirection.Vertical
contentList.SortOrder           = Enum.SortOrder.LayoutOrder
contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentList.Parent              = scroll
pad(scroll, 8)

contentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local h = contentList.AbsoluteContentSize.Y + 16 + 44
    main.Size = UDim2.new(0, UI_W, 0, math.min(h, 650))
end)

local layoutOrder = 0
local function mkSection(title)
    layoutOrder = layoutOrder + 1
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.BorderSizePixel        = 0
    wrap.Size                   = UDim2.new(1,-16,0,0)
    wrap.AutomaticSize          = Enum.AutomaticSize.Y
    wrap.LayoutOrder            = layoutOrder
    wrap.Parent                 = scroll

    local wl = Instance.new("UIListLayout")
    wl.Padding   = UDim.new(0,4)
    wl.SortOrder = Enum.SortOrder.LayoutOrder
    wl.Parent    = wrap

    if title then
        local hdr = Instance.new("TextLabel")
        hdr.Size             = UDim2.new(1,0,0,14)
        hdr.BackgroundTransparency = 1
        hdr.Text             = title
        hdr.TextColor3       = C.muted
        hdr.TextSize         = 9
        hdr.Font             = Enum.Font.GothamBold
        hdr.TextXAlignment   = Enum.TextXAlignment.Left
        hdr.LayoutOrder      = 0
        hdr.Parent           = wrap
    end

    local card = Instance.new("Frame")
    card.BackgroundColor3 = C.card
    card.BorderSizePixel  = 0
    card.Size             = UDim2.new(1,0,0,0)
    card.AutomaticSize    = Enum.AutomaticSize.Y
    card.LayoutOrder      = 1
    card.Parent           = wrap
    corner(card, 10)
    stroke(card, C.border)
    pad(card, 10)
    return card
end

-- ── Stats ──
local statsCard = mkSection(nil)
statsCard.AutomaticSize = Enum.AutomaticSize.None
statsCard.Size = UDim2.new(1,0,0,54)

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection       = Enum.FillDirection.Horizontal
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
statsLayout.Parent              = statsCard

local statBought, statUptime, statStatus

local function mkStatCol(parent, label)
    local col = Instance.new("Frame")
    col.BackgroundTransparency = 1
    col.BorderSizePixel        = 0
    col.Size                   = UDim2.new(0.333,0,1,0)
    col.Parent                 = parent

    local cl = Instance.new("UIListLayout")
    cl.HorizontalAlignment = Enum.HorizontalAlignment.Center
    cl.VerticalAlignment   = Enum.VerticalAlignment.Center
    cl.Parent              = col

    local v = Instance.new("TextLabel")
    v.Size             = UDim2.new(1,0,0,24)
    v.BackgroundTransparency = 1
    v.Text             = "0"
    v.TextColor3       = C.accent
    v.TextSize         = 20
    v.Font             = Enum.Font.GothamBold
    v.TextXAlignment   = Enum.TextXAlignment.Center
    v.Parent           = col

    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(1,0,0,12)
    l.BackgroundTransparency = 1
    l.Text             = label
    l.TextColor3       = C.muted
    l.TextSize         = 8
    l.Font             = Enum.Font.Gotham
    l.TextXAlignment   = Enum.TextXAlignment.Center
    l.Parent           = col
    return v
end

statBought = mkStatCol(statsCard, "TOTAL BELI")
statUptime = mkStatCol(statsCard, "UPTIME")
statStatus = mkStatCol(statsCard, "STATUS")
statStatus.Text      = "IDLE"
statStatus.TextColor3 = C.muted
statStatus.TextSize  = 11

task.spawn(function()
    while task.wait(1) do statUptime.Text = GetUptime() end
end)

-- ── Egg Target ──
local eggCard = mkSection("TARGET EGG")

local eggGrid = Instance.new("UIGridLayout")
eggGrid.CellSize            = UDim2.new(0,152,0,30)
eggGrid.CellPadding         = UDim2.new(0,5,0,5)
eggGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
eggGrid.Parent              = eggCard

for _, e in ipairs(EGG_TYPES) do
    local btn = Instance.new("TextButton")
    btn.Size             = UDim2.new(0,152,0,30)
    btn.BackgroundColor3 = e.enabled and e.color or C.border
    btn.BorderSizePixel  = 0
    btn.Text             = e.label
    btn.TextColor3       = e.enabled and Color3.fromRGB(15,15,15) or C.muted
    btn.TextSize         = 10
    btn.Font             = Enum.Font.GothamBold
    btn.AutoButtonColor  = false
    btn.Parent           = eggCard
    corner(btn, 6)

    btn.MouseButton1Click:Connect(function()
        e.enabled = not e.enabled
        TARGET_EGGS[e.name] = e.enabled
        btn.BackgroundColor3 = e.enabled and e.color or C.border
        btn.TextColor3       = e.enabled and Color3.fromRGB(15,15,15) or C.muted
        SaveConfig()
    end)
end

-- ── Podium Monitor ──
local podiumCard = mkSection("PODIUM STATUS")
local podiumLabels = {}

local podiumList = Instance.new("UIListLayout")
podiumList.Padding   = UDim.new(0,4)
podiumList.SortOrder = Enum.SortOrder.LayoutOrder
podiumList.Parent    = podiumCard

for i = 1, 5 do
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.BorderSizePixel        = 0
    row.Size                   = UDim2.new(1,0,0,22)
    row.LayoutOrder            = i
    row.Parent                 = podiumCard

    local lbl = Instance.new("TextLabel")
    lbl.Size           = UDim2.new(0.4,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text           = "Podium " .. i
    lbl.TextColor3     = C.muted
    lbl.TextSize       = 10
    lbl.Font           = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent         = row

    local val = Instance.new("TextLabel")
    val.Size           = UDim2.new(0.6,0,1,0)
    val.Position       = UDim2.new(0.4,0,0,0)
    val.BackgroundTransparency = 1
    val.Text           = "—"
    val.TextColor3     = C.muted
    val.TextSize       = 10
    val.Font           = Enum.Font.Gotham
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.Parent         = row

    podiumLabels[i] = val
end

-- ── Settings ──
local settCard = mkSection("SETTINGS")

local settList = Instance.new("UIListLayout")
settList.Padding   = UDim.new(0,8)
settList.SortOrder = Enum.SortOrder.LayoutOrder
settList.Parent    = settCard

local function mkSlider(parent, label, default, minV, maxV, step, onChange, order)
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.BorderSizePixel        = 0
    row.Size                   = UDim2.new(1,0,0,28)
    row.LayoutOrder            = order or 1
    row.Parent                 = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(0.55,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = C.text
    lbl.TextSize         = 10
    lbl.Font             = Enum.Font.Gotham
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = row

    local minus = Instance.new("TextButton")
    minus.Size             = UDim2.new(0,26,0,22)
    minus.Position         = UDim2.new(1,-78,0.5,-11)
    minus.BackgroundColor3 = C.surface
    minus.BorderSizePixel  = 0
    minus.Text             = "−"
    minus.TextColor3       = C.text
    minus.TextSize         = 15
    minus.Font             = Enum.Font.GothamBold
    minus.AutoButtonColor  = false
    minus.Parent           = row
    corner(minus, 6); stroke(minus, C.border)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size             = UDim2.new(0,28,0,22)
    valLbl.Position         = UDim2.new(1,-50,0.5,-11)
    valLbl.BackgroundTransparency = 1
    valLbl.Text             = tostring(default)
    valLbl.TextColor3       = C.accent
    valLbl.TextSize         = 11
    valLbl.Font             = Enum.Font.GothamBold
    valLbl.TextXAlignment   = Enum.TextXAlignment.Center
    valLbl.Parent           = row

    local plus = Instance.new("TextButton")
    plus.Size             = UDim2.new(0,26,0,22)
    plus.Position         = UDim2.new(1,-22,0.5,-11)
    plus.BackgroundColor3 = C.surface
    plus.BorderSizePixel  = 0
    plus.Text             = "+"
    plus.TextColor3       = C.text
    plus.TextSize         = 15
    plus.Font             = Enum.Font.GothamBold
    plus.AutoButtonColor  = false
    plus.Parent           = row
    corner(plus, 6); stroke(plus, C.border)

    local cur = default
    minus.MouseButton1Click:Connect(function()
        cur = math.max(minV, math.round((cur-step)*10)/10)
        valLbl.Text = tostring(cur); onChange(cur); SaveConfig()
    end)
    plus.MouseButton1Click:Connect(function()
        cur = math.min(maxV, math.round((cur+step)*10)/10)
        valLbl.Text = tostring(cur); onChange(cur); SaveConfig()
    end)
    return valLbl
end

local delayVal = mkSlider(settCard, "Check Delay (detik)", CHECK_DELAY, 1, 30, 1,
    function(v) CHECK_DELAY = v end, 1)
delayVal.Text = tostring(CHECK_DELAY)

-- ── Webhook ──
local whCard = mkSection("DISCORD WEBHOOK")

local whList = Instance.new("UIListLayout")
whList.Padding   = UDim.new(0,6)
whList.SortOrder = Enum.SortOrder.LayoutOrder
whList.Parent    = whCard

-- Toggle row
local togRow = Instance.new("Frame")
togRow.BackgroundTransparency = 1
togRow.BorderSizePixel        = 0
togRow.Size                   = UDim2.new(1,0,0,24)
togRow.LayoutOrder            = 1
togRow.Parent                 = whCard

local togBg = Instance.new("Frame")
togBg.Size             = UDim2.new(0,36,0,18)
togBg.Position         = UDim2.new(0,0,0.5,-9)
togBg.BackgroundColor3 = C.border
togBg.BorderSizePixel  = 0
togBg.Parent           = togRow
corner(togBg, 9)

local togCircle = Instance.new("Frame")
togCircle.Size             = UDim2.new(0,12,0,12)
togCircle.Position         = UDim2.new(0,3,0.5,-6)
togCircle.BackgroundColor3 = C.muted
togCircle.BorderSizePixel  = 0
togCircle.Parent           = togBg
corner(togCircle, 6)

local togHit = Instance.new("TextButton")
togHit.Size               = UDim2.new(1,0,1,0)
togHit.BackgroundTransparency = 1
togHit.Text               = ""
togHit.ZIndex             = 5
togHit.Parent             = togBg

local togLbl = Instance.new("TextLabel")
togLbl.Size           = UDim2.new(1,-50,1,0)
togLbl.Position       = UDim2.new(0,44,0,0)
togLbl.BackgroundTransparency = 1
togLbl.Text           = "Aktifkan notif Discord"
togLbl.TextColor3     = C.muted
togLbl.TextSize       = 10
togLbl.Font           = Enum.Font.Gotham
togLbl.TextXAlignment = Enum.TextXAlignment.Left
togLbl.Parent         = togRow

local whStatusLbl = Instance.new("TextLabel")
whStatusLbl.Size           = UDim2.new(0,32,1,0)
whStatusLbl.Position       = UDim2.new(1,-32,0,0)
whStatusLbl.BackgroundTransparency = 1
whStatusLbl.Text           = "OFF"
whStatusLbl.TextColor3     = C.muted
whStatusLbl.TextSize       = 9
whStatusLbl.Font           = Enum.Font.GothamBold
whStatusLbl.TextXAlignment = Enum.TextXAlignment.Right
whStatusLbl.Parent         = togRow

-- URL input
local urlLblRow = Instance.new("Frame")
urlLblRow.BackgroundTransparency = 1
urlLblRow.BorderSizePixel        = 0
urlLblRow.Size                   = UDim2.new(1,0,0,14)
urlLblRow.LayoutOrder            = 2
urlLblRow.Parent                 = whCard

local urlLbl2 = Instance.new("TextLabel")
urlLbl2.Size           = UDim2.new(1,0,1,0)
urlLbl2.BackgroundTransparency = 1
urlLbl2.Text           = "Webhook URL"
urlLbl2.TextColor3     = C.muted
urlLbl2.TextSize       = 9
urlLbl2.Font           = Enum.Font.Gotham
urlLbl2.TextXAlignment = Enum.TextXAlignment.Left
urlLbl2.Parent         = urlLblRow

local urlBoxRow = Instance.new("Frame")
urlBoxRow.BackgroundTransparency = 1
urlBoxRow.BorderSizePixel        = 0
urlBoxRow.Size                   = UDim2.new(1,0,0,30)
urlBoxRow.LayoutOrder            = 3
urlBoxRow.Parent                 = whCard

local urlBox = Instance.new("TextBox")
urlBox.Size             = UDim2.new(1,0,1,0)
urlBox.BackgroundColor3 = C.surface
urlBox.BorderSizePixel  = 0
urlBox.Text             = WEBHOOK_URL
urlBox.PlaceholderText  = "https://discord.com/api/webhooks/..."
urlBox.PlaceholderColor3 = C.border
urlBox.TextColor3       = C.text
urlBox.TextSize         = 9
urlBox.Font             = Enum.Font.Gotham
urlBox.TextXAlignment   = Enum.TextXAlignment.Left
urlBox.ClearTextOnFocus = false
urlBox.ClipsDescendants = true
urlBox.Parent           = urlBoxRow
corner(urlBox, 6)
local urlPad = Instance.new("UIPadding")
urlPad.PaddingLeft = UDim.new(0,8); urlPad.Parent = urlBox
local urlStroke = stroke(urlBox, C.border)

-- Buttons
local whBtnRow = Instance.new("Frame")
whBtnRow.BackgroundTransparency = 1
whBtnRow.BorderSizePixel        = 0
whBtnRow.Size                   = UDim2.new(1,0,0,30)
whBtnRow.LayoutOrder            = 4
whBtnRow.Parent                 = whCard

local whBtnList = Instance.new("UIListLayout")
whBtnList.FillDirection       = Enum.FillDirection.Horizontal
whBtnList.HorizontalAlignment = Enum.HorizontalAlignment.Left
whBtnList.VerticalAlignment   = Enum.VerticalAlignment.Center
whBtnList.Padding             = UDim.new(0,6)
whBtnList.Parent              = whBtnRow

local function mkSmallBtn(parent, text, bg, col)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.5,-3,1,0)
    b.BackgroundColor3 = bg or C.surface
    b.BorderSizePixel  = 0
    b.Text             = text
    b.TextColor3       = col or C.white
    b.TextSize         = 10
    b.Font             = Enum.Font.GothamBold
    b.AutoButtonColor  = false
    b.Parent           = parent
    corner(b, 7)
    return b
end

local saveBtn = mkSmallBtn(whBtnRow, "💾  Simpan", C.green)
local testBtn = mkSmallBtn(whBtnRow, "🔔  Test",   C.surface, C.text)
stroke(testBtn, C.border)

local function IsValidWebhook(url)
    return type(url)=="string"
        and url:match("^https://discord%.com/api/webhooks/%d+/.+") ~= nil
end

local function UpdateWhStatus()
    if not WEBHOOK_ENABLED then
        whStatusLbl.Text        = "OFF"
        whStatusLbl.TextColor3  = C.muted
        togBg.BackgroundColor3  = C.border
        togCircle.Position      = UDim2.new(0,3,0.5,-6)
        togCircle.BackgroundColor3 = C.muted
        urlStroke.Color         = C.border
    elseif not IsValidWebhook(WEBHOOK_URL) then
        whStatusLbl.Text        = "⚠"
        whStatusLbl.TextColor3  = C.yellow
        urlStroke.Color         = C.yellow
    else
        whStatusLbl.Text        = "ON"
        whStatusLbl.TextColor3  = C.green
        togBg.BackgroundColor3  = C.green
        togCircle.Position      = UDim2.new(0,21,0.5,-6)
        togCircle.BackgroundColor3 = C.white
        urlStroke.Color         = C.green
    end
end

togHit.MouseButton1Click:Connect(function()
    WEBHOOK_ENABLED = not WEBHOOK_ENABLED
    UpdateWhStatus(); SaveConfig()
end)

saveBtn.MouseButton1Click:Connect(function()
    local url = urlBox.Text
    if IsValidWebhook(url) then
        WEBHOOK_URL = url
        saveBtn.Text = "✅  Tersimpan!"
        saveBtn.BackgroundColor3 = C.green
        SaveConfig()
    else
        saveBtn.Text = "❌  URL Salah"
        saveBtn.BackgroundColor3 = C.red
    end
    UpdateWhStatus()
    task.delay(1.5, function()
        saveBtn.Text = "💾  Simpan"
        saveBtn.BackgroundColor3 = C.green
    end)
end)

testBtn.MouseButton1Click:Connect(function()
    if not IsValidWebhook(WEBHOOK_URL) then
        testBtn.Text = "❌ Set URL dulu!"; testBtn.BackgroundColor3 = C.red
        task.delay(1.5, function() testBtn.Text="🔔  Test"; testBtn.BackgroundColor3=C.surface end)
        return
    end
    testBtn.Text = "⏳ ..."; testBtn.BackgroundColor3 = C.yellow
    local ok = pcall(function()
        Request({
            Url = WEBHOOK_URL, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ embeds = {{
                title = "🔔  Webhook Test",
                description = "```\n✅ Terhubung!\n👤 Player : "..Player.Name.."\n🕐 Waktu  : "..GetWIB().."\n```",
                color = 3066993,
                footer = { text = "Build A Ring Farm  •  Auto Egg" },
                timestamp = DateTime.now():ToIsoDate()
            }}})
        })
    end)
    testBtn.Text = ok and "✅ Berhasil!" or "❌ Gagal!"
    testBtn.BackgroundColor3 = ok and C.green or C.red
    task.delay(1.5, function() testBtn.Text="🔔  Test"; testBtn.BackgroundColor3=C.surface end)
end)

UpdateWhStatus()

-- ── Log ──
local logCard = mkSection("LOG")
logCard.AutomaticSize = Enum.AutomaticSize.None
logCard.Size = UDim2.new(1,0,0,70)

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size                   = UDim2.new(1,-10,1,-10)
logScroll.Position               = UDim2.new(0,5,0,5)
logScroll.BackgroundTransparency = 1
logScroll.BorderSizePixel        = 0
logScroll.ScrollBarThickness     = 2
logScroll.ScrollBarImageColor3   = C.border
logScroll.CanvasSize             = UDim2.new(0,0,0,0)
logScroll.Parent                 = logCard

local logList2 = Instance.new("UIListLayout")
logList2.Padding  = UDim.new(0,2)
logList2.SortOrder = Enum.SortOrder.LayoutOrder
logList2.Parent   = logScroll

logList2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    logScroll.CanvasSize     = UDim2.new(0,0,0,logList2.AbsoluteContentSize.Y)
    logScroll.CanvasPosition = Vector2.new(0, logList2.AbsoluteContentSize.Y)
end)

local logOrder2 = 0
local function addLog(msg, color)
    local children = logScroll:GetChildren()
    local count = 0
    for _, c in ipairs(children) do if c:IsA("TextLabel") then count=count+1 end end
    if count > 40 then
        for _, c in ipairs(children) do if c:IsA("TextLabel") then c:Destroy(); break end end
    end
    logOrder2 = logOrder2 + 1
    local l = Instance.new("TextLabel")
    l.Size             = UDim2.new(1,0,0,12)
    l.BackgroundTransparency = 1
    l.Text             = "["..GetWIB().."] "..msg
    l.TextColor3       = color or C.muted
    l.TextSize         = 9
    l.Font             = Enum.Font.Gotham
    l.TextXAlignment   = Enum.TextXAlignment.Left
    l.LayoutOrder      = logOrder2
    l.Parent           = logScroll
end

-- ── Run Button ──
layoutOrder = layoutOrder + 1
local runWrap = Instance.new("Frame")
runWrap.BackgroundTransparency = 1
runWrap.BorderSizePixel        = 0
runWrap.Size                   = UDim2.new(1,-16,0,38)
runWrap.LayoutOrder            = layoutOrder
runWrap.Parent                 = scroll

local runBtn = Instance.new("TextButton")
runBtn.Size             = UDim2.new(1,0,1,0)
runBtn.BackgroundColor3 = C.green
runBtn.BorderSizePixel  = 0
runBtn.Text             = "▶  Mulai Auto Buy Egg"
runBtn.TextColor3       = C.white
runBtn.TextSize         = 13
runBtn.Font             = Enum.Font.GothamBold
runBtn.AutoButtonColor  = false
runBtn.Parent           = runWrap
corner(runBtn, 10)

-- ── Drag ──
local dragging, dragStart, startPos
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = inp.Position; startPos = main.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = inp.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                   startPos.Y.Scale, startPos.Y.Offset+d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
end)

-- ── Minimize ──
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    scroll.Visible = not minimized
    if minimized then
        main.Size = UDim2.new(0, UI_W, 0, MINI_H)
    else
        local h = contentList.AbsoluteContentSize.Y + 16 + 44
        main.Size = UDim2.new(0, UI_W, 0, math.min(h, 650))
    end
    minBtn.Text = minimized and "+" or "—"
end)

-- ══════════════════════════════════════
--   MAIN LOOP
-- ══════════════════════════════════════
local function RunLoop()
    local pm = GetPetMerchant()
    if not pm then
        addLog("❌ PetMerchant tidak ditemukan!", C.red)
        Running = false
        runBtn.Text = "▶  Mulai Auto Buy Egg"
        runBtn.BackgroundColor3 = C.green
        statusDot.TextColor3    = C.muted
        statStatus.Text         = "IDLE"
        statStatus.TextColor3   = C.muted
        return
    end

    addLog("✅ PetMerchant ditemukan!", C.green)
    addLog("Auto Buy Egg dimulai!", C.accent)

    while Running do
        local podiums = ScanPodiums()

        -- Update podium status di UI
        for i = 1, 5 do
            podiumLabels[i].Text      = "—"
            podiumLabels[i].TextColor3 = C.muted
        end

        local foundTarget = false
        for _, p in ipairs(podiums) do
            -- Cek apakah egg ini target
            local isTarget = false
            for _, e in ipairs(EGG_TYPES) do
                if p.eggName:find(e.name) or e.name:find(p.eggName) or
                   p.eggName:lower():find(e.label:lower()) then
                    if e.enabled then isTarget = true end
                end
            end
            -- Direct name match
            if TARGET_EGGS[p.eggName] then isTarget = true end

            -- Update podium label
            if podiumLabels[p.podium] then
                podiumLabels[p.podium].Text      = p.eggName .. (isTarget and " ⭐" or "")
                podiumLabels[p.podium].TextColor3 = isTarget and C.gold or C.text
            end

            if isTarget then
                foundTarget = true
                addLog("🥚 Podium "..p.podium..": "..p.eggName, C.gold)
                local ok = FirePrompt(p.prompt)
                if ok then
                    TotalBought = TotalBought + 1
                    statBought.Text = tostring(TotalBought)
                    addLog("✅ Beli "..p.eggName.." dari Podium "..p.podium, C.green)
                    SendEggBought(p.eggName, p.podium)
                else
                    addLog("⚠ Gagal beli dari Podium "..p.podium, C.yellow)
                end
                task.wait(0.5)
            end
        end

        if not foundTarget then
            addLog("— Tidak ada target egg, cek lagi dalam "..CHECK_DELAY.."s", C.muted)
        end

        statStatus.Text      = "CEK /" .. #podiums .. " PODIUM"
        statStatus.TextColor3 = C.accent
        task.wait(CHECK_DELAY)
    end
end

runBtn.MouseButton1Click:Connect(function()
    Running = not Running
    if Running then
        runBtn.Text             = "⏹  Stop"
        runBtn.BackgroundColor3 = C.red
        statusDot.TextColor3    = C.green
        statStatus.Text         = "RUNNING"
        statStatus.TextColor3   = C.green
        task.spawn(RunLoop)
    else
        runBtn.Text             = "▶  Mulai Auto Buy Egg"
        runBtn.BackgroundColor3 = C.green
        statusDot.TextColor3    = C.muted
        statStatus.Text         = "IDLE"
        statStatus.TextColor3   = C.muted
    end
end)

addLog("Siap! Pilih egg target lalu tekan Mulai.", C.muted)
print("✅ AutoEgg v1 Loaded!")
