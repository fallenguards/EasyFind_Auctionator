-- Auctionator's prices on EasyFind's item rows: the last scanned auction
-- price at the row's right, and "Add to shopping list" in the row's menu.
-- Auctionator is read through its public API; its data is never copied.
local ADDON, ns = ...
local API = EasyFind and EasyFind.API
if not (API and API.VERSION == 1) then return end

local L = ns.L
local KEY = "auctionator"
local ICON = "Interface\\AddOns\\EasyFind_Auctionator\\tag"
ns.KEY = KEY

local C_Item = C_Item
local sformat = string.format
local GetCoinTextureString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString or GetCoinTextureString

-- Auctionator's price functions, bound at login; nil until then.
local A = {}

local function DB()
    EasyFindAuctionatorDB = EasyFindAuctionatorDB or {}
    return EasyFindAuctionatorDB
end
ns.DB = DB

-- An on-unless-false switch: nil when on, so the saved table stays small.
function ns.SetSwitch(key, on)
    if on then DB()[key] = nil else DB()[key] = false end
end

function ns.Print(text)
    print(sformat("|cff66ccff%s:|r %s", L["EXT_NAME"], text))
end

function ns.Coins(copper)
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return tostring(copper)
end

function ns.AtAuctionHouse()
    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then return true end
    return (AuctionFrame and AuctionFrame:IsShown()) or false
end

-- ==== Auctionator ============================================================

local NEED = { byLink = "GetAuctionPriceByItemLink", byID = "GetAuctionPriceByItemID" }

local function Bind()
    local v1 = Auctionator and Auctionator.API and Auctionator.API.v1
    if not v1 then return false end
    for k, name in pairs(NEED) do
        if type(v1[name]) ~= "function" then return false end
        A[k] = v1[name]
    end
    -- The scan callback is a per-flavor file: present on the modern AH.
    if type(v1.RegisterForDBUpdate) == "function" then A.onUpdate = v1.RegisterForDBUpdate end
    return true
end

-- The last scanned price in copper: by the link when there is one (gear
-- is keyed by item level), else by the id; nil when never scanned.
function ns.AuctionPrice(link, itemID)
    if link and A.byLink then return A.byLink(ADDON, link) end
    if itemID and A.byID then return A.byID(ADDON, itemID) end
    return nil
end

-- ==== EasyFind's item rows ===================================================

local function RowPrice(row, link)
    if DB().rowPrices == false then return nil end
    return ns.AuctionPrice(link, row.itemID)
end

-- The client's own name for the row's item, as the list term.
local function RowItemName(row)
    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(row.itemID)
    return name or row.name
end

local function RowMenu(row)
    if not ns.ListsReady() then return nil end
    local name = RowItemName(row)
    local rows = {}
    if not API.RegisterAddTarget then
        rows[1] = { kind = "menu", label = L["MENU_ADD"], rows = function() return ns.AddToListRows(name) end }
    end
    if ns.AtAuctionHouse() then
        rows[#rows + 1] = { kind = "action", label = L["MENU_SEARCH"],
                            onClick = function() ns.SearchTerms({ { searchString = name, isExact = true } }) end }
    end
    return rows
end

local function RefreshRows()
    if API.RefreshRowDecorations then API.RefreshRowDecorations() end
end

-- A scan reports prices in batches: shown rows repaint once it pauses.
local pending = false
local function OnPricesChanged()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        RefreshRows()
    end)
end

API.RegisterExtension({
    id = KEY,
    name = L["EXT_NAME"],
    description = L["EXT_DESC"],
    icon = ICON,
    keywords = { "auction", "auction house", "prices", "shopping list" },
    scope = KEY,
    settings = function(page, kit)
        local below = kit.Title(page, L["EXT_NAME"], L["SETTINGS_HINT"])
        local box = kit.Checkbox(page, L["OPT_ROW_PRICE"],
            function() return DB().rowPrices ~= false end,
            function(on)
                ns.SetSwitch("rowPrices", on)
                RefreshRows()
            end, L["OPT_ROW_PRICE_TIP"])
        box:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -8)
    end,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        if Bind() then
            if API.RegisterRowDecorator then
                API.RegisterRowDecorator({ id = KEY, slot = "price", label = L["DECORATOR_LABEL"], text = RowPrice, menu = RowMenu })
            end
            if A.onUpdate then A.onUpdate(ADDON, OnPricesChanged) end
        else
            ns.Print(L["NOT_READY_PRICES"])
        end
        ns.StartLists()
        self:RegisterEvent("AUCTION_HOUSE_CLOSED")
    else
        -- The AH closed: a last repaint, and the lists it may have changed.
        RefreshRows()
        ns.RefreshLists()
    end
end)
