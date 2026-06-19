if _G.ShopMonitorRunning then warn("⚠️ Shop Monitor sudah berjalan!") return end
_G.ShopMonitorRunning=true

local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local Player=Players.LocalPlayer
local WEBHOOK="https://discord.com/api/webhooks/1514898766040137779/WqgxA1O9VZX7qxtmY3hfMsbHCjCZuVKmWuiBND2DZzup8S84ZfpvcMqeMP1VlA0PhXtW"
local ROLE="1514999345819291648"
local Req=(syn and syn.request) or http_request or request
if not Req then warn("❌ No HTTP support") return end

local ITEM_TAGS={
	["EpicEgg"]         ="<@&1515089277443244042>",
	["Fire Spray"]      ="<@&1515088881140109453>",
	["Bubblegum Spray"] ="<@&1515089097314537522>",
	["Rainbow Spray"]   ="<@&1515088969455636572>",
	["Cosmic Spray"]   ="<@&1515091681324564480>",
	["LegendaryEgg"]   ="<@&1515395549191475310>"
}

local PG=Player:WaitForChild("PlayerGui")
local GS=PG:WaitForChild("MainUI"):WaitForChild("Menus"):WaitForChild("GearShopFrame")
local SF=GS:WaitForChild("ScrollingFrame")
local RT=GS:WaitForChild("RestockTimer")
local EGG_EMOJI={CommonEgg="<:Common:1514990825715798136>",RareEgg="<:rare:1514990743436136550>",EpicEgg="<:epic:1514990936675848273>",LegendaryEgg="<:Legendary:1515432727069851811>"}
local START=os.time()
local RestockCount=0

local function uptime()
	local e=os.time()-START
	local h,m,s=math.floor(e/3600),math.floor((e%3600)/60),e%60
	if h>0 then return h.."h "..m.."m "..s.."s"
	elseif m>0 then return m.."m "..s.."s"
	else return s.."s" end
end

local function wib()
	local u=DateTime.now():ToUniversalTime()
	return string.format("%02d:%02d WIB",(u.Hour+7)%24,u.Minute)
end

local function ts()
	local u=DateTime.now():ToUniversalTime()
	return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ",u.Year,u.Month,u.Day,u.Hour,u.Minute,u.Second)
end

local function getNextRestock()
	return RT.Text or "N/A"
end

local function scanGear()
	local t={}
	for _,i in ipairs(SF:GetChildren()) do
		if i:IsA("ImageLabel") and i.Name~="ComingSoon" and i.Name~="UIListLayout" and i.Name~="UIPadding" then
			local n,c=i:FindFirstChild("GearName"),i:FindFirstChild("Cost")
			if n and c then
				local s=0
				for _,ch in ipairs(i:GetDescendants()) do
					if ch:IsA("TextLabel") or ch:IsA("TextButton") or ch:IsA("TextBox") then
						local x=ch.Text or ""
						local v=tonumber(x:match("[Ss]tock:?%s*(%d+)")) or tonumber(x:match("(%d+)%s+[Ll]eft")) or (ch.Name:lower():find("stock") and tonumber(x:match("(%d+)")))
						if v then s=v break end
					end
				end
				table.insert(t,{name=n.Text,stock=s,cost=c.Text or "?"})
			end
		end
	end
	return t
end

local EGG_WHITELIST={
	["CommonEgg"]=true,
	["RareEgg"]=true,
	["EpicEgg"]=true,
	["LegendaryEgg"]=true,
}

local function scanEggs()
	local t={}
	for _,v in ipairs(workspace:GetChildren()) do
		if EGG_WHITELIST[v.Name] then
			t[v.Name]=(t[v.Name] or 0)+1
		end
	end
	return t
end

local function getItemTags(items,eggCounts)
	local tags={}
	for _,i in ipairs(items) do
		if i.stock>0 and ITEM_TAGS[i.name] then
			table.insert(tags,ITEM_TAGS[i.name])
		end
	end
	for e,c in pairs(eggCounts) do
		if c>0 and ITEM_TAGS[e] then
			table.insert(tags,ITEM_TAGS[e])
		end
	end
	local seen,result={},{}
	for _,t in ipairs(tags) do
		if not seen[t] then seen[t]=true table.insert(result,t) end
	end
	return table.concat(result," ")
end

