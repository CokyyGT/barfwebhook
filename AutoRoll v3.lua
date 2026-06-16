local Players    = game:GetService("Players")
local UIS        = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local Player  = Players.LocalPlayer
-- HTTP request kompatibel semua executor
local Request = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
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

local TARGET_RARITIES  = {}
local ROLL_DELAY       = 2
local SEED_WAIT        = 6
local WEBHOOK_URL      = ""
local WEBHOOK_ENABLED  = false

for _, r in ipairs(RARITIES) do
    TARGET_RARITIES[r.name] = r.enabled
end

-- ══════════════════════════════════════
--         CONFIG SAVE/LOAD
-- ══════════════════════════════════════
local CONFIG_FILE = "autoroll_config.json"

local function SaveConfig()
    local rarityState = {}
    for _, r in ipairs(RARITIES) do
        rarityState[r.name] = r.enabled
    end
    local data = {
        rarities        = rarityState,
        roll_delay      = ROLL_DELAY,
        seed_wait       = SEED_WAIT,
        webhook_url     = WEBHOOK_URL,
        webhook_enabled = WEBHOOK_ENABLED,
    }
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function LoadConfig()
    local ok, raw = pcall(readfile, CONFIG_FILE)
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
    if data.roll_delay      then ROLL_DELAY      = data.roll_delay      end
    if data.seed_wait       then SEED_WAIT       = data.seed_wait       end
    if data.webhook_url     then WEBHOOK_URL     = data.webhook_url     end
    if data.webhook_enabled ~= nil then WEBHOOK_ENABLED = data.webhook_enabled end
end

-- Load saved config
LoadConfig()

-- ══════════════════════════════════════
--           STATE
-- ══════════════════════════════════════
local Running     = false
local TotalRolls  = 0
local TotalBought = 0
local StartTime   = os.time()
local myPlot      = nil
local rollPrompt  = nil

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
--           WEBHOOK
-- ══════════════════════════════════════
local function SendWebhook(title, desc, color)
    if not WEBHOOK_ENABLED or WEBHOOK_URL == "" or not Request then return end
    pcall(function()
        Request({
            Url    = WEBHOOK_URL, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body   = HttpService:JSONEncode({
                embeds = {{
                    title       = title,
                    description = desc,
                    color       = color,
                    footer      = { text = "Build A Ring Farm  •  Auto Roll" },
                    timestamp   = DateTime.now():ToIsoDate()
                }}
            })
        })
    end)
end

