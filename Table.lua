--[[
  BiS Gamba :: Table.lua - THE TABLE: everyone at the round, standing in 3D around one round table.

  Arn, 20 Oct 2026: "Rethink the big gamba window with the table with 3d models moving, people with the
  addon can move them around and everyone sees we only read where they walk and we draw on our client and
  have them if they don't have the addon if they enter the game their 3d models still interact as if they
  are standing around gambling around a table. That window can still start small because of raids and I'm
  not opposed to the idea that people can full screen like our other survivor window with back drops".

  PHASE 1 (this file; plan in dev/TABLE.md): the third view, "table", beside 2d and 3d -
  - one round table, seen from your own place: every client turns the room so YOU stand at the front;
  - everyone at the round stands on a circle around it - by their real body when in range (SetUnit), their
    race's checked stand-in when not (BiSGamba.lua's ApplyModel), a wisp when nothing is known - so a player
    WITHOUT the addon is there like everybody else, rolling, cheering, crying, paying;
  - click the floor and you walk there (here only, for now - phase 2 tells the others where you went);
  - the pay walk crosses the room: the loser walks to the winner, wherever they stand, begs, walks back;
  - it opens small (raids); the square in the corner makes it big - on top of everything, a dark backdrop,
    never remembered, dropped in a fight;
  - `/bisgamba table demo [n]` seats pretend people to look at, and `/bisgamba table demo round` plays a
    pretend round with them - drawing only: no game, no message, no gold.
  Table space is 0..999 both ways, the table's middle at 500,500; y grows toward the viewer before the room
  is turned. Nothing ticks unless somebody walks.
]]
local G = BiSGamba
local K = G.Kit
local T = G.T

local Tb = { actors = {}, byName = {}, rot = 0 }
G.Table = Tb

Tb.SIZES = { { 10, 340 }, { 20, 420 }, { 999, 500 } }   -- up to n people: the stage's width (1.43:1)
Tb.R_TABLE, Tb.R_SEAT, Tb.R_FLOOR = 230, 330, 470       -- the table, where people stand, the room's edge
Tb.KX, Tb.KY, Tb.CY = 0.42, 0.28, 0.50                  -- table space -> the stage: across, deep, the middle
Tb.MODEL_W, Tb.MODEL_H = 44, 60                         -- a model at the front of the small stage
Tb.SPEED = 300                                          -- table units a second, walking
Tb.WALK = { delay = 1.4, gap = 0.5, beg = 1.6, short = 70 }   -- the pay walk (stops this far short)
Tb.BIG = 1.5                                            -- the big window: at most this much bigger
Tb.DEMO_NAMES = { "Grizzik", "Hazel", "Brakka", "Lune", "Odo", "Vex", "Morrigan", "Tibbs", "Kael", "Rhea",
  "Gorm", "Saffi", "Dunn", "Ivy", "Zug", "Pell", "Quill", "Rook", "Nyx", "Bram" }
Tb.DEMO_RACES = { "Orc", "Human", "Tauren", "NightElf", "Troll", "Dwarf", "Scourge", "Gnome" }

local function db() return K.DB() end

--------------------------------------------------------------------
-- the room
--------------------------------------------------------------------

--- Table space -> the stage: x across, y down from the stage's top, and depth (0 at the back, 1 at the front).
function Tb.ToStage(x, y)
  local dx, dy = x - 500, y - 500
  local c, s = math.cos(Tb.rot), math.sin(Tb.rot)
  local rx, ry = dx * c - dy * s, dx * s + dy * c
  return Tb.SW / 2 + rx * (Tb.SW * Tb.KX / 500), Tb.SH * Tb.CY + ry * (Tb.SH * Tb.KY / 500), (ry + 500) / 1000
end

--- The stage -> table space (a click on the floor).
function Tb.FromStage(sx, sy)
  local rx = (sx - Tb.SW / 2) / (Tb.SW * Tb.KX / 500)
  local ry = (sy - Tb.SH * Tb.CY) / (Tb.SH * Tb.KY / 500)
  local c, s = math.cos(-Tb.rot), math.sin(-Tb.rot)
  return 500 + rx * c - ry * s, 500 + rx * s + ry * c
end

--- Where the i-th of n stands: evenly round the table, the first at the front before the room turns.
function Tb.SeatSpot(i, n)
  local a = 2 * math.pi * (i - 1) / math.max(1, n)
  return 500 + Tb.R_SEAT * math.sin(a), 500 + Tb.R_SEAT * math.cos(a), a
