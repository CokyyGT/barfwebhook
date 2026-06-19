if _G.BARFWebhookRunning then warn("⚠️ Webhook sudah berjalan!") return end
_G.BARFWebhookRunning = true

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer
local Backpack = Player:WaitForChild("Backpack")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1515326252540625039/WO3J6i9rahOqvFf_BLR4WOPWphyG3WBtGUYrhQ3YPM7ljndyS_ecE30C_oMx97oYuEIy"

local RARE_ITEMS = {
    ["mammoth"] = "<@&ROLE_ID_MAMMOTH>",
    ["hydra"]   = "<@&ROLE_ID_HYDRA>",
}

local Request = (syn and syn.request) or http_request or request
if not Request then warn("❌ Executor tidak mendukung HTTP Request") return end

local LastAmounts = {}
local PendingGain = {}
local Sending = false
local ScanQueued = false
local StartTime = os.time()

local HourlyGear = {}
local HourlyPet = {}
local HourlySeed = {}
local HourlyOther = {}
local HourlyTotal = 0
local LastCrateMoney = nil

local function GetUptime()
    local e = os.time() - StartTime
    local h = math.floor(e / 3600)
    local m = math.floor((e % 3600) / 60)
    local s = e % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function GetWIB()
    local u = DateTime.now():ToUniversalTime()
    return string.format("%02d:%02d WIB", (u.Hour + 7) % 24, u.Minute)
end

local function GetCrateMoney()
    local map = workspace:FindFirstChild("Map")
    if not map then return "N/A" end
    local plots = map:FindFirstChild("Plots")
    if not plots then return "N/A" end
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("OwnerSign")
        if sign then
            for _, v in ipairs(sign:GetDescendants()) do
                if (v:IsA("TextLabel") or v:IsA("TextBox")) and v.Text == Player.Name then
                    local cui = plot:FindFirstChild("CashUIPosition")
                    local cashui = cui and cui:FindFirstChild("CashUI")
                    local main = cashui and cashui:FindFirstChild("Main")
                    local amt = main and main:FindFirstChild("AmountTxt")
                    if amt then return amt.Text end
                end
            end
        end
    end
    return "N/A"
end

local function GetCashPerMin()
    local lb = workspace:FindFirstChild("Leaderboards")
    if not lb then return "N/A" end
    local cl = lb:FindFirstChild("CashLeaderboard")
    if not cl then return "N/A" end
    local part = cl:FindFirstChild("PlayerPart")
    if not part then return "N/A" end
    local sg = part:FindFirstChild("SurfaceGui")
    if not sg then return "N/A" end
    local frame = sg:FindFirstChild("Frame")
    if not frame then return "N/A" end
    local tmpl = frame:FindFirstChild("CashTemplate")
    if not tmpl then return "N/A" end
    local tl = tmpl:FindFirstChild("TextLabel2")
    if tl then return tl.Text end
    return "N/A"
end

local function GetPlayerMoney()
    local pg = Player:FindFirstChild("PlayerGui")
    if not pg then return "N/A" end
    local mui = pg:FindFirstChild("MainUI")
    if not mui then return "N/A" end
    local mc = mui:FindFirstChild("MoneyCounter")
    if not mc then return "N/A" end
    local cc = mc:FindFirstChild("CashCounter")
    if cc then return cc.Text end
    return "N/A"
end

local function EstPerHour(cashPerMin)
    local num, suffix = cashPerMin:match("([%d%.]+)([A-Za-z]*)/min")
    if not num then return "N/A" end
    local mult = {
        k=1e3, m=1e6, b=1e9, t=1e12,
        qa=1e15, qn=1e18, sx=1e21, sp=1e24,
        oc=1e27, no=1e30
    }
    local val = tonumber(num) * (mult[suffix and suffix:lower()] or 1) * 60
    if val >= 1e30 then return string.format("$%.2fNo/hr", val/1e30)
    elseif val >= 1e27 then return string.format("$%.2fOc/hr", val/1e27)
    elseif val >= 1e24 then return string.format("$%.2fSp/hr", val/1e24)
    elseif val >= 1e21 then return string.format("$%.2fSx/hr", val/1e21)
    elseif val >= 1e18 then return string.format("$%.2fQn/hr", val/1e18)
    elseif val >= 1e15 then return string.format("$%.2fQa/hr", val/1e15)
    elseif val >= 1e12 then return string.format("$%.2fT/hr", val/1e12)
    elseif val >= 1e9 then return string.format("$%.2fB/hr", val/1e9)
    elseif val >= 1e6 then return string.format("$%.2fM/hr", val/1e6)
    else return string.format("$%.0f/hr", val) end