local function SendActivated()
    local targets = {}
    for _, r in ipairs(RARITIES) do
        if r.enabled then table.insert(targets, r.name) end
    end
    SendWebhook("🟢  Auto Roll Activated", table.concat({
        "```",
        "👤 Player  : " .. Player.Name,
        "🎯 Target  : " .. (#targets > 0 and table.concat(targets, ", ") or "None"),
        "⏱ Delay   : " .. ROLL_DELAY .. "s",
        "🕐 Waktu   : " .. GetWIB(),
        "```"
    }, "\n"), 3066993)
end

local function SendSeedFound(seedName, rarity)
    local rarityColor = 16776960
    for _, r in ipairs(RARITIES) do
        if r.name == rarity then
            rarityColor = math.floor(r.color.R*255)*65536
                        + math.floor(r.color.G*255)*256
                        + math.floor(r.color.B*255)
            break
        end
    end
    SendWebhook("🌟  Seed Target Ditemukan!", table.concat({
        "🌱 **" .. seedName .. "**", "",
        "```",
        "✨ Rarity    : " .. rarity,
        "🎲 Roll ke-  : " .. TotalRolls,
        "🌱 Total Beli: " .. TotalBought,
        "⏱ Uptime    : " .. GetUptime(),
        "🕐 Waktu     : " .. GetWIB(),
        "```"
    }, "\n"), rarityColor)
end

local function SendStopped()
    SendWebhook("🔴  Auto Roll Berhenti", table.concat({
        "```",
        "👤 Player      : " .. Player.Name,
        "🎲 Total Roll  : " .. TotalRolls,
        "🌱 Total Beli  : " .. TotalBought,
        "⏱ Uptime      : " .. GetUptime(),
        "🕐 Waktu       : " .. GetWIB(),
        "```"
    }, "\n"), 15158332)
end

-- ══════════════════════════════════════
--   UNIVERSAL FIRE PROMPT
--   fireproximityprompt = Synapse/Delta dll
--   Xeno ga punya → jalan ke posisi dulu
--   lalu pakai TouchInterest / RemoteEvent
-- ══════════════════════════════════════
local HasFireProximity = (fireproximityprompt ~= nil)

local function WalkTo(position)
    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then
        hum:MoveTo(position)
        -- Tunggu sampe deket (max 5s)
        local t = 0
        while t < 5 do
            task.wait(0.1); t = t + 0.1
            if (hrp.Position - position).Magnitude < 5 then break end
        end
    end
end

local function FirePrompt(prompt)
    if not prompt then return false end
    if HasFireProximity then
        -- Synapse X, Delta, Script-Ware, dll
        return pcall(fireproximityprompt, prompt)
    else
        -- Xeno & executor tanpa fireproximityprompt
        -- Jalan ke posisi prompt dulu, lalu trigger
        local part = prompt.Parent
        if part and part:IsA("BasePart") then
            WalkTo(part.Position)
        elseif part then
            local bp = part:FindFirstChildOfClass("BasePart")
            if bp then WalkTo(bp.Position) end
        end
        -- Coba trigger via TouchInterest
        local ok = pcall(function()
            local ti = prompt.Parent:FindFirstChild("TouchInterest")
            if ti then
                firetouchinterest(Player.Character.HumanoidRootPart, ti, 0)
            end
        end)
        if not ok then
            -- Fallback: trigger langsung
            ok = pcall(function()
                prompt.Triggered:Fire(Player)
            end)
        end
        return ok
    end
end

-- ══════════════════════════════════════
--           FIND PLOT & PROMPT
-- ══════════════════════════════════════
local function FindPlotAndPrompt()
    myPlot = nil; rollPrompt = nil
    local map = workspace:FindFirstChild("Map")
    if not map then return false end
    local plotsContainer = map:FindFirstChild("Plots")
    if not plotsContainer then return false end
    for _, plot in ipairs(plotsContainer:GetChildren()) do
        if not plot.Name:match("^Plot") then continue end
        local ownerSign = plot:FindFirstChild("OwnerSign")
        local isOwner   = false
        if ownerSign then
            for _, desc in ipairs(ownerSign:GetDescendants()) do
                if desc:IsA("TextLabel") then
                    if desc.Text:gsub("^%s*(.-)%s*$","%1") == Player.Name then
                        isOwner = true; break
                    end
                end
            end
        end
        if isOwner then
            myPlot = plot
            local rp = plot:FindFirstChild("RollPlatform")
            if rp then
                local lv = rp:FindFirstChild("Lever")
                if lv then
                    local lp = lv:FindFirstChild("LevelPrompt")
                    if lp then rollPrompt = lp:FindFirstChild("RollSeeds") end
                    if not rollPrompt then
                        for _, d in ipairs(lv:GetDescendants()) do
                            if d:IsA("ProximityPrompt") then rollPrompt = d; break end
                        end
                    end
                end
            end
            if not rollPrompt then
                for _, d in ipairs(plot:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and
                       (d.Name:match("Roll") or d.Name:match("Seed")) then
                        rollPrompt = d; break
                    end
                end
            end
            if rollPrompt then return true end
        end
    end
    return false
end

-- ══════════════════════════════════════
--           SCAN SEEDS
-- ══════════════════════════════════════
local function ScanSeeds()
    local seeds = {}
    for _, v in ipairs(workspace:GetChildren()) do
        local buySeed = v:FindFirstChild("BuySeed", true)
        local rarity  = v:FindFirstChild("Rarity",  true)
        local nameLbl = v:FindFirstChild("NameLabel", true)
        if buySeed and rarity and nameLbl then
            table.insert(seeds, {
                name   = nameLbl.Text,
                rarity = rarity.Text,
                prompt = buySeed,
            })
        end
    end
    return seeds
end

-- ══════════════════════════════════════
--           UI HELPERS
-- ══════════════════════════════════════
if game.CoreGui:FindFirstChild("AutoRollUI") then
    game.CoreGui.AutoRollUI:Destroy()
end

local sg = Instance.new("ScreenGui")
sg.Name          = "AutoRollUI"
sg.ResetOnSpawn  = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent        = game.CoreGui

local C = {
    bg      = Color3.fromRGB(15, 15, 20),
    surface = Color3.fromRGB(24, 24, 32),
    card    = Color3.fromRGB(30, 30, 42),
    border  = Color3.fromRGB(55, 55, 75),
    accent  = Color3.fromRGB(99, 179, 237),
    green   = Color3.fromRGB(72, 199, 142),
    text    = Color3.fromRGB(225, 225, 235),
    muted   = Color3.fromRGB(110, 110, 140),
    red     = Color3.fromRGB(220, 80, 80),
    gold    = Color3.fromRGB(255, 210, 60),
    yellow  = Color3.fromRGB(255, 185, 40),
    white   = Color3.fromRGB(255, 255, 255),
}

local function corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function stroke(p, color, thick)
    local s = Instance.new("UIStroke")
    s.Color     = color or C.border
    s.Thickness = thick or 1
    s.Parent    = p
    return s
end

local function pad(p, all, l, r, t, b)
    local u = Instance.new("UIPadding")
    u.PaddingLeft   = UDim.new(0, l or all or 0)
    u.PaddingRight  = UDim.new(0, r or all or 0)
    u.PaddingTop    = UDim.new(0, t or all or 0)
    u.PaddingBottom = UDim.new(0, b or all or 0)
    u.Parent        = p
end

local function mkLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font      = props.font  or Enum.Font.Gotham
    l.TextSize  = props.size  or 11
    l.TextColor3 = props.color or C.text
    l.TextXAlignment = props.align or Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Center
    l.Size      = props.sz    or UDim2.new(1,0,0,20)
    l.Position  = props.pos   or UDim2.new(0,0,0,0)
    l.Text      = props.text  or ""
    l.ZIndex    = props.z     or 1
    l.Parent    = parent
    return l
end

local function mkBtn(parent, props)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = props.bg   or C.card
    b.BorderSizePixel  = 0
    b.Font             = props.font or Enum.Font.GothamBold
    b.TextSize         = props.size or 11
    b.TextColor3       = props.color or C.white
    b.Text             = props.text or ""
    b.Size             = props.sz   or UDim2.new(1,0,0,30)
    b.Position         = props.pos  or UDim2.new(0,0,0,0)
    b.ZIndex           = props.z    or 1
    b.AutoButtonColor  = false
    b.Parent           = parent
    corner(b, props.r or 8)
    return b
end

-- ══════════════════════════════════════
--           MAIN FRAME
-- ══════════════════════════════════════
local UI_W       = 380
local FULL_H     = 0   -- will be set after content
local MINI_H     = 44
local SECTION_PAD = 8

local main = Instance.new("Frame")
main.Name              = "Main"
main.BackgroundColor3  = C.bg
main.BorderSizePixel   = 0
main.ClipsDescendants  = true
main.Size              = UDim2.new(0, UI_W, 0, 500) -- temp
main.Position          = UDim2.new(0, 20, 0.5, -250)
main.Parent            = sg
corner(main, 12)
stroke(main, C.border, 1)

-- Gradient overlay top
local grad = Instance.new("UIGradient")
grad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(35,35,55)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(15,15,20)),
})
grad.Rotation = 90
grad.Parent   = main