end

--- The part of the stage a model's feet may stand on: a model's width in from the sides, its height down from
--- the top (so it is never cut off), a little up from the bottom.
function Tb.Floor()
  local k = Tb.k or 1
  return Tb.MODEL_W * 0.6 * k, Tb.MODEL_H * 0.9 * k, Tb.SW - Tb.MODEL_W * 0.6 * k, Tb.SH - 4 * k
end

--- A spot kept on the floor: off the table, inside the room.
--- TO THE EDGES (Arn, 21 Oct: "i can walk around it but not to the edges of the screen"): the room is the
--- whole stage you see, not a ring round the table (Tb.R_FLOOR is only the fallback before there is a stage).
function Tb.Clamp(x, y)
  if Tb.SW and Tb.SH then
    local sx, sy = Tb.ToStage(x, y)
    local l, t, r, b = Tb.Floor()
    x, y = Tb.FromStage(math.max(l, math.min(r, sx)), math.max(t, math.min(b, sy)))
  end
  local dx, dy = x - 500, y - 500
  local d = math.sqrt(dx * dx + dy * dy)
  if d < 1 then return 500, 500 + Tb.R_TABLE + 40 end
  local r = math.max(Tb.R_TABLE + 40, Tb.SW and d or math.min(Tb.R_FLOOR, d))
  return 500 + dx / d * r, 500 + dy / d * r
end

--- The way a model faces to look from (x0,y0) to (x1,y1), as seen in the turned room (0 faces you).
function Tb.Facing(x0, y0, x1, y1)
  local ax, ay = Tb.ToStage(x0, y0)
  local bx, by = Tb.ToStage(x1, y1)
  return math.atan2(bx - ax, by - ay)
end

