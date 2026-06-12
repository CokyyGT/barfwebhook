local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local WEBHOOK_URL = "https://discord.com/api/webhooks/1514898766040137779/WqgxA1O9VZX7qxtmY3hfMsbHCjCZuVKmWuiBND2DZzup8S84ZfpvcMqeMP1VlA0PhXtW"
local ROLE_ID = "1514999345819291648"
local Request = (syn and syn.request) or http_request or request

if not Request then
    warn("❌ Executor tidak mendukung HTTP Request")
    return
end

local PlayerGui = Player:WaitForChild("PlayerGui")
local GearShopFrame = PlayerGui:WaitForChild("MainUI"):WaitForChild("Menus"):WaitForChild("GearShopFrame")
local ScrollingFrame = GearShopFrame:WaitForChild("ScrollingFrame")
local RestockTimer = GearShopFrame:WaitForChild("RestockTimer")

local EGG_TYPES = {"CommonEgg", "RareEgg", "EpicEgg"}
local START_TIME = os.time()

-- ══════════════════════════════════════
--        CUSTOM EMOJI TABLE
-- ══════════════════════════════════════
local CUSTOM_EMOJI = {
    ["fire spray"]      = "<:Fire:1514892546466381906>",
    ["bubblegum spray"] = "<:Bubblegum:1514892495920824320>",
    ["cosmic spray"]    = "<:Cosmic:1514892463695859812>",
    ["rainbow spray"]   = "<:Rainbow:1514892436747321394>",
    ["EpicEgg"]         = "<:epic:1514990936675848273>",
    ["RareEgg"]         = "<:rare:1514990743436136550>",
    ["CommonEgg"]       = "<:Common:1514990825715798136>",
}

local FALLBACK_EMOJI = {
    fertilizer = "🌿",
    spray      = "💧",
    treat      = "🦴",
    other      = "📦",
}

-- ══════════════════════════════════════
--           HELPER: EMOJI
-- ══════════════════════════════════════
local function GetGearEmoji(name)
    local lower = name:lower()
    for key, emoji in pairs(CUSTOM_EMOJI) do
        if lower == key then return emoji end
    end
    if lower:find("fertilizer") then return FALLBACK_EMOJI.fertilizer
    elseif lower:find("spray")  then return FALLBACK_EMOJI.spray
    elseif lower:find("treat")  then return FALLBACK_EMOJI.treat
    else return FALLBACK_EMOJI.other end
end

-- ══════════════════════════════════════
--           UPTIME
-- ══════════════════════════════════════
local function GetUptime()
    local elapsed = os.time() - START_TIME
    local h = math.floor(elapsed / 3600)
    local m = math.floor((elapsed % 3600) / 60)
    local s = elapsed % 60
    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

-- ══════════════════════════════════════
--           SCAN GEAR SHOP
-- ══════════════════════════════════════
local function ScanGearShop()
    local items = {}
    for _, item in ipairs(ScrollingFrame:GetChildren()) do
        if item:IsA("ImageLabel")
            and item.Name ~= "ComingSoon"
            and item.Name ~= "UIListLayout"
            and item.Name ~= "UIPadding"
        then
            local gearName = item:FindFirstChild("GearName")
            local cost     = item:FindFirstChild("Cost")
            if gearName and cost then
                local stock = 0
                for _, child in ipairs(item:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                        local t = child.Text or ""
                        local s = tonumber(t:match("[Ss]t[oa][ck][k]?:?%s*(%d+)"))
                             or tonumber(t:match("(%d+)%s+[Ll]eft"))
                             or (child.Name:lower():find("stock") and tonumber(t:match("(%d+)")))
                        if s then stock = s break end
                    end
                end
                table.insert(items, {
                    name  = gearName.Text,
                    stock = stock,
                    cost  = cost.Text or "?",
                })
            end
        end
    end
    return items
end

-- ══════════════════════════════════════
--           SCAN EGG SHOP
-- ══════════════════════════════════════
local function ScanEggs()
    local counts = {}
    for _, eggName in ipairs(EGG_TYPES) do counts[eggName] = 0 end
    for _, v in ipairs(workspace:GetChildren()) do
        if counts[v.Name] ~= nil then
            counts[v.Name] = counts[v.Name] + 1
        end
    end
    return counts
end

-- ══════════════════════════════════════
--           BUILD FIELDS
-- ══════════════════════════════════════
local function BuildGearFields(items)
    local groups = {
        { label = "- 🌿  Fertilizers", key = "fertilizer", list = {} },
        { label = "- 💧  Sprays",      key = "spray",      list = {} },
        { label = "- 🦴  Pet Treats",  key = "treat",      list = {} },
        { label = "- 📦  Others",      key = "other",      list = {} },
    }

    for _, item in ipairs(items) do
        local lower = item.name:lower()
        local emoji = GetGearEmoji(item.name)
        local icon  = item.stock > 0 and "🟢" or "🔴"
        local line  = emoji .. "  **" .. item.name .. "**"
                   .. "  " .. icon .. " `" .. item.stock .. "`"
                   .. "  💰 `" .. item.cost .. "`"

        if lower:find("fertilizer") then
            table.insert(groups[1].list, line)
        elseif lower:find("spray") then
            table.insert(groups[2].list, line)
        elseif lower:find("treat") then
            table.insert(groups[3].list, line)
        else
            table.insert(groups[4].list, line)
        end
    end

    local fields = {}
    for _, g in ipairs(groups) do
        if #g.list > 0 then
            table.insert(fields, {
                name   = g.label,
                value  = table.concat(g.list, "\n"),
                inline = false
            })
        end
    end

    if #fields == 0 then
        table.insert(fields, { name = "⚠️ Kosong", value = "Tidak ada item di shop", inline = false })
    end
    return fields
end

local function BuildEggFields(counts)
    local lines = {}
    for _, eggName in ipairs(EGG_TYPES) do
        local emoji = CUSTOM_EMOJI[eggName] or "🥚"
        local count = counts[eggName] or 0
        local icon  = count > 0 and "🟢" or "🔴"
        local label = eggName:gsub("Egg", " Egg")
        table.insert(lines, {
            name   = emoji .. "  " .. label,
            value  = icon .. "  Stok: `" .. count .. "`\n" .. (count > 0 and "✅ `Ready`" or "❌ `Habis`"),
            inline = true
        })
    end
    return lines
end

-- ══════════════════════════════════════
--           TIMESTAMP
-- ══════════════════════════════════════
local function GetTimestamp()
    local dt  = DateTime.now()
    local utc = dt:ToUniversalTime()
    return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ",
        utc.Year, utc.Month, utc.Day,
        utc.Hour, utc.Minute, utc.Second)