-- ── Header ──
local header = Instance.new("Frame")
header.Size             = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = C.surface
header.BorderSizePixel  = 0
header.ZIndex           = 20
header.Parent           = main
corner(header, 12)

-- header bottom filler so corners only show top
local hFill = Instance.new("Frame")
hFill.Size             = UDim2.new(1,0,0,12)
hFill.Position         = UDim2.new(0,0,1,-12)
hFill.BackgroundColor3 = C.surface
hFill.BorderSizePixel  = 0
hFill.ZIndex           = 19
hFill.Parent           = header

local titleLbl = mkLabel(header, {
    text  = "🎲  Auto Roll Seed",
    font  = Enum.Font.GothamBold,
    size  = 14,
    color = C.white,
    sz    = UDim2.new(1,-90,1,0),
    pos   = UDim2.new(0,14,0,0),
    z     = 21,
})

local statusDot = mkLabel(header, {
    text  = "●",
    font  = Enum.Font.GothamBold,
    size  = 10,
    color = C.muted,
    sz    = UDim2.new(0,12,0,12),
    pos   = UDim2.new(0,160,0.5,-6),
    z     = 21,
})

local minBtn = mkBtn(header, {
    text  = "—",
    bg    = C.border,
    color = C.text,
    size  = 12,
    sz    = UDim2.new(0,26,0,26),
    pos   = UDim2.new(1,-60,0.5,-13),
    r     = 6,
    z     = 21,
})

local closeBtn = mkBtn(header, {
    text  = "✕",
    bg    = C.red,
    size  = 12,
    sz    = UDim2.new(0,26,0,26),
    pos   = UDim2.new(1,-30,0.5,-13),
    r     = 6,
    z     = 21,
})
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- ── Scroll content ──
local scroll = Instance.new("ScrollingFrame")
scroll.Name                    = "Scroll"
scroll.Size                    = UDim2.new(1,0,1,-44)
scroll.Position                = UDim2.new(0,0,0,44)
scroll.BackgroundTransparency  = 1
scroll.BorderSizePixel         = 0
scroll.ScrollBarThickness      = 3
scroll.ScrollBarImageColor3    = C.border
scroll.ScrollingDirection      = Enum.ScrollingDirection.Y
scroll.CanvasSize              = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize     = Enum.AutomaticSize.Y
scroll.Parent                  = main

local contentList = Instance.new("UIListLayout")
contentList.Padding            = UDim.new(0, SECTION_PAD)
contentList.FillDirection      = Enum.FillDirection.Vertical
contentList.SortOrder          = Enum.SortOrder.LayoutOrder
contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
contentList.Parent             = scroll
pad(scroll, SECTION_PAD)

-- ── Auto-resize main to content ──
contentList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local h = contentList.AbsoluteContentSize.Y + SECTION_PAD*2 + 44
    main.Size = UDim2.new(0, UI_W, 0, math.min(h, 650))
end)