end

local function GetEmoji(name)
    local lower = name:lower()
    if lower:find("mammoth") then return "<:Mammoth:1514891081509113946>"
    elseif lower:find("hydra") then return "<:Hydra:1514891118180044821>"
    elseif lower:find("rainbow spray") then return "<:Rainbow:1514892436747321394>"
    elseif lower:find("cosmic spray") then return "<:Cosmic:1514892463695859812>"
    elseif lower:find("bubblegum spray") then return "<:Bubblegum:1514892495920824320>"
    elseif lower:find("fire spray") then return "<:Fire:1514892546466381906>"
    elseif lower:find("aurora lotus") then return "<:AuroraLotus:1514892142844055592>"
    elseif lower:find("ember fruit") then return "<:EmberFruit:1514892113010098316>"
    elseif lower:find("seed") then return "🌱"
    elseif lower:find("fertilizer") then return "🧪"
    elseif lower:find("pet treat") or lower:find("treat") then return "🦴"
    elseif lower:find("spray") then return "💨"
    elseif lower:find("time skip") then return "⏩"
    elseif lower:find("lvl") then return "🐾"
    else return "📦" end
end

local function ParseItem(itemName)
    local name, amount = itemName:match("^(.-)%s*%[x(%d+)%]")
    if name and amount then
        local lvl = itemName:match("%[Lvl:%s*(%d+)%]")
        local cleanName = name:match("^%s*(.-)%s*$")
        if lvl and lvl ~= "1" then cleanName = cleanName .. " ✨Lv." .. lvl end
        return cleanName, tonumber(amount)
    end
    name, amount = itemName:match("^(.-)%s*%(x(%d+)%)$")
    if name and amount then return name:match("^%s*(.-)%s*$"), tonumber(amount) end
    return itemName, 1
end

local function GetAllItems()
    local Current = {}
    local function ProcessTool(tool)
        if not tool:IsA("Tool") then return end
        local petName, lvl = tool.Name:match("^(.-)%s*%(lvl%s*(%d+)%)$")
        if petName then
            local key = petName:match("^%s*(.-)%s*$") .. " (lvl " .. lvl .. ")"
            Current[key] = (Current[key] or 0) + 1
        else
            local name, amount = ParseItem(tool.Name)
            Current[name] = (Current[name] or 0) + amount
        end
    end
    for _, tool in ipairs(Backpack:GetChildren()) do ProcessTool(tool) end
    local char = Player.Character
    if char then for _, tool in ipairs(char:GetChildren()) do ProcessTool(tool) end end
    return Current
end

local function SendRareAlert(itemName, amount)
    local lower = itemName:lower()
    local mention = nil
    for keyword, role in pairs(RARE_ITEMS) do
        if lower:find(keyword) then mention = role break end
    end
    if not mention then return end
    pcall(function()
        Request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                content = mention,
                embeds = {{
                    title = "🌟  Rare Item Obtained!",
                    description = string.format("%s **%s** `+%d`\n\n`👤 %s  •  🕐 %s`", GetEmoji(itemName), itemName, amount, Player.Name, GetWIB()),
                    color = 16711930,
                    footer = { text = "⏱ Uptime: " .. GetUptime() .. "  •  Build A Ring Farm" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            })
        })
    end)
end

