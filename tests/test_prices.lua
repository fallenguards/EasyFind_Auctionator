-- Prices.lua against a stand-in Auctionator (2026-11-03): at login it
-- offers EasyFind's shopping lists its auction price with the price's age,
-- and searches a list line in its own tab. Run: lua tests/test_prices.lua
local ROOT = (arg and arg[0] or ""):match("^(.-)tests[/\\]") or "./"

local ages, searched, updates = { [2589] = 0, [2592] = 3 }, {}, {}
Auctionator = { API = { v1 = {
    GetAuctionPriceByItemID = function(_, id) return id == 2589 and 125 or nil end,
    GetAuctionPriceByItemLink = function(_, link) return link == "item:2592" and 980 or nil end,
    GetAuctionAgeByItemID = function(_, id) return ages[id] end,
    GetAuctionAgeByItemLink = function(_, link) return ages[tonumber(link:match("item:(%d+)"))] end,
    RegisterForDBUpdate = function(_, fn) updates[#updates + 1] = fn end,
} } }

local sources, searches, refreshed = {}, {}, {}
EasyFind = { API = {
    VERSION = 1,
    RegisterExtension = function() end,
    RegisterRowDecorator = function() end,
    RegisterPriceSource = function(id, def) sources[id] = def end,
    RegisterAuctionSearch = function(id, fn) searches[id] = fn end,
    RefreshPrices = function(id) refreshed[#refreshed + 1] = id end,
} }
C_AddOns = { IsAddOnLoaded = function(name) return name == "Auctionator" end }
C_Item = {}
C_Timer = { After = function(_, fn) fn() end }
local frames = {}
function CreateFrame()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end

local atHouse, ready = false, true
local ns = { L = setmetatable({}, { __index = function(_, k) return k end }),
             ListsReady = function() return ready end, StartLists = function() end, RefreshLists = function() end,
             SearchTerms = function(terms) searched[#searched + 1] = terms[1].searchString .. (terms[1].isExact and "!" or "") end }
assert(loadfile(ROOT .. "Prices.lua"))("EasyFind_Auctionator", ns)
local HouseInSight = ns.AtAuctionHouse
ns.AtAuctionHouse = function() return atHouse end
frames[1].onEvent(frames[1], "PLAYER_LOGIN")

local pass, fail = 0, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then pass = pass + 1 print("  ok   " .. name) else fail = fail + 1 print("  FAIL " .. name .. "\n       " .. tostring(err)) end
end
local function eq(a, b, what) if a ~= b then error((what or "") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

print("== AuctionatorPrices ==")

check("thePriceSource_oneKind_itsPriceAndAge", function()
    local def = sources.auctionator
    eq(def and def.label, "EXT_NAME", "offered under the extension's name")
    eq(#def.sources, 1)
    eq(def.sources[1].key, "auction")
    local copper, note = def.price("auction", 2589, nil)
    eq(copper, 125, "by the id with no link")
    eq(note, "PRICE_AGE_TODAY")
    copper, note = def.price("auction", 2592, "item:2592")
    eq(copper, 980, "by the link when there is one")
    eq(note, "PRICE_AGE_FMT", "days ago")
    copper, note = def.price("auction", 4306, nil)
    eq(copper, nil, "never scanned: no price")
    eq(note, nil)
end)

check("aScan_redrawsTheListsPrices", function()
    refreshed = {}
    updates[1]()
    eq(refreshed[1], "auctionator")
end)

check("theSearch_onlyAtTheHouse_inItsOwnTab", function()
    local fn = searches.auctionator
    eq(fn("item:2589", "Linen Cloth"), false, "away from the house: the house's own box gets it")
    atHouse = true
    eq(fn("item:2589", "Linen Cloth"), true)
    eq(searched[1], "Linen Cloth!", "an exact search for the name")
    ready = false
    eq(fn("item:2589", "Linen Cloth"), false, "lists not bound: not taken")
    ready, atHouse = true, false
end)

-- TSM's window on retail keeps the house's own shown at scale 0.001: not
-- the house to search in (2026-11-03).
check("theHouse_onlyWhenItsWindowIsInSight", function()
    local function Frame(shown, scale)
        return { IsShown = function() return shown end, GetScale = function() return scale end }
    end
    eq(HouseInSight(), false, "no house")
    AuctionHouseFrame = Frame(true, 0.001)
    eq(HouseInSight(), false, "shrunk out of sight behind another window")
    AuctionHouseFrame = Frame(true, 1)
    eq(HouseInSight(), true)
    AuctionHouseFrame, AuctionFrame = nil, Frame(true, 1)
    eq(HouseInSight(), true, "the classic house")
    AuctionFrame = nil
end)

print(("%d passed, %d failed"):format(pass, fail))
if fail > 0 then os.exit(1) end