-- ── Section helper ──
local sectionOrder = 0
local function mkSection(title, innerH)
    sectionOrder = sectionOrder + 1
    local wrap = Instance.new("Frame")
    wrap.BackgroundTransparency = 1
    wrap.BorderSizePixel        = 0
    wrap.Size                   = UDim2.new(1, -SECTION_PAD*2, 0, 0)
    wrap.AutomaticSize          = Enum.AutomaticSize.Y
    wrap.LayoutOrder            = sectionOrder
    wrap.Parent                 = scroll

    local wList = Instance.new("UIListLayout")
    wList.Padding    = UDim.new(0, 4)
    wList.SortOrder  = Enum.SortOrder.LayoutOrder
    wList.Parent     = wrap

    if title then
        local hdr = mkLabel(wrap, {
            text  = title,
            font  = Enum.Font.GothamBold,
            size  = 9,
            color = C.muted,
            sz    = UDim2.new(1,0,0,14),
        })
        hdr.LayoutOrder = 0
    end

    local card = Instance.new("Frame")
    card.BackgroundColor3 = C.card
    card.BorderSizePixel  = 0
    card.Size             = UDim2.new(1,0,0,innerH or 60)
    card.AutomaticSize    = innerH and Enum.AutomaticSize.None or Enum.AutomaticSize.Y
    card.LayoutOrder      = 1
    card.Parent           = wrap
    corner(card, 10)
    stroke(card, C.border, 1)
    return card
end

-- ══════════════════════════════════════
--         STATS SECTION
-- ══════════════════════════════════════
local statsCard = mkSection(nil, 54)

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection       = Enum.FillDirection.Horizontal
statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
statsLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
statsLayout.Padding             = UDim.new(0,0)
statsLayout.Parent              = statsCard
pad(statsCard, 0, 8, 8, 4, 4)

local statRolls, statBought, statUptime

local function mkStatCol(parent, label)
    local col = Instance.new("Frame")
    col.BackgroundTransparency = 1
    col.Size                   = UDim2.new(0.333, 0, 1, 0)
    col.BorderSizePixel        = 0
    col.Parent                 = parent

    local colList = Instance.new("UIListLayout")
    colList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    colList.VerticalAlignment   = Enum.VerticalAlignment.Center
    colList.Parent              = col

    local v = mkLabel(col, {
        text  = "0",
        font  = Enum.Font.GothamBold,
        size  = 20,
        color = C.accent,
        sz    = UDim2.new(1,0,0,24),
        align = Enum.TextXAlignment.Center,
    })
    mkLabel(col, {
        text  = label,
        size  = 8,
        color = C.muted,
        sz    = UDim2.new(1,0,0,12),
        align = Enum.TextXAlignment.Center,
    })
    return v
end

statRolls  = mkStatCol(statsCard, "TOTAL ROLL")
statBought = mkStatCol(statsCard, "TOTAL BELI")
statUptime = mkStatCol(statsCard, "UPTIME")

task.spawn(function()
    while task.wait(1) do statUptime.Text = GetUptime() end
end)

-- ══════════════════════════════════════
--         RARITY SECTION
-- ══════════════════════════════════════
local rarityCard = mkSection("TARGET RARITY")
pad(rarityCard, 8)

local rarityGrid = Instance.new("UIGridLayout")
rarityGrid.CellSize             = UDim2.new(0, 100, 0, 28)
rarityGrid.CellPadding          = UDim2.new(0, 5, 0, 5)
rarityGrid.HorizontalAlignment  = Enum.HorizontalAlignment.Center
rarityGrid.Parent               = rarityCard

local rarityBtns = {}
for _, r in ipairs(RARITIES) do
    local btn = mkBtn(rarityCard, {
        text  = r.name,
        bg    = r.enabled and r.color or C.border,
        color = r.enabled and Color3.fromRGB(15,15,15) or C.muted,
        size  = 9,
        r     = 6,
    })
    rarityBtns[r.name] = btn
    btn.MouseButton1Click:Connect(function()
        r.enabled = not r.enabled
        TARGET_RARITIES[r.name] = r.enabled
        btn.BackgroundColor3 = r.enabled and r.color or C.border
        btn.TextColor3       = r.enabled and Color3.fromRGB(15,15,15) or C.muted
        SaveConfig()
    end)
end