local function SendHourlyReport()
    local crate = GetCrateMoney()
    local cashMin = GetCashPerMin()
    local playerMoney = GetPlayerMoney()
    local estHour = EstPerHour(cashMin)

    local crateChange = ""
    if LastCrateMoney and LastCrateMoney ~= "N/A" and crate ~= "N/A" then
        crateChange = "\n📈 Dari sejam lalu: `" .. LastCrateMoney .. "` → `" .. crate .. "`"
    end
    LastCrateMoney = crate

    local gearLines, petLines, seedLines, otherLines = {}, {}, {}, {}
    for item, amt in pairs(HourlyGear) do table.insert(gearLines, GetEmoji(item).." **"..item.."** `"..amt.."x`") end
    for item, amt in pairs(HourlyPet) do table.insert(petLines, GetEmoji(item).." **"..item.."** `"..amt.."x`") end
    for item, amt in pairs(HourlySeed) do table.insert(seedLines, GetEmoji(item).." **"..item.."** `"..amt.."x`") end
    for item, amt in pairs(HourlyOther) do table.insert(otherLines, GetEmoji(item).." **"..item.."** `"..amt.."x`") end

    local sections = {}
    table.insert(sections, "**👤 Player:** "..Player.Name.."  •  ⏱ `"..GetUptime().."`  •  🕐 `"..GetWIB().."`")
    table.insert(sections, "")
    table.insert(sections, "**💵 Saldo Player:** `"..playerMoney.."`")
    table.insert(sections, "**💰 Crate:** `"..crate.."`"..crateChange)
    table.insert(sections, "**⚡ Cash/min:** `"..cashMin.."`  •  **💵 Est/jam:** `"..estHour.."`")
    table.insert(sections, "**📦 Total Item:** `"..HourlyTotal.." item`")
    if #gearLines > 0 then table.insert(sections, "\n⚙️ __**Gear**__\n"..table.concat(gearLines, "\n")) end
    if #petLines > 0 then table.insert(sections, "\n🐾 __**Pet**__\n"..table.concat(petLines, "\n")) end
    if #seedLines > 0 then table.insert(sections, "\n🌱 __**Seeds**__\n"..table.concat(seedLines, "\n")) end
    if #otherLines > 0 then table.insert(sections, "\n📦 __**Others**__\n"..table.concat(otherLines, "\n")) end
    if #gearLines == 0 and #petLines == 0 and #seedLines == 0 and #otherLines == 0 then
        table.insert(sections, "\n_Tidak ada item masuk selama 1 jam terakhir._")
    end

    pcall(function()
        Request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                embeds = {{
                    title = "📊  Laporan 1 Jam — Build A Ring Farm",
                    description = table.concat(sections, "\n"),
                    color = 16750592,
                    footer = { text = "Build A Ring Farm Logger" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            })
        })
    end)

    HourlyGear = {}
    HourlyPet = {}
    HourlySeed = {}
    HourlyOther = {}
    HourlyTotal = 0
end

local function SendDisconnectAlert()
    pcall(function()
        Request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                embeds = {{
                    title = "🔴  Monitoring Berhenti!",
                    description = table.concat({
                        "**👤 Player:** "..Player.Name,
                        "**⚠️ Alasan:** Player Disconnect / Game Closed",
                        "",
                        "**📊 Statistik Terakhir:**",
                        "⏱ Uptime: `"..GetUptime().."`",
                        "💵 Saldo: `"..GetPlayerMoney().."`",
                        "💰 Crate: `"..GetCrateMoney().."`",
                        "📦 Total Item: `"..HourlyTotal.." item`",
                        "🕐 Waktu: `"..GetWIB().."`",
                    }, "\n"),
                    color = 15158332,
                    footer = { text = "Build A Ring Farm Logger" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            })
        })
    end)
    _G.BARFWebhookRunning = false
end

