--[[ BiSGamba :: DeckApp.lua - GAMBA ON THE PHONE (22 Nov 2026).

  Arn, 22 Nov: "start gamba" - the picks off the mock (https://claude.ai/artifact/HZHvD2uqp3iG6bpPQTwREu): "phone and room".
  The phone is BiSTheme's deck (it comes with BiS Tools): an app hands in DATA, never a frame. Without it nothing here runs.
  Everything here is a click the window already has - Game.JoinMe / RollMe / Open / LastCall / End, Trade.Pay, the
  deathroll window - and the books are only read. NOTHING HERE EVER MOVES GOLD: PAY opens the trade, the gold is yours to put in.

   TABLE     the round now: who sits, what they rolled, the next thing to press as the big button; TABLE opens the 3D room
   BOARD     the leaderboard (your scope), each name opens to its page: net, won, lost, what they owe you or you them
   DEBTS     what is owed to you and what you owe; PAY opens the trade with them
   SETTINGS  the options window's own switches, and the door to the window

  THE CARD: a table opens and you are not at it (JOIN / NOT NOW, hot), your roll (ROLL, hottest), seated (LEAVE), and you owe
  somebody (PAY). The window's own Refresh tells the phone to repaint - nothing ticks here except the last call's seconds.
]]
local ADDON, ns = ...
local A = {}
local G                                      -- BiSGamba, at login
local ID = ADDON .. ":gamba"

local function plain(v)
    if v == nil then return nil end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return nil end
    end
    return v
end
local function ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return plain(a), plain(b) end
end
local function Deck()
    local T = _G.BiSTheme
    return type(T) == "table" and T.Deck or nil
end
local function db() return G and G.db or {} end
local function me() return G and G.Kit and G.Kit.MyName() or "" end
local function gold(n) return G and G.Kit and G.Kit.Gold(tonumber(n) or 0) or (tostring(n) .. "g") end
local function cap(s) s = tostring(s or "") return s:sub(1, 1):upper() .. s:sub(2):lower() end
local function signed(n) n = tonumber(n) or 0 return (n > 0 and "+" or "") .. gold(n) end
local function grouped() return ask(IsInGroup) and true or false end

local pick                                   -- a name's page: { name = }
local notNow                                 -- the table you said NOT NOW to (its host and when it opened)

local function game() return G and G.Game or nil end
--- This table's mark, so NOT NOW holds for it only.
local function tableMark()
    local g = game()
    return g and g.host and (tostring(g.host) .. "|" .. tostring(g.max) .. "|" .. tostring(#(g.order or {}) > 0 and g.order[1] or "")) or nil
end
local function seated() local g = game() return g and g.players and g.players[me()] ~= nil or false end
local function owes() return G and G.Ledger and G.Ledger.Owes(me()) or {} end
local function owed() return G and G.Ledger and G.Ledger.OwedTo(me()) or {} end
local function stat(name) local s = db().stats return type(s) == "table" and type(s[name]) == "table" and s[name] or {} end

-- THE TABLE -------------------------------------------------------------------------------------------------------------------

local STATE_WORD = { IDLE = "NONE", JOIN = "OPEN", ROLL = "ROLLING", TIE = "TIE", DONE = "DONE" }
local function tableBoxes()
    local g = game()
    if not g then return {} end
    local cd = g.Countdown and g.Countdown()
    local out = { { "TABLE", STATE_WORD[g.state] or g.state, g.state == "JOIN" and "good" or g.state == "ROLL" and "gold" or "ink2" },
        { "SEATS", #(g.order or {}) }, { "ROLL", "1-" .. tostring(g.max or 100) } }
    if cd then out[#out + 1] = { "CLOSES", math.ceil(cd) .. "s", "warn" } end
    return out
end
local function tableRows()
    local g = game()
    local out = {}
    if not g or g.state == "IDLE" then return out end
    if g.host then out[#out + 1] = { head = true, text = (g.team and "TEAM ROLL" or "HIGH / LOW") .. " - " .. tostring(g.host) .. "'s table", right = "" } end
    local res = g.result
    for i, name in ipairs(g.order or {}) do
        local p = g.players[name] or {}
        local roll = p.tieRoll or p.roll
        local ink = (res and name == res.winner and "good") or (res and name == res.loser and "warn") or (name == me() and "accent") or nil
        local right = roll and tostring(roll) or (g.state == "JOIN" and "in" or "rolling")
        out[#out + 1] = { mark = tostring(i), text = name, right = right, ink = ink, act = { word = "open", peek = true, fn = function() pick = { name = name } end } }
    end
    if res and res.winner and res.loser then
        out[#out + 1] = { head = true, text = res.loser .. " pays " .. res.winner, right = gold(res.amount) }
    end
    return out
end
--- The next thing to press, as the big button.
function A.Big()
    local g = game()
    if not g then return nil end
    local K = G.Kit
    if g.CanRoll() then return { word = "ROLL 1-" .. tostring(g.max), fn = function() g.RollMe() end } end
    if g.state == "JOIN" then
        if g.IsHost() then
            if seated() and #(g.order or {}) >= 2 then return { word = "CALL THE ROLLS", fn = function() g.StartRolls() end } end
        end
        if not seated() then return { word = "JOIN", tip = "Types 1 in group chat: you're in this round", fn = function() g.JoinMe() end } end
        return nil
    end
    if not g.Active() then
        local o = owes()[1]
        if o and K.InGroup(o.to) then return { word = "PAY " .. tostring(o.to), tip = "Opens a trade and puts " .. gold(o.amount) .. " in: you press Trade", fn = function() G.Trade.Pay(o.to) end } end
        if grouped() and not g.Remote() then
            return { word = "OPEN A TABLE", tip = "Posts the table in group chat: /roll " .. tostring(db().wager or 100), fn = function() g.Open(db().wager) end }
        end
    end
    return nil
end
local function tableKeys()
    local g = game()
    local out = { { word = "3D ROOM", peek = true, tip = "Everyone around the table, in 3D", fn = function()
        db().view = "table"
        G.UI:Show()
        G.UI:Refresh()
    end } }
    if not g then return out end
    if g.state == "JOIN" and seated() and not g.IsHost() then out[#out + 1] = { word = "LEAVE", tip = "Types -1 in group chat", fn = function() g.JoinMe() end } end
    if g.IsHost() and g.state == "JOIN" then
        out[#out + 1] = { word = "LAST CALL", tip = "Ten seconds' warning in chat, then the rolls start", fn = function() g.LastCall() end }
        out[#out + 1] = { word = "END", tip = "Close the table", fn = function() g.End() end }
    elseif g.IsHost() and (g.state == "ROLL" or g.state == "TIE") then
        out[#out + 1] = { word = "SETTLE", tip = "Settle now with the rolls that are in", fn = function() g.End() end }
    end
    return out
end
local function tableSay()
    local g = game()
    if not g or g.state == "IDLE" then return nil end
    if g.state == "JOIN" then return "Lowest pays the highest, up to " .. gold(g.max) end
    if g.state == "ROLL" then local m = g.Missing and g.Missing() or {} return #m > 0 and ("Waiting on " .. table.concat(m, ", ")) or "Everyone rolled" end
    if g.state == "TIE" then return "A tie: the tied roll again" end
    return nil
end

-- THE BOARD, AND A NAME'S PAGE ------------------------------------------------------------------------------------------------

local function boardRows()
    local out = {}
    for i, row in ipairs(G and G.Board() or {}) do
        local net = tonumber(row.r.net) or 0
        out[#out + 1] = { mark = tostring(i), text = row.name, right = signed(net), ink = net > 0 and "good" or net < 0 and "warn" or nil,
            act = { word = "open", peek = true, fn = function() pick = { name = row.name } end } }
    end
    return out
end
local function boardBoxes()
    local s = stat(me())
    local kind, len = G.Streak(me())
    return { { "YOU", signed(s.net), (tonumber(s.net) or 0) >= 0 and "gold" or "warn" },
        { "STREAK", len and len > 1 and (len .. (kind == "win" and " won" or " lost")) or "-", kind == "win" and "good" or kind == "lose" and "warn" or "dim" },
        { "ROUNDS", tonumber(s.games) or 0 } }
end
local function nameBoxes(name)
    local s = stat(name)
    return { { "NET", signed(s.net), (tonumber(s.net) or 0) >= 0 and "good" or "warn" }, { "WON", tonumber(s.wins) or 0 }, { "LOST", tonumber(s.losses) or 0, "warn" },
        { "WORST", s.worst and gold(s.worst) or "-", "dim" } }
end
local function nameRows(name)
    local out = { { mark = "<", text = "Back", act = { word = "back", peek = true, fn = function() pick = nil end } } }
    local kind, len = G.Streak(name)
    if len and len > 1 then out[#out + 1] = { text = "Streak", right = len .. (kind == "win" and " won" or " lost"), ink = kind == "win" and "good" or "warn" } end
    local s = stat(name)
    if s.best then out[#out + 1] = { text = "Biggest win", right = gold(s.best), ink = "good" } end
    for _, d in ipairs(owed()) do if d.from == name then out[#out + 1] = { text = name .. " owes you", right = gold(d.amount), ink = "good" } end end
    for _, d in ipairs(owes()) do
        if d.to == name then out[#out + 1] = { text = "You owe " .. name, right = gold(d.amount), ink = "warn", act = { word = "PAY", fn = function() G.Trade.Pay(name) end }, verb = "PAY" } end
    end
    return out
end
local function nameBig(name)
    if name == me() or not G.Deathroll then return nil end
    return { word = "DEATHROLL", peek = true, tip = "The deathroll window, with " .. name .. " in it", fn = function() G.Deathroll.Show(name) end }
end

-- THE DEBTS -------------------------------------------------------------------------------------------------------------------

local function sum(list) local n = 0 for _, d in ipairs(list) do n = n + (tonumber(d.amount) or 0) end return n end
local function debtBoxes()
    local a, b = owed(), owes()
    return { { "OWED TO YOU", gold(sum(a)), "good" }, { "YOU OWE", gold(sum(b)), sum(b) > 0 and "warn" or "dim" }, { "OPEN", #a + #b } }
end
local function debtRows()
    local out = {}
    for _, d in ipairs(owed()) do out[#out + 1] = { text = tostring(d.from) .. " owes you", right = gold(d.amount), ink = "good", act = { word = "open", peek = true, fn = function() pick = { name = d.from } end } } end
    for _, d in ipairs(owes()) do
        out[#out + 1] = { text = "You owe " .. tostring(d.to), right = gold(d.amount), ink = "warn", verb = "PAY",
            tip = "Opens a trade with " .. tostring(d.to) .. " and puts the gold in: you press Trade", act = { word = "PAY", fn = function() G.Trade.Pay(d.to) end } }
    end
    return out
end

-- THE SETTINGS ----------------------------------------------------------------------------------------------------------------

local function settingRows()
    local out = {}
    for _, sec in ipairs(G.UI:Sections()) do
        for _, opt in ipairs(sec.rows or {}) do
            if opt and opt.kind == "toggle" then
                local is = opt.get(db()) and true or false
                out[#out + 1] = { text = cap(opt.label), right = is and "ON" or "OFF", ink = is and "good" or "dim", tip = opt.help,
                    act = { word = "switch", chip = true, fn = function()
                        opt.set(db(), not opt.get(db()))
                        if G.UI.opt and G.UI.opt:IsShown() and G.UI.opt.Paint then G.UI.opt:Paint() end
                    end } }
            end
        end
    end
    out[#out + 1] = { head = true, text = "THE WINDOWS", right = "" }
    out[#out + 1] = { text = "Every setting", act = { word = "OPEN", peek = true, fn = function() G.UI:OpenConfig() end }, verb = "OPEN" }
    out[#out + 1] = { text = "The table window", act = { word = "OPEN", peek = true, fn = function() G.UI:Show() end }, verb = "OPEN" }
    return out
end

-- THE CARD --------------------------------------------------------------------------------------------------------------------

--- What the card says now: "roll" | "join" | "in" | "owe" | nil.
function A.CardKind()
    local g = game()
    if not g then return nil end
    if g.CanRoll() then return "roll" end
    if g.state == "JOIN" and not seated() and tableMark() ~= notNow then return "join" end
    if g.state == "JOIN" and seated() then return "in" end
    local o = owes()[1]
    if o and not g.Active() and G.Kit.InGroup(o.to) then return "owe" end
    return nil
end
function A.CardPrio(out)
    local k = A.CardKind()
    if k == "roll" then return 9 elseif k == "join" then return 8 elseif k == "in" then return 5 elseif k == "owe" then return 4 end
    return out and 1 or nil
end
function A.CardLines()
    local g, k = game(), A.CardKind()
    if not g then return nil end
    local cd = g.Countdown and g.Countdown()
    local list = { { "At the table", tostring(#(g.order or {})) } }
    if cd then list[#list + 1] = { "Closes", math.ceil(cd) .. "s" } end
    if k == "roll" then return { "GAMBA", "", "Your roll", "1-" .. tostring(g.max), "gold", hot = true, list = list } end
    if k == "join" then return { "GAMBA", "", tostring(g.host) .. " opened a table", gold(g.max), "gold", hot = true, list = list } end
    if k == "in" then return { "GAMBA", "", "You are at the table", gold(g.max), "good", list = list } end
    if k == "owe" then local o = owes()[1] return { "GAMBA", "", "You owe " .. tostring(o.to), gold(o.amount), "warn", list = { { "Standing near", "yes" } } } end
    local s = stat(me())
    return { "GAMBA", "", "No table", signed(s.net), "ink2", list = {} }
end
function A.CardButtons()
    local g, k = game(), A.CardKind()
    if not g then return {} end
    if k == "roll" then return { { word = "ROLL", fn = function() g.RollMe() end } } end
    if k == "join" then
        return { { word = "JOIN", fn = function() g.JoinMe() end }, { word = "NOT NOW", peek = true, fn = function() notNow = tableMark() end } }
    end
    if k == "in" and not g.IsHost() then return { { word = "LEAVE", fn = function() g.JoinMe() end } } end
    if k == "owe" then local o = owes()[1] return { { word = "PAY", fn = function() G.Trade.Pay(o.to) end } } end
    return { { word = "OPEN", peek = true, fn = function() local D = Deck() if D then D.Open(ID) end end } }
end

-- REGISTER --------------------------------------------------------------------------------------------------------------------

local TABS = { "TABLE", "BOARD", "DEBTS", "SETTINGS" }
function A.Register()
    local D = Deck()
    G = _G.BiSGamba
    if A.handle or not (D and D.Register) or type(G) ~= "table" or not G.Game then return false end
    A.handle = D.Register{
        owner = ADDON, key = "gamba", name = "Gamba", icon = "Ga", order = 40,
        about = "High / low and deathrolls with your group: the table, the board, who owes whom.",
        badge = function() local k = A.CardKind() return (k == "roll" or k == "join") and 1 or nil end,
        card = { tick = true, prio = A.CardPrio, lines = A.CardLines, buttons = A.CardButtons },
        page = {
            tick = true,
            tour = { { text = "TABLE is the round now: the big button is always the next thing to press.", note = "3D ROOM opens everyone around the table." },
                { text = "Nothing here moves gold. PAY opens the trade; you press Trade." } },
            title = function() return pick and pick.name or "Gamba" end,
            kicker = function()
                local g = game()
                if pick then return "a player" end
                return g and g.Active() and (tostring(g.host) .. "'s table") or "high / low"
            end,
            tabs = function() return TABS end,
            boxes = function(tab)
                if pick then return nameBoxes(pick.name) end
                if tab == 1 then return tableBoxes() elseif tab == 2 then return boardBoxes() elseif tab == 3 then return debtBoxes() end
                return {}
            end,
            rows = function(tab)
                if pick then return nameRows(pick.name) end
                if tab == 1 then return tableRows() elseif tab == 2 then return boardRows() elseif tab == 3 then return debtRows() end
                return settingRows()
            end,
            text = function(tab)
                if pick then return nil end
                if tab == 1 and #tableRows() == 0 then return grouped() and "No table open. OPEN A TABLE posts one in group chat." or "No table open. Join a group to play." end
                if tab == 2 and #boardRows() == 0 then return "No rounds yet." end
                if tab == 3 and #debtRows() == 0 then return "Nobody owes anybody." end
                return nil
            end,
            say = function(tab) if not pick and tab == 1 then return tableSay() end end,
            big = function(tab)
                if pick then return nameBig(pick.name) end
                if tab == 1 then return A.Big() end
                return nil
            end,
            keys = function(tab)
                if pick then return {} end
                if tab == 1 then return tableKeys() end
                if tab == 2 and G.Deathroll then return { { word = "DEATHROLL", peek = true, fn = function() G.Deathroll.Toggle() end } } end
                return {}
            end,
        },
    }
    -- the window's own Refresh runs at every change of the round: the phone repaints with it
    local UI = G.UI
    if UI and type(UI.Refresh) == "function" and not UI.bisDeckHooked then
        local old = UI.Refresh
        UI.Refresh = function(self, ...)
            local r = old(self, ...)
            if A.handle and A.handle.Dirty then pcall(A.handle.Dirty, A.handle) end
            return r
        end
        UI.bisDeckHooked = true
    end
    return true
end
A.ID = ID
A.Pick = function(name) pick = name and { name = name } or nil end
if type(_G.BiSGamba) == "table" then _G.BiSGamba.DeckApp = A end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() A.Register() end)
A.boot = ev