-- dummy filler so grid height is right (12 items, 3 col = 4 rows)
task.defer(function()
    local rows = math.ceil(#RARITIES / 3)
    rarityCard.Size = UDim2.new(1, 0, 0, rows * 28 + (rows-1)*5 + 16)
end)

-- ══════════════════════════════════════
--         SETTINGS SECTION
-- ══════════════════════════════════════
local settCard = mkSection("SETTINGS")
pad(settCard, 10)

local settList = Instance.new("UIListLayout")
settList.Padding   = UDim.new(0, 8)
settList.SortOrder = Enum.SortOrder.LayoutOrder
settList.Parent    = settCard

-- Slider row
local sliderOrder = 0
local function mkSlider(parent, label, default, minV, maxV, step, onChange)
    sliderOrder = sliderOrder + 1
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.BorderSizePixel        = 0
    row.Size                   = UDim2.new(1,0,0,28)
    row.LayoutOrder            = sliderOrder
    row.Parent                 = parent

    mkLabel(row, {
        text  = label,
        size  = 10,
        color = C.text,
        sz    = UDim2.new(0.55,0,1,0),
    })

    local minus = mkBtn(row, {
        text  = "−",
        bg    = C.surface,
        size  = 15,
        sz    = UDim2.new(0,26,0,22),
        pos   = UDim2.new(1,-78,0.5,-11),
        r     = 6,
    })
    stroke(minus, C.border)

    local valLbl = mkLabel(row, {
        text  = tostring(default),
        font  = Enum.Font.GothamBold,
        size  = 11,
        color = C.accent,
        sz    = UDim2.new(0,28,0,22),
        pos   = UDim2.new(1,-50,0.5,-11),
        align = Enum.TextXAlignment.Center,
    })

    local plus = mkBtn(row, {
        text  = "+",
        bg    = C.surface,
        size  = 15,
        sz    = UDim2.new(0,26,0,22),
        pos   = UDim2.new(1,-22,0.5,-11),
        r     = 6,
    })
    stroke(plus, C.border)

    local cur = default
    minus.MouseButton1Click:Connect(function()
        cur = math.max(minV, math.round((cur - step)*10)/10)
        valLbl.Text = tostring(cur)
        onChange(cur)
        SaveConfig()
    end)
    plus.MouseButton1Click:Connect(function()
        cur = math.min(maxV, math.round((cur + step)*10)/10)
        valLbl.Text = tostring(cur)
        onChange(cur)
        SaveConfig()
    end)
    return valLbl
end

local rollDelayVal = mkSlider(settCard, "Roll Delay (detik)", ROLL_DELAY, 0.5, 15, 0.5, function(v) ROLL_DELAY = v end)
local seedWaitVal  = mkSlider(settCard, "Seed Wait (detik)",  SEED_WAIT,  1,   15, 0.5, function(v) SEED_WAIT  = v end)

-- sync display with loaded config
rollDelayVal.Text = tostring(ROLL_DELAY)
seedWaitVal.Text  = tostring(SEED_WAIT)

-- ══════════════════════════════════════
--         WEBHOOK SECTION
-- ══════════════════════════════════════
local whCard = mkSection("DISCORD WEBHOOK")
pad(whCard, 10)

local whList = Instance.new("UIListLayout")
whList.Padding   = UDim.new(0, 6)
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

mkLabel(togRow, {
    text  = "Aktifkan notif Discord",
    size  = 10,
    color = C.muted,
    sz    = UDim2.new(1,-50,1,0),
    pos   = UDim2.new(0,44,0,0),
})

local whStatusLbl = mkLabel(togRow, {
    text  = "OFF",
    font  = Enum.Font.GothamBold,
    size  = 9,
    color = C.muted,
    sz    = UDim2.new(0,32,1,0),
    pos   = UDim2.new(1,-32,0,0),
    align = Enum.TextXAlignment.Right,
})

-- URL label
local urlLblRow = Instance.new("Frame")
urlLblRow.BackgroundTransparency = 1
urlLblRow.BorderSizePixel        = 0
urlLblRow.Size                   = UDim2.new(1,0,0,14)
urlLblRow.LayoutOrder            = 2
urlLblRow.Parent                 = whCard
mkLabel(urlLblRow, {text="Webhook URL", size=9, color=C.muted})

-- URL TextBox
local urlBoxRow = Instance.new("Frame")
urlBoxRow.BackgroundTransparency = 1
urlBoxRow.BorderSizePixel        = 0
urlBoxRow.Size                   = UDim2.new(1,0,0,30)
urlBoxRow.LayoutOrder            = 3
urlBoxRow.Parent                 = whCard

local urlBox = Instance.new("TextBox")
urlBox.Size               = UDim2.new(1,0,1,0)
urlBox.BackgroundColor3   = C.surface
urlBox.BorderSizePixel    = 0
urlBox.Text               = WEBHOOK_URL
urlBox.PlaceholderText    = "https://discord.com/api/webhooks/..."
urlBox.PlaceholderColor3  = C.border
urlBox.TextColor3         = C.text
urlBox.TextSize           = 9
urlBox.Font               = Enum.Font.Gotham
urlBox.TextXAlignment     = Enum.TextXAlignment.Left
urlBox.ClearTextOnFocus   = false
urlBox.ClipsDescendants   = true
urlBox.Parent             = urlBoxRow
corner(urlBox, 6)
pad(urlBox, 0, 8, 8, 0, 0)
local urlStroke = stroke(urlBox, C.border)

-- Buttons row
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

local saveBtn = mkBtn(whBtnRow, {
    text  = "💾  Simpan",
    bg    = C.green,
    size  = 10,
    sz    = UDim2.new(0.5,-3,1,0),
    r     = 7,
})

local testBtn = mkBtn(whBtnRow, {
    text  = "🔔  Test",
    bg    = C.surface,
    color = C.text,
    size  = 10,
    sz    = UDim2.new(0.5,-3,1,0),
    r     = 7,
})
stroke(testBtn, C.border)

-- Webhook logic
local function IsValidWebhook(url)
    return type(url)=="string"
        and url:match("^https://discord%.com/api/webhooks/%d+/.+") ~= nil
end

local function UpdateWhStatus()
    if not WEBHOOK_ENABLED then
        whStatusLbl.Text       = "OFF"
        whStatusLbl.TextColor3 = C.muted
        togBg.BackgroundColor3 = C.border
        togCircle.Position     = UDim2.new(0,3,0.5,-6)
        togCircle.BackgroundColor3 = C.muted
        urlStroke.Color        = C.border
    elseif not IsValidWebhook(WEBHOOK_URL) then
        whStatusLbl.Text       = "⚠"
        whStatusLbl.TextColor3 = C.yellow
        urlStroke.Color        = C.yellow
    else
        whStatusLbl.Text       = "ON"
        whStatusLbl.TextColor3 = C.green
        togBg.BackgroundColor3 = C.green
        togCircle.Position     = UDim2.new(0,21,0.5,-6)
        togCircle.BackgroundColor3 = C.white
        urlStroke.Color        = C.green
    end
end

togHit.MouseButton1Click:Connect(function()
    WEBHOOK_ENABLED = not WEBHOOK_ENABLED
    UpdateWhStatus()
    SaveConfig()
end)

saveBtn.MouseButton1Click:Connect(function()
    local url = urlBox.Text
    if IsValidWebhook(url) then
        WEBHOOK_URL = url
        saveBtn.Text = "✅  Tersimpan!"
        saveBtn.BackgroundColor3 = C.green
        SaveConfig()
        task.delay(1.5, function()
            saveBtn.Text = "💾  Simpan"
            saveBtn.BackgroundColor3 = C.green
        end)
    else
        saveBtn.Text = "❌  URL Salah"
        saveBtn.BackgroundColor3 = C.red
        task.delay(1.5, function()
            saveBtn.Text = "💾  Simpan"
            saveBtn.BackgroundColor3 = C.green
        end)
    end
    UpdateWhStatus()
end)

testBtn.MouseButton1Click:Connect(function()
    if not IsValidWebhook(WEBHOOK_URL) then
        testBtn.Text = "❌ Set URL dulu!"
        testBtn.BackgroundColor3 = C.red
        task.delay(1.5, function()
            testBtn.Text = "🔔  Test"
            testBtn.BackgroundColor3 = C.surface
        end)
        return
    end
    testBtn.Text = "⏳ Mengirim..."
    testBtn.BackgroundColor3 = C.yellow
    local ok = pcall(function()
        Request({
            Url = WEBHOOK_URL, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ embeds = {{
                title = "🔔  Webhook Test",
                description = table.concat({
                    "```",
                    "✅ Terhubung!",
                    "👤 Player : " .. Player.Name,
                    "🕐 Waktu  : " .. GetWIB(),
                    "```"
                }, "\n"),
                color = 3066993,
                footer = { text = "Build A Ring Farm  •  Auto Roll" },
                timestamp = DateTime.now():ToIsoDate()
            }}})
        })
    end)
    testBtn.Text = ok and "✅ Berhasil!" or "❌ Gagal!"
    testBtn.BackgroundColor3 = ok and C.green or C.red
    task.delay(1.5, function()
        testBtn.Text = "🔔  Test"
        testBtn.BackgroundColor3 = C.surface
    end)