end

-- ══════════════════════════════════════
--           BUILD EMBEDS
--   Kirim 2 embed dalam 1 POST
--   → tag role cuma muncul sekali!
-- ══════════════════════════════════════
local function BuildEmbeds(isRestock)
    local gearItems  = ScanGearShop()
    local eggCounts  = ScanEggs()
    local gearFields = BuildGearFields(gearItems)
    local eggFields  = BuildEggFields(eggCounts)

    local title  = isRestock and "🔄  RESTOCK ALERT!" or "🛒  Stock Update"
    local color  = isRestock and 3066993 or 5763719
    local ts     = GetTimestamp()
    local uptime = GetUptime()


    local footer = {
        text = "⏱️ Uptime: " .. uptime .. "  •  © Coky  •  Build A Ring Farm"
    }
 return {
           { title     = title .. "  —  Gear Shop",
            color     = color,
            fields    = #gearFields > 0 and gearFields or {
                { name = "⚠️ Kosong", value = "Tidak ada item di shop", inline = false }
            },
            footer    = footer,
            timestamp = ts
        },
        {
            title     = title .. "  —  Egg Shop",
            color     = color,
            fields    = #eggFields > 0 and eggFields or {
                { name = "⚠️ Kosong", value = "Tidak ada egg", inline = false }
            },
            footer    = footer,
            timestamp = ts
        }
    }
end

-- ══════════════════════════════════════
--    SEND WEBHOOK — 1 POST, 2 Embeds
--    Tag role hanya muncul 1x
-- ══════════════════════════════════════
local function SendWebhook(isRestock)
    local embeds = BuildEmbeds(isRestock)

    pcall(function()
        Request({
            Url     = WEBHOOK_URL .. "?wait=true",
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                content = "<@&" .. ROLE_ID .. ">",
                embeds  = embeds   -- kirim keduanya sekaligus!
            })
        })
        print("📨 Webhook terkirim! (" .. (isRestock and "🔄 Restock" or "🛒 Stock") .. ") | Uptime: " .. GetUptime())
    end)
end

-- ══════════════════════════════════════
--        MONITOR RESTOCK TIMER
-- ══════════════════════════════════════
local RestockState  = "IDLE"
local LastTimerText = ""

local function ParseTimerSeconds(text)
    local m, s = text:match("(%d+):(%d+)")
    if m and s then return tonumber(m) * 60 + tonumber(s) end
    return nil
end

RestockTimer:GetPropertyChangedSignal("Text"):Connect(function()
    local text = RestockTimer.Text
    if text == LastTimerText then return end
    LastTimerText = text

    local secs = ParseTimerSeconds(text)

    if RestockState == "IDLE" then
        if secs and secs <= 10 then
            RestockState = "NEAR_ZERO"
            print("⏳ Timer hampir habis, siap deteksi restock...")
        end

    elseif RestockState == "NEAR_ZERO" then
        if secs and secs >= 60 then
            RestockState = "SENT"
            task.spawn(function()
                print("🔄 Restock terdeteksi! Menunggu item muncul...")
                task.wait(2)
                SendWebhook(true)
                task.wait(3)
                RestockState = "IDLE"
                print("✅ State kembali IDLE")
            end)
        elseif not secs then
            RestockState = "WAITING_RESET"
        end

    elseif RestockState == "WAITING_RESET" then
        if secs and secs >= 30 then
            RestockState = "SENT"
            task.spawn(function()
                print("🔄 Restock terdeteksi (via reset)!")
                task.wait(2)
                SendWebhook(true)
                task.wait(3)
                RestockState = "IDLE"
                print("✅ State kembali IDLE")
            end)
        end
    end
end)

-- ══════════════════════════════════════
--              INIT
-- ══════════════════════════════════════
SendWebhook(false)
print("✅ Build A Ring Farm — Shop Monitor Started | © Copyright By Coky")