local function FlushWebhook()
    if next(PendingGain) == nil then Sending = false return end
    local seeds, pets, gears, others = {}, {}, {}, {}
    for item, amount in pairs(PendingGain) do
        local lower = item:lower()
        local line = string.format("%s **%s** `+%d`", GetEmoji(item), item, amount)
        if lower:find("seed") then table.insert(seeds, line)
        elseif lower:find("lvl") or lower:find("mammoth") or lower:find("hydra") then table.insert(pets, line)
        elseif lower:find("spray") or lower:find("treat") or lower:find("fertilizer") then table.insert(gears, line)
        else table.insert(others, line) end
    end
    table.sort(seeds); table.sort(pets); table.sort(gears); table.sort(others)
    local sections = {}
    if #seeds > 0 then table.insert(sections, "🌱 __**Seeds Items**__\n"..table.concat(seeds, "\n")) end
    if #pets > 0 then table.insert(sections, "🐾 __**Pet Items**__\n"..table.concat(pets, "\n")) end
    if #gears > 0 then table.insert(sections, "⚙️ __**Gear Items**__\n"..table.concat(gears, "\n")) end
    if #others > 0 then table.insert(sections, "📦 __**Other Items**__\n"..table.concat(others, "\n")) end
    pcall(function()
        Request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                embeds = {{
                    title = "🌾  Build A Ring Farm  🌾",
                    description = table.concat(sections, "\n\n"),
                    color = 5763719,
                    footer = { text = "👤 "..Player.Name.."  •  ⏱ "..GetUptime().."  •  🕐 "..GetWIB().."  •  Build A Ring Farm" },
                    timestamp = DateTime.now():ToIsoDate()
                }}
            })
        })
    end)
    PendingGain = {}
    Sending = false
end

local function QueueItem(name, amount)
    local lower = name:lower()
    PendingGain[name] = (PendingGain[name] or 0) + amount
    HourlyTotal = HourlyTotal + amount
    if lower:find("seed") then HourlySeed[name] = (HourlySeed[name] or 0) + amount
    elseif lower:find("lvl") or lower:find("mammoth") or lower:find("hydra") then HourlyPet[name] = (HourlyPet[name] or 0) + amount
    elseif lower:find("spray") or lower:find("treat") or lower:find("fertilizer") then HourlyGear[name] = (HourlyGear[name] or 0) + amount
    else HourlyOther[name] = (HourlyOther[name] or 0) + amount end
    SendRareAlert(name, amount)
    if Sending then return end
    Sending = true
    task.delay(2, FlushWebhook)
end

local function ScanInventory()
    ScanQueued = false
    local Current = GetAllItems()
    for name, amount in pairs(Current) do
        local old = LastAmounts[name] or 0
        if amount > old then QueueItem(name, amount - old) end
        LastAmounts[name] = amount
    end
end

local function QueueScan()
    if ScanQueued then return end
    ScanQueued = true
    task.delay(0.3, ScanInventory)
end

task.spawn(function()
    while task.wait(3600) do SendHourlyReport() end
end)



local initItems = GetAllItems()
for name, amount in pairs(initItems) do LastAmounts[name] = amount end
LastCrateMoney = GetCrateMoney()

pcall(function()
    Request({
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = HttpService:JSONEncode({
            embeds = {{
                title = "🟢  Webhook Activated",
                description = table.concat({
                    "```",
                    "👤 Player  : " .. Player.Name,
                    "🎮 Game    : Build A Ring Farm",
                    "🕐 Time    : " .. GetWIB(),
                    "💰 Crate   : " .. GetCrateMoney(),
                    "⚡ Cash/min: " .. GetCashPerMin(),
                    "💵 Saldo   : " .. GetPlayerMoney(),
                    "🛡 Status  : Monitoring Started",
                    "```"
                }, "\n"),
                color = 3066993,
                footer = { text = "Build A Ring Farm Logger" },
                timestamp = DateTime.now():ToIsoDate()
            }}
        })
    })
end)

Backpack.ChildAdded:Connect(QueueScan)
Backpack.ChildRemoved:Connect(QueueScan)

local function ConnectCharacter(char)
    char.ChildAdded:Connect(QueueScan)
    char.ChildRemoved:Connect(QueueScan)
end

if Player.Character then ConnectCharacter(Player.Character) end
Player.CharacterAdded:Connect(ConnectCharacter)

task.spawn(function()
    while task.wait(2) do ScanInventory() end
end)

print("✅ Build A Ring Farm Webhook Started | © Coky")