end)

UpdateWhStatus()

-- ══════════════════════════════════════
--         LOG SECTION
-- ══════════════════════════════════════
local logCard = mkSection("LOG", 70)

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size                   = UDim2.new(1,-16,1,-10)
logScroll.Position               = UDim2.new(0,8,0,5)
logScroll.BackgroundTransparency = 1
logScroll.BorderSizePixel        = 0
logScroll.ScrollBarThickness     = 2
logScroll.ScrollBarImageColor3   = C.border
logScroll.CanvasSize             = UDim2.new(0,0,0,0)
logScroll.Parent                 = logCard

local logList = Instance.new("UIListLayout")
logList.Padding  = UDim.new(0,2)
logList.SortOrder = Enum.SortOrder.LayoutOrder
logList.Parent   = logScroll

logList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    logScroll.CanvasSize     = UDim2.new(0,0,0,logList.AbsoluteContentSize.Y)
    logScroll.CanvasPosition = Vector2.new(0, logList.AbsoluteContentSize.Y)
end)

local logOrder = 0
local function addLog(msg, color)
    -- prune old
    local children = logScroll:GetChildren()
    local count = 0
    for _, c in ipairs(children) do if c:IsA("TextLabel") then count=count+1 end end
    if count > 40 then
        for _, c in ipairs(children) do
            if c:IsA("TextLabel") then c:Destroy(); break end
        end
    end
    logOrder = logOrder + 1
    local l = Instance.new("TextLabel")
    l.Size                = UDim2.new(1,0,0,12)
    l.BackgroundTransparency = 1
    l.Text                = "[" .. GetWIB() .. "] " .. msg
    l.TextColor3          = color or C.muted
    l.TextSize            = 9
    l.Font                = Enum.Font.Gotham
    l.TextXAlignment      = Enum.TextXAlignment.Left
    l.LayoutOrder         = logOrder
    l.Parent              = logScroll
end

