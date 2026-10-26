-- Lists.lua against a stand-in Auctionator (2026-10-26): a shopping list
-- opens as a linked checklist note and the player's edits there reach the
-- list through Auctionator's API. Run: lua tests/test_lists.lua
local ROOT = (arg and arg[0] or ""):match("^(.-)tests[/\\]") or "./"

-- Auctionator: lists in memory, terms as "name;quantity".
local lists, order, calls = {}, {}, {}
local function Copy(t) local o = {} for i = 1, #t do o[i] = t[i] end return o end
local manager = {
    GetCount = function() return #order end,
    GetByIndex = function(_, i)
        local name = order[i]
        return { GetName = function() return name end, IsTemporary = function() return false end }
    end,
    GetIndexForName = function(_, name)
        for i = 1, #order do if order[i] == name then return i end end
    end,
}
local v1 = {
    GetShoppingListItems = function(_, name) return Copy(lists[name]) end,
    CreateShoppingList = function(_, name, items)
        if not lists[name] then order[#order + 1] = name end
        lists[name] = Copy(items)
        calls[#calls + 1] = "create " .. name .. " [" .. table.concat(items, ",") .. "]"
    end,
    DeleteShoppingListItem = function(_, name, raw)
        for i, r in ipairs(lists[name]) do if r == raw then table.remove(lists[name], i) break end end
        calls[#calls + 1] = "delete " .. raw
    end,
    AlterShoppingListItem = function(_, name, old, new)
        for i, r in ipairs(lists[name]) do if r == old then lists[name][i] = new break end end
        calls[#calls + 1] = "alter " .. old .. " -> " .. new
    end,
    ConvertToSearchString = function(_, term) return term.searchString .. ";" .. (term.quantity or "") end,
    ConvertFromSearchString = function(_, raw)
        local name, qty = raw:match("^(.-);(.*)$")
        return { searchString = name, quantity = tonumber(qty) }
    end,
    MultiSearchAdvanced = function() end,
}
Auctionator = { API = { v1 = v1 }, Shopping = { ListManager = manager } }

-- EasyFind: the linked-checklist calls recorded; one note.
local note = {}
local registered, provider, addTarget
EasyFind = { API = {
    VERSION = 1,
    RegisterSearchProvider = function(def) provider = def end,
    RegisterAddTarget = function(def) addTarget = def end,
    RefreshSearchProvider = function() end,
    LinkChecklists = function(_, handlers) registered = handlers end,
    LinkedChecklist = function(_, key, _, make) if make then note.key = key end return note.key and 7 or nil end,
    SyncChecklist = function(_, entries) note.entries = entries end,
    SetChecklistRefs = function(_, refs) note.refs = refs end,
    OpenNote = function(id) note.opened = id end,
} }

-- The client: two items it knows by name.
local ITEMS = { ["Linen Cloth"] = 2589, ["Wool Cloth"] = 2592 }
local NAMES = { [2589] = "Linen Cloth", [2592] = "Wool Cloth" }
C_Item = {
    GetItemInfoInstant = function(name) return ITEMS[name], nil, nil, nil, 134000 end,
    GetItemInfo = function(id) return NAMES[id], "item:" .. id end,
    GetItemNameByID = function(id) return NAMES[id] end,
    GetItemIconByID = function(id) return 130000 + id end,
}
C_Timer = { After = function(_, fn) fn() end }
IsShiftKeyDown = function() return false end

local db = {}
local ns = { KEY = "auctionator", L = setmetatable({}, { __index = function(_, k) return k end }),
             AtAuctionHouse = function() return false end, Print = function() end, Coins = tostring,
             DB = function() return db end }
assert(loadfile(ROOT .. "Lists.lua"))("EasyFind_Auctionator", ns)
ns.StartLists()

local pass, fail = 0, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    if ok then pass = pass + 1 print("  ok   " .. name) else fail = fail + 1 print("  FAIL " .. name .. "\n       " .. tostring(err)) end
end
local function eq(a, b, what) if a ~= b then error((what or "") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

print("== AuctionatorLists ==")
lists["Mats"], order[1] = { "Linen Cloth;20", "Wool Cloth;", "Dust;" }, "Mats"

check("aListOpensAsItsNote", function()
    ns.OpenList("Mats")
    eq(note.opened, 7, "the note opens")
    local e = note.entries
    eq(#e, 3)
    eq(e[1].line.link, "item", "an amount: counted")
    eq(e[1].line.target, 20)
    eq(e[2].line.item, 2592, "no amount: ticked by hand")
    eq(e[2].line.link, nil)
    eq(e[3].line.text, "Dust", "a name the client does not know: its text")
    eq(registered and registered.changed, ns.PushNote, "edits come back to the list")
end)

check("aNewAmountAltersTheEntry", function()
    calls = {}
    ns.PushNote(7, "Mats", {
        { id = 1, ref = "Linen Cloth;20", item = 2589, link = "item", target = 40 },
        { id = 2, ref = "Wool Cloth;", item = 2592 },
        { id = 3, ref = "Dust;", text = "Dust" },
    })
    eq(table.concat(calls, " | "), "alter Linen Cloth;20 -> Linen Cloth;40")
    eq(note.refs[1], "Linen Cloth;40", "the line now stands for the new entry")
end)

check("aLineAddedAndOneRemoved", function()
    calls = {}
    ns.PushNote(7, "Mats", {
        { id = 1, ref = "Linen Cloth;40", item = 2589, link = "item", target = 40 },
        { id = 3, ref = "Dust;", text = "Dust" },
        { id = 4, text = "Silk Cloth" },
    })
    eq(table.concat(calls, " | "), "delete Wool Cloth; | create Mats [Linen Cloth;40,Dust;,Silk Cloth;]")
    eq(note.refs[4], "Silk Cloth;")
end)

check("anUntouchedNoteWritesNothing", function()
    calls = {}
    ns.PushNote(7, "Mats", {
        { id = 1, ref = "Linen Cloth;40", item = 2589, link = "item", target = 40 },
        { id = 3, ref = "Dust;", text = "Dust" },
        { id = 4, ref = "Silk Cloth;", text = "Silk Cloth" },
        { id = 5, link = "quest", text = "Bring the cloth" },
    })
    eq(#calls, 0, "a quest line is the note's own; the list already matches")
end)

-- Added from a result row while the client has not cached the item: the
-- line still carries the item, so it shows its icon.
check("anItemAddedFromARowKeepsItsIcon", function()
    local rows = addTarget.rows({ itemID = 4306, name = "Silk Cloth" })
    for _, r in ipairs(rows) do
        if r.label == "Mats" then r.onClick() end
    end
    ns.OpenList("Mats")
    local last = note.entries[#note.entries]
    eq(last.ref, "Silk Cloth;")
    eq(last.line.item, 4306, "known by the id the row carried")
end)

check("anItemOnAListOpensTheList", function()
    note.opened = nil
    provider.select({ name = "Linen Cloth", listName = "Mats", raw = "Linen Cloth;40", term = { searchString = "Linen Cloth" } })
    eq(note.opened, 7, "away from the auction house: the list's note")
end)

print(("%d passed, %d failed"):format(pass, fail))
if fail > 0 then os.exit(1) end