local function disc(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")      -- the portraits' round mask: a disc
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

--- The stage, the table on it, and the floor you click: made once, inside the window's scene.
function Tb.Build(scene)
  if Tb.stage then return Tb.stage end
  local st = CreateFrame("Frame", nil, scene)
  Tb.stage = st
  local ground = st:CreateTexture(nil, "BACKGROUND")
  ground:SetColorTexture(0.05, 0.04, 0.035, 0.95)
  ground:SetAllPoints(st)
  Tb.lamp = st:CreateTexture(nil, "BORDER")
  Tb.lamp:SetTexture("Interface\\Cooldown\\star4")
  if Tb.lamp.SetBlendMode then pcall(Tb.lamp.SetBlendMode, Tb.lamp, "ADD") end
  Tb.lamp:SetVertexColor(1, 0.85, 0.55, 1)
  Tb.lamp:SetAlpha(0.28)
  -- the floor: a click walks you there
  local floor = CreateFrame("Button", nil, st)
  floor:SetAllPoints(st)
  floor:SetScript("OnClick", function() Tb.ClickFloor() end)
  Tb.floor = floor
  -- the table, between the people behind it and the people in front
  local tf = CreateFrame("Frame", nil, st)
  Tb.tableFrame = tf
  Tb.shadow = disc(tf, "BACKGROUND", 0, 0, 0, 0.55)
  Tb.rim = disc(tf, "BORDER", 0.33, 0.20, 0.10, 1)
  Tb.felt = disc(tf, "ARTWORK", 0.07, 0.30, 0.15, 1)
  Tb.shine = tf:CreateTexture(nil, "OVERLAY")
  Tb.shine:SetTexture("Interface\\Cooldown\\star4")
  if Tb.shine.SetBlendMode then pcall(Tb.shine.SetBlendMode, Tb.shine, "ADD") end
  Tb.shine:SetVertexColor(0.9, 0.75, 0.3, 1)
  Tb.shine:SetAlpha(0.18)
  Tb.pot = tf:CreateTexture(nil, "OVERLAY")
  Tb.pot:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
  -- BIG (the square in the corner)
  local big = CreateFrame("Button", nil, st, "BackdropTemplate")
  big:SetSize(16, 16)
  big:SetPoint("TOPRIGHT", st, "TOPRIGHT", -4, -4)
  big.edge = big:CreateTexture(nil, "BORDER")
  big.edge:SetAllPoints(big)
  big.edge:SetColorTexture(T.rgba("accent", 0.9))
  big.inner = big:CreateTexture(nil, "ARTWORK")
  big.inner:SetPoint("TOPLEFT", 4, -4)
  big.inner:SetPoint("BOTTOMRIGHT", -4, 4)
  big.inner:SetColorTexture(0.05, 0.04, 0.035, 1)
  big:SetScript("OnClick", function() Tb.SetBig(not Tb.big) end)
  big:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(Tb.big and "Small again" or "Big table")
    GameTooltip:AddLine(Tb.big and "Back where it was." or "The table half as big again, over everything else - a fight takes it back to small.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  big:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Tb.bigBtn = big
  -- the one walker: it ticks only while somebody walks
  Tb.mover = CreateFrame("Frame", nil, st)
  st:Hide()
  return st
end

--------------------------------------------------------------------
-- the people
--------------------------------------------------------------------

--- Who stands in the room: the demo's pretend people, or everyone at the round - and you, always.
function Tb.People()
  local me, out, seen = K.MyName(), {}, {}
  if Tb.demo then
    out[1] = Tb.Me()
    seen[me] = true
    for i = 1, Tb.demo do
      local name = Tb.DEMO_NAMES[(i - 1) % #Tb.DEMO_NAMES + 1]
      local race = Tb.DEMO_RACES[(i - 1) % #Tb.DEMO_RACES + 1]
      out[#out + 1] = { name = name, race = race, sex = (i % 3 == 0) and 3 or 2, demo = true, roll = Tb.demoRolls and Tb.demoRolls[name] }
    end
    return out
  end
  local Game = G.Game
  for _, name in ipairs(Game and Game.order or {}) do
    local p = Game.players[name]
    if p and not seen[name] then out[#out + 1] = p seen[name] = true end
  end
  if not seen[me] then table.insert(out, 1, Tb.Me()) end      -- standing by: you are in the room anyway
  return out
end

--- You, as a person, whether or not you sit at the round.
function Tb.Me()
  local me = K.MyName()
  local Game = G.Game
  if Game and Game.players[me] then return Game.players[me] end
  local _, class = UnitClass("player")
  local race
  if UnitRace then local _, r = UnitRace("player") race = r end
  return { name = me, class = class, race = race, sex = UnitSex and UnitSex("player") or 2 }
end

local function newActor(i)
  local st = Tb.stage
  local a = { actor = true, i = i }
  a.f = CreateFrame("Frame", nil, st)
  a.model = CreateFrame("DressUpModel", nil, a.f)
  a.model:SetAllPoints(a.f)
  a.label = a.f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  a.label:SetPoint("TOP", a.f, "BOTTOM", 0, 2)
  a.mood = a.f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  a.mood:SetPoint("BOTTOM", a.f, "TOP", 0, -2)
  a.roll = a.f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  a.roll:SetPoint("BOTTOM", a.mood, "TOP", 0, 0)
  Tb.actors[i] = a
  return a
end

--- Put an actor where it stands: its frame at its feet, sized and layered by how near it is.
function Tb.Place(a)
  local sx, sy, depth = Tb.ToStage(a.x, a.y)
  -- a spot past this room's edge (the room turned since, or someone else's corner) is drawn at the edge
  local l, t, r, b = Tb.Floor()
  sx, sy, depth = math.max(l, math.min(r, sx)), math.max(t, math.min(b, sy)), math.max(0, math.min(1, depth))
  local s = (0.72 + 0.42 * depth) * Tb.k
  local w, h = Tb.MODEL_W * s, Tb.MODEL_H * s
  a.f:SetSize(w, h)
  a.f:ClearAllPoints()
  a.f:SetPoint("BOTTOM", Tb.stage, "TOPLEFT", sx, -sy)
  local lvl = Tb.base + math.floor(depth * 40)
  if a.lvl ~= lvl then a.lvl = lvl a.f:SetFrameLevel(lvl) a.model:SetFrameLevel(lvl) end
end

--- Turn to face a spot (asked only when the angle really changes).
function Tb.Face(a, x, y)
  local f = Tb.Facing(a.x, a.y, x, y)
  if not a.face or math.abs(f - a.face) > 0.05 then
    a.face = f
    pcall(a.model.SetFacing, a.model, f)
  end
end

--- Lay the room out (UI:Layout, the table view): the stage's size for this many people, the table, and
--- everyone in it - their bodies asked for only when someone new stands there (or walks into range).
--- Returns the scene's width and height, as BiSGamba.lua's GridLayout does.
function Tb.Layout(ui, minW)
  local st = Tb.Build(ui.scene)
  local people = Tb.People()
  local n = #people
  local W = Tb.SIZES[#Tb.SIZES][2]
  for _, s in ipairs(Tb.SIZES) do if n <= s[1] then W = s[2] break end end
  Tb.SW, Tb.SH = W, math.floor(W / 1.43 + 0.5)
  Tb.k = W / Tb.SIZES[1][2]
  local w = math.max(Tb.SW + 16, minW or 0)
  st:SetSize(Tb.SW, Tb.SH)
  st:ClearAllPoints()
  st:SetPoint("TOP", ui.scene, "TOP", 0, 0)
  st:Show()
  Tb.base = (ui.scene:GetFrameLevel() or 1) + 4
  Tb.tableFrame:SetFrameLevel(Tb.base + 20)              -- the middle's depth: 0.5 of 40
  Tb.floor:SetFrameLevel(Tb.base - 1)
  Tb.bigBtn:SetFrameLevel(Tb.base + 50)
  -- the table: an oval of the turned room
  local tx, ty = Tb.ToStage(500, 500)
  local rx, ry = Tb.R_TABLE * Tb.SW * Tb.KX / 500, Tb.R_TABLE * Tb.SH * Tb.KY / 500
  local function put(t, wx, wy, ox, oy)
    t:SetSize(wx, wy)
    t:ClearAllPoints()
    t:SetPoint("CENTER", st, "TOPLEFT", tx + (ox or 0), -(ty + (oy or 0)))
  end
  put(Tb.shadow, rx * 2 + 16, ry * 2 + 12, 0, 6)
  put(Tb.rim, rx * 2 + 8, ry * 2 + 6)
  put(Tb.felt, rx * 2 - 6, ry * 2 - 5)
  put(Tb.shine, rx * 1.6, ry * 1.4)
  put(Tb.pot, 18 * Tb.k, 18 * Tb.k)
  put(Tb.lamp, rx * 3.2, ry * 3.4)
  -- turn the room: your place at the front
  local me = K.MyName()
  local mine = 1
  for i, p in ipairs(people) do if p.name == me then mine = i end end
  local _, _, aMe = Tb.SeatSpot(mine, n)
  Tb.rot = aMe
  -- everyone
  Tb.byName = {}
  local now = K.Now and K.Now() or GetTime()
  local check = now >= (Tb.checkAt or 0)
  if check then Tb.checkAt = now + 5 end
  for i, p in ipairs(people) do
    local a = Tb.actors[i] or newActor(i)
    local hx, hy = Tb.SeatSpot(i, n)
    a.homeX, a.homeY = hx, hy
    local fresh = a.name ~= p.name
    a.person, a.name = p, p.name
    if fresh then
      a.x, a.y, a.spot, a.walking, a.legs, a.face, a.restAt = hx, hy, nil, nil, nil, nil, nil
      a.f:Show()
      a.model:Show()
      K.ApplyModel(a)
    elseif check and a.how ~= "live" and not p.demo then
      local u = K.UnitFor(p.name)
      if u and UnitIsVisible and UnitIsVisible(u) then K.ApplyModel(a) end   -- walked into range: the real thing
    end
    if not a.walking and not a.spot then a.x, a.y = hx, hy end
    if not a.walking then Tb.Face(a, 500, 500) end         -- standing: looking at the table
    a.label:SetText(p.name == me and T.text("gold", K.Bare(p.name)) or K.Bare(p.name))
    a.roll:SetText(p.roll and T.text("accent", p.roll) or "")
    Tb.Place(a)
    a.f:Show()
    Tb.byName[p.name] = a
  end
  for i = n + 1, #Tb.actors do
    local a = Tb.actors[i]
    a.f:Hide()
    a.name, a.person, a.walking, a.legs = nil, nil, nil, nil
  end
  if not Tb.Walking() then Tb.mover:SetScript("OnUpdate", nil) end
  return w, Tb.SH + 4
end

function Tb.Hide()
  if Tb.stage then Tb.stage:Hide() end
  if Tb.big then Tb.SetBig(false) end
end

--- The actor standing for a name (BiSGamba.lua's SeatOf asks, in the table view).
function Tb.ActorOf(name) return name and Tb.byName[name] or nil end

--- Everyone standing in the room now.
function Tb.List()
  local out = {}
  for _, a in ipairs(Tb.actors) do if a.person and a.f:IsShown() then out[#out + 1] = a end end
  return out
end

--------------------------------------------------------------------
-- walking
--------------------------------------------------------------------

function Tb.Walking()
  for _, a in ipairs(Tb.actors) do if a.person and (a.walking or a.legs) then return true end end
  return false
end

local function wake()
  if Tb.mover:GetScript("OnUpdate") then return end
  Tb.mover:SetScript("OnUpdate", function(_, dt) Tb.Tick(dt) end)
end

--- Give an actor a set of legs to play: { go = {x, y} } walks there, { wait = s }, { act = anim, hold = s }.
function Tb.Legs(a, legs)
  a.legs = legs
  a.walking = true                       -- UI:Emote leaves a walker alone until the walk is done
  wake()
end

--- One frame of every walker. Stops ticking when nobody walks.
function Tb.Tick(dt)
  dt = math.min(tonumber(dt) or 0, 0.1)
  local any = false
  for _, a in ipairs(Tb.actors) do
    local leg = a.person and a.legs and a.legs[1]
    if leg then
      any = true
      if leg.wait then
        leg.wait = leg.wait - dt
        if leg.wait <= 0 then table.remove(a.legs, 1) end
      elseif leg.act then
        if not leg.started then
          leg.started = true
          a.anim = leg.act
          pcall(a.model.SetAnimation, a.model, leg.act)
          if leg.face then Tb.Face(a, leg.face[1], leg.face[2]) end
        end
        leg.hold = leg.hold - dt
        if leg.hold <= 0 then table.remove(a.legs, 1) end
      elseif leg.go then
        local gx, gy = leg.go[1], leg.go[2]
        if not leg.started then
          leg.started = true
          a.anim = 5
          pcall(a.model.SetAnimation, a.model, 5)                      -- run
          Tb.Face(a, gx, gy)
        end
        local dx, dy = gx - a.x, gy - a.y
        local d = math.sqrt(dx * dx + dy * dy)
        local step = Tb.SPEED * dt
        if d <= step then
          a.x, a.y = gx, gy
          table.remove(a.legs, 1)
        else
          a.x, a.y = a.x + dx / d * step, a.y + dy / d * step
        end
        Tb.Place(a)
      end
      if #a.legs == 0 then
        a.legs, a.walking = nil, nil
        a.anim = 0
        pcall(a.model.SetAnimation, a.model, 0)
        Tb.Face(a, 500, 500)
      end
    end
  end
  if not any then Tb.mover:SetScript("OnUpdate", nil) end
end

--- A click on the floor: you walk there (kept off the table, inside the room).
function Tb.ClickFloor()
  local a = Tb.ActorOf(K.MyName())
  if not (a and Tb.stage and GetCursorPosition) then return nil end
  local cx, cy = GetCursorPosition()
  local s = Tb.stage:GetEffectiveScale() or 1
  local left, top = Tb.stage:GetLeft(), Tb.stage:GetTop()
  if not (cx and left and top) then return nil end
  local x, y = Tb.Clamp(Tb.FromStage(cx / s - left, top - cy / s))
  return Tb.WalkTo(a, x, y)
end

--- Walk an actor to a spot of the room, and leave them standing there.
function Tb.WalkTo(a, x, y)
  x, y = Tb.Clamp(x, y)
  a.spot = { x, y }
  Tb.Legs(a, { { go = { x, y } } })
  return x, y
end

--- THE PAY WALK, across the room: the loser goes up to the winner where they stand, begs, and walks back
--- to where they were. (BiSGamba.lua's UI:PayWalk hands actors here.)
function Tb.PayWalk(from, to, delay)
  if not (from and to and from ~= to and from.person and to.person) then return false end
  local dx, dy = from.x - to.x, from.y - to.y
  local d = math.max(1, math.sqrt(dx * dx + dy * dy))
  local short = math.min(Tb.WALK.short, d * 0.5)
  local gx, gy = to.x + dx / d * short, to.y + dy / d * short
  Tb.Legs(from, { { wait = delay or 0 }, { go = { gx, gy } },
                  { act = G.ANIM.beg, hold = Tb.WALK.beg, face = { to.x, to.y } },
                  { go = { from.x, from.y } } })
  return true
end

--------------------------------------------------------------------
-- big
--------------------------------------------------------------------

--- Everyone's body again, posed for the table. A window's scale change resets each model's camera to the
--- client's own close portrait (Arn, 21 Oct 2026: "full screen 3d model gets cut off" - Chain showed from the
--- chest up), so after one the models are set again, at once and once more a moment later, after the client
--- has drawn the new size.
function Tb.Repose()
  for _, a in pairs(Tb.actors) do
    if a.name and a.f:IsShown() then K.ApplyModel(a) end
  end
end

--- Big (on top of everything, half as big again at most, a dark backdrop) or small (where it was).
--- Never remembered: the window opens small, for raids. A fight takes it back to small (UI:CombatHide).
function Tb.SetBig(on)
  local UI = G.UI
  local f = UI and UI.frame
  if not f then return nil end
  on = on and true or false
  if on == (Tb.big or false) then return on end
  Tb.big = on or nil
  local scale = db().scale or 1
  if on then
    if not Tb.back then
      local b = CreateFrame("Button", nil, UIParent)
      b:SetAllPoints(UIParent)
      b:SetFrameStrata("FULLSCREEN")
      local t = b:CreateTexture(nil, "BACKGROUND")
      t:SetColorTexture(0, 0, 0, 0.62)
      t:SetAllPoints(b)
      b:SetScript("OnClick", function() Tb.SetBig(false) end)      -- a click beside the table: small again
      Tb.back = b
    end
    local sw = UIParent:GetWidth() or 1024
    local sh = UIParent:GetHeight() or 768
    local w, h = f:GetWidth() or 500, f:GetHeight() or 350
    local k = math.min(Tb.BIG, sw * 0.96 / (w * scale), sh * 0.92 / (h * scale))
    Tb.back:Show()
    f:SetScale(scale * math.max(1, k))
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    if f.Raise then f:Raise() end
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  else
    if Tb.back then Tb.back:Hide() end
    f:SetScale(scale)
    f:SetFrameStrata("MEDIUM")
    f:ClearAllPoints()
    local d = db()
    if d.x then f:SetPoint(d.point or "CENTER", UIParent, d.rel or d.point or "CENTER", d.x, d.y) else f:SetPoint("CENTER") end
  end
  Tb.Repose()
  if C_Timer and C_Timer.After then C_Timer.After(0.1, Tb.Repose) end
  return on
end

--------------------------------------------------------------------
-- the demo: pretend people to look at, and a pretend round - drawing only
--------------------------------------------------------------------

--- `/bisgamba table demo [n]` (n pretend people), `demo round`, `demo off`.
function Tb.Demo(arg)
  arg = tostring(arg or ""):lower()
  if arg == "off" then
    Tb.demo, Tb.demoRolls = nil, nil
    K.Print("table demo off")
  elseif arg == "round" then
    if not Tb.demo then Tb.demo = 7 end
    return Tb.DemoRound()
  else
    Tb.demo = math.max(1, math.min(39, tonumber(arg) or 7))
    Tb.demoRolls = nil
    K.Print(("table demo: %d pretend people - click the floor to walk; /bisgamba table demo round plays a pretend round; /bisgamba table demo off"):format(Tb.demo))
  end
  K.DB().view = "table"
  G.UI:Show()
  G.UI:Refresh()
  return Tb.demo
end

--- A pretend round: everyone rolls, the top one cheers, the bottom one cries and walks over to pay.
function Tb.DemoRound()
  Tb.demoRolls = {}
  local hi, lo
  for i = 1, Tb.demo do
    local name = Tb.DEMO_NAMES[(i - 1) % #Tb.DEMO_NAMES + 1]
    local r = math.random(1, 100)
    Tb.demoRolls[name] = r
    if not hi or r > Tb.demoRolls[hi] then hi = name end
    if not lo or r < Tb.demoRolls[lo] then lo = name end
  end
  K.DB().view = "table"
  G.UI:Show()
  G.UI:Refresh()
  for _, a in ipairs(Tb.List()) do
    if a.person.demo then G.UI:Emote(a, 63, 1.2) end                -- reach for the dice
  end
  local A = G.ANIM
  local hiA, loA = Tb.ActorOf(hi), Tb.ActorOf(lo)
  if hiA then G.UI:Emote(hiA, A.cheer, 6) end
  if loA then G.UI:Emote(loA, A.cry, 3) end
  if hiA and loA and hiA ~= loA then Tb.PayWalk(loA, hiA, Tb.WALK.delay) end
  K.Print(("table demo: %s rolled %d and wins; %s rolled %d and walks over to pay (pretend)"):format(
    hi, Tb.demoRolls[hi], lo, Tb.demoRolls[lo]))
  return hi, lo
end