-- ══════════════════════════════════════
--         RUN BUTTON
-- ══════════════════════════════════════
sectionOrder = sectionOrder + 1
local runWrap = Instance.new("Frame")
runWrap.BackgroundTransparency = 1
runWrap.BorderSizePixel        = 0
runWrap.Size                   = UDim2.new(1,-SECTION_PAD*2,0,38)
runWrap.LayoutOrder            = sectionOrder
runWrap.Parent                 = scroll

local runBtn = mkBtn(runWrap, {
    text  = "▶  Mulai Auto Roll",
    bg    = C.green,
    size  = 13,
    sz    = UDim2.new(1,0,1,0),
    r     = 10,
})

-- ══════════════════════════════════════
--           DRAG
-- ══════════════════════════════════════
local dragging, dragStart, startPos
header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = inp.Position
        startPos  = main.Position
    end
end)
UIS.InputChanged:Connect(function(inp)
    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
        local d = inp.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ── Minimize ──
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    scroll.Visible = not minimized
    if minimized then
        main.Size = UDim2.new(0, UI_W, 0, MINI_H)
    else
        local h = contentList.AbsoluteContentSize.Y + SECTION_PAD*2 + 44
        main.Size = UDim2.new(0, UI_W, 0, math.min(h, 650))
    end
    minBtn.Text = minimized and "+" or "—"
end)

-- ══════════════════════════════════════
--           MAIN LOOP
-- ══════════════════════════════════════
local function TryBuySeeds(logFn, maxAttempts, waitPerAttempt)
    local bought        = false
    local alreadyBought = {}
    maxAttempts    = maxAttempts    or 12
    waitPerAttempt = waitPerAttempt or 1

    for attempt = 1, maxAttempts do
        if not Running then break end

        local seeds    = ScanSeeds()
        local foundAny = false

        for _, seed in ipairs(seeds) do
            if TARGET_RARITIES[seed.rarity] and not alreadyBought[seed.name] then
                foundAny = true
                logFn("🌟 " .. seed.name .. " [" .. seed.rarity .. "]!", C.gold)
                local buyOk = false
                for _fire = 1, 5 do
                    local ok2, _ = FirePrompt(seed.prompt)
                    if ok2 then buyOk = true end
                    task.wait(0.1)
                end
                if buyOk then
                    alreadyBought[seed.name] = true
                    TotalBought = TotalBought + 1
                    statBought.Text = tostring(TotalBought)
                    logFn("✅ Beli " .. seed.name, C.green)
                    SendSeedFound(seed.name, seed.rarity)
                    bought = true
                else
                    logFn("⚠ Gagal beli " .. seed.name .. " (#"..attempt..")", C.yellow)
                end
            end
        end

        if not foundAny and attempt >= 2 then break end
        if attempt < maxAttempts then task.wait(waitPerAttempt) end
    end
    return bought
end

-- ══════════════════════════════════════
--   Monitor workspace sampai semua plot
--   berhenti ngacak seed (nama stabil)
-- ══════════════════════════════════════

-- Ambil snapshot nama+rarity semua seed yang ada sekarang
local function SnapshotSeeds()
    local snap = {}
    for _, v in ipairs(workspace:GetChildren()) do
        local buySeed = v:FindFirstChild("BuySeed", true)
        local rarity  = v:FindFirstChild("Rarity",  true)
        local nameLbl = v:FindFirstChild("NameLabel", true)
        if buySeed and rarity and nameLbl then
            table.insert(snap, nameLbl.Text .. "|" .. rarity.Text)
        end
    end
    table.sort(snap)
    return table.concat(snap, ",")
end

local function WaitWorkspaceStable()
    -- Tunggu sampai snapshot nama+rarity seed tidak berubah
    -- selama 5x berturut (1s) = semua plot berhenti ngacak
    -- Max tunggu total 12s
    local elapsed  = 0
    local prevSnap = ""
    local sameFor  = 0

    while elapsed < 12 do
        task.wait(0.2); elapsed = elapsed + 0.2
        local snap = SnapshotSeeds()
        if snap == prevSnap and snap ~= "" then
            sameFor = sameFor + 1
            if sameFor >= 5 then return end  -- 1s stabil = beneran berhenti ngacak
        else
            sameFor  = 0
            prevSnap = snap
        end
    end
end