local function buildGear(items)
	local g={{l="🌿 __Fertilizers__",k="fertilizer",t={}},{l="💧 __Sprays__",k="spray",t={}},{l="🦴 __Pet Treats__",k="treat",t={}},{l="📦 __Others__",k="other",t={}}}
	local inn,out=0,0
	for _,i in ipairs(items) do
		local lo=i.name:lower()
		if i.stock>0 then
			local ln="🟢 **"..i.name.."** `"..i.stock.."` 💰 `"..i.cost.."`"
			inn=inn+1
			if lo:find("fertilizer") then table.insert(g[1].t,ln)
			elseif lo:find("spray") then table.insert(g[2].t,ln)
			elseif lo:find("treat") then table.insert(g[3].t,ln)
			else table.insert(g[4].t,ln) end
		else
			out=out+1
		end
	end
	local f={}
	local sum=""
	if inn>0 then sum=sum.."🟢 **"..inn.." In Stock**\n" end
	if out>0 then sum=sum.."🔴 **"..out.." Out of Stock**\n" end
	sum=sum.."⏰ Next Restock: `"..getNextRestock().."`"
	table.insert(f,{name="📊 Summary",value=sum,inline=false})
	table.insert(f,{name="​",value="​",inline=false})
	for _,gr in ipairs(g) do
		if #gr.t>0 then table.insert(f,{name=gr.l,value=table.concat(gr.t,"\n"),inline=false}) end
	end
	if inn==0 then
		table.insert(f,{name="❌ No Items Available",value="Wait for the next restock!",inline=false})
	end
	return f,inn,out
end

local function buildEggs(counts)
	local f={}
	local sorted={}
	for e in pairs(counts) do table.insert(sorted,e) end
	table.sort(sorted)
	for _,e in ipairs(sorted) do
		local c=counts[e] or 0
		if c>0 then
			local em=EGG_EMOJI[e] or "🥚"
			local lb=e:gsub("Egg"," Egg")
			table.insert(f,{name=em.." __"..lb.."__",value="🟢 Stock: `"..c.."`\n✅ Ready",inline=true})
		end
	end
	if #f==0 then table.insert(f,{name="🥚 Egg Shop",value="❌ No eggs in stock.",inline=false}) end
	return f
end

local function getPing()
	local t0=os.clock()
	pcall(function()
		Req({Url=WEBHOOK.."?wait=true",Method="GET",Headers={["Content-Type"]="application/json"}})
	end)
	local ms=math.floor((os.clock()-t0)*1000)
	local label=ms<200 and "🟢 Fast" or ms<500 and "🟡 Normal" or "🔴 Slow"
	return label.." — `"..ms.."ms`"
end

local function buildStatus(isRestock)
	if isRestock then RestockCount=RestockCount+1 end
	local ping=getPing()
	return {
		{name="⏱️ Uptime",value="`"..uptime().."`",inline=true},
		{name="📡 Ping",value=ping,inline=true},
		{name="🔄 Restock Count",value="`#"..RestockCount.."` since monitor started",inline=false},
	}
end

local function send(isRestock)
	local gear=scanGear()
	local eggs=scanEggs()
	local gf,inn,out=buildGear(gear)
	local ef=buildEggs(eggs)
	local sf=buildStatus(isRestock)

	-- warna dinamis berdasarkan kondisi stok
	local color
	if inn==0 then
		color=15158332      -- merah: semua habis
	elseif out==0 then
		color=5763719       -- hijau: semua ada
	else
		color=16754176      -- orange: sebagian ada
	end

	local title
	if inn==0 then
		title="⚠️ All Items Out of Stock!"
	elseif isRestock then
		title="🔄 RESTOCK ALERT!"
	else
		title="🛒 Stock Update"
	end

	local foot={text="⏱️ "..uptime().." • 🕐 "..wib().." • © Coky • Build A Ring Farm"}
	local t=ts()
	local itemTags=getItemTags(gear,eggs)
	local mentionContent="<@&"..ROLE..">"
	if itemTags~="" then mentionContent=mentionContent.." "..itemTags end
	pcall(function()
		Req({Url=WEBHOOK.."?wait=true",Method="POST",Headers={["Content-Type"]="application/json"},
		Body=HttpService:JSONEncode({content=mentionContent,embeds={
			{title=title.." — Gear Shop",color=color,fields=gf,footer=foot,timestamp=t},
			{title=title.." — Egg Shop",color=color,fields=ef,footer=foot,timestamp=t},
			{title="📡 Webhook Status",color=3066993,fields=sf,footer=foot,timestamp=t},
		}})})
		print("📨 Webhook sent | "..uptime())
	end)
end

local state,last="IDLE",""
local function parseSecs(t)
	local m,s=t:match("(%d+):(%d+)")
	if m and s then return tonumber(m)*60+tonumber(s) end
end

RT:GetPropertyChangedSignal("Text"):Connect(function()
	local t=RT.Text
	if t==last then return end
	last=t
	local s=parseSecs(t)
	if state=="IDLE" then
		if s and s<=10 then state="NEAR_ZERO" end
	elseif state=="NEAR_ZERO" then
		if s and s>=60 then state="SENT" task.spawn(function() task.wait(2) send(true) task.wait(3) state="IDLE" end)
		elseif not s then state="WAITING_RESET" end
	elseif state=="WAITING_RESET" then
		if s and s>=30 then state="SENT" task.spawn(function() task.wait(2) send(true) task.wait(3) state="IDLE" end) end
	end
end)

send(false)
print("✅ Shop Monitor Started | © Coky")