local function RunLoop()
    if not FindPlotAndPrompt() then
        addLog("❌ Plot/RollSeeds tidak ditemukan!", C.red)
        Running = false
        runBtn.Text = "▶  Mulai Auto Roll"
        runBtn.BackgroundColor3 = C.green
        statusDot.TextColor3    = C.muted
        return
    end

    addLog("✅ Plot: " .. myPlot.Name, C.green)
    addLog("Auto roll dimulai!", C.accent)
    SendActivated()

    local BONUS_OBJECTS = {"2xClover","4xClover","8xClover","16xClover","Jackpot","jackpot"}

    local function FindBonusObject()
        for _, name in ipairs(BONUS_OBJECTS) do
            local obj = workspace:FindFirstChild(name)
            if obj then return obj.Name end
        end
        return nil
    end

    local function BuySeedList(seedList)
        local gotTarget = false
        for _, seed in ipairs(seedList) do
            if TARGET_RARITIES[seed.rarity] then
                addLog("🌟 " .. seed.name .. " [" .. seed.rarity .. "]!", C.gold)
                local buyOk = false
                for _fire = 1, 5 do
                    local ok2, _ = FirePrompt(seed.prompt)
                    if ok2 then buyOk = true end
                    task.wait(0.1)
                end
                if buyOk then
                    TotalBought = TotalBought + 1
                    statBought.Text = tostring(TotalBought)
                    addLog("✅ Beli " .. seed.name, C.green)
                    SendSeedFound(seed.name, seed.rarity)
                    gotTarget = true
                else
                    addLog("⚠ Gagal beli " .. seed.name, C.yellow)
                end
            end
        end
        return gotTarget
    end

    while Running do
        -- Roll
        local ok, _ = FirePrompt(rollPrompt)
        if ok then
            TotalRolls = TotalRolls + 1
            statRolls.Text = tostring(TotalRolls)
            addLog("Roll #" .. TotalRolls, C.muted)
        else
            addLog("❌ Gagal roll!", C.red)
        end

        -- Pasang listener SEGERA setelah roll
        local bonusDetected = FindBonusObject()
        local bonusTimes = {} -- catat waktu muncul tiap bonus

        local bonusAddConn = workspace.ChildAdded:Connect(function(v)
            for _, name in ipairs(BONUS_OBJECTS) do
                if v.Name == name then
                    bonusTimes[name] = os.clock()
                    bonusDetected = name
                    break
                end
            end
        end)

        local bonusRemConn = workspace.ChildRemoved:Connect(function(v)
            for _, name in ipairs(BONUS_OBJECTS) do
                if v.Name == name then
                    -- Kalau hilang dalam < 0.5s = flash, batalkan deteksi
                    local appeared = bonusTimes[name]
                    if appeared and (os.clock() - appeared) < 0.5 then
                        if bonusDetected == name then
                            bonusDetected = FindBonusObject() -- cek masih ada yang lain
                        end
                    end
                    break
                end
            end
        end)

        -- Tunggu seed muncul
        WaitWorkspaceStable()
        task.wait(0.2)
        bonusAddConn:Disconnect()
        bonusRemConn:Disconnect()

        -- Cek ulang bonus sekarang kalau listener kelewatan
        if not bonusDetected then
            bonusDetected = FindBonusObject()
        end

        if bonusDetected then
            -- ── LUCK MODE ──
            addLog("🍀 LUCK: " .. bonusDetected .. "...", C.gold)
            local finalTier = bonusDetected

            -- Tunggu bonus muncul dulu kalau belum ada
            local waitAppear = 0
            while not FindBonusObject() and waitAppear < 5 do
                task.wait(0.2)
                waitAppear = waitAppear + 0.2
            end

            -- Pasang listener tier naik agar tidak kelewat
            local tierConn = workspace.ChildAdded:Connect(function(v)
                for _, name in ipairs(BONUS_OBJECTS) do
                    if v.Name == name then
                        if name ~= finalTier then
                            addLog("⬆ " .. finalTier .. " → " .. name, C.gold)
                        end
                        finalTier = name
                        break
                    end
                end
            end)

            -- Tunggu sampai bonus benar-benar selesai
            -- Kalau tidak ada bonus selama 1.5s = selesai
            local bonusWait = 0
            local lastSeenBonus = os.clock()
            while bonusWait < 60 do
                task.wait(0.2)
                bonusWait = bonusWait + 0.2
                if FindBonusObject() then
                    lastSeenBonus = os.clock()
                else
                    if os.clock() - lastSeenBonus >= 1.5 then
                        break
                    end
                end
            end
            tierConn:Disconnect()

            addLog("🍀 [" .. finalTier .. "] selesai, beli seed!", C.gold)
            task.wait(0.3)
            local gotTarget = BuySeedList(ScanSeeds())
            if gotTarget then
                addLog("✅ Luck done!", C.green)
                task.wait(ROLL_DELAY)
            else
                addLog("✅ Luck done, lanjut roll!", C.green)
            end
        else
            -- ── NORMAL ROLL ──
            local gotTarget = BuySeedList(ScanSeeds())
            if gotTarget then
                task.wait(ROLL_DELAY)
            else
                addLog("— Lanjut roll", C.muted)
                task.wait(0.3)
            end
        end
    end

    SendStopped()
    addLog("Dihentikan.", C.red)
end

runBtn.MouseButton1Click:Connect(function()
    Running = not Running
    if Running then
        runBtn.Text             = "⏹  Stop"
        runBtn.BackgroundColor3 = C.red
        statusDot.TextColor3    = C.green
        task.spawn(RunLoop)
    else
        runBtn.Text             = "▶  Mulai Auto Roll"
        runBtn.BackgroundColor3 = C.green
        statusDot.TextColor3    = C.muted
    end
end)

addLog("Siap! Pilih rarity & tekan Mulai.", C.muted)
print("✅ AutoRoll v6 Loaded! (+ Clover/Jackpot Detection)")
