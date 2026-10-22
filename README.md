# EasyFind: Auctionator Extension

Auctionator's prices on EasyFind's item rows, and your shopping lists in EasyFind's search bar. An item row (the item catalog, boss loot, your bags and bank) shows the price from your last auction house scan at its right, and its right-click menu adds the item to one of your shopping lists. Type a list's name to see what is on it; at the auction house a click searches it.

Requires Auctionator and EasyFind.

## What it adds

- The last scanned auction price at the right of EasyFind's item rows, with a switch in Options > Extensions.
- Add to shopping list in an item row's right-click menu: one of your lists, or a new one.
- Shopping list rows in EasyFind's search results, and an `@shopping` scope that lists them. Typing a list's name shows its items, each with what the term asks for (quantity, rank, item level).
- Click a list or an item at the auction house to search it in Auctionator's shopping tab; away from it, a list opens in the bar and an item is looked up in EasyFind. Shift-click links a known item in chat.
- Right-click an item on a list to search it, find it, add it to another list or remove it.
- An Auctionator tile in the extensions menu.

## Dependencies

- EasyFind, with its extension API (EasyFind.API version 1). Prices on item rows need EasyFind's row decorator; without it the shopping lists still work.
- Auctionator, read at runtime through its public API (Auctionator.API.v1). Nothing of Auctionator's is copied into this addon.

## How it reads Auctionator

At login the addon looks for the price and shopping list functions of Auctionator's API. If one it needs is missing in the installed version, that part turns itself off with one line in chat and nothing else changes. Prices are read from Auctionator's own scan database as rows are drawn. Shopping lists are written only through Auctionator's API, and only when you pick Add or Remove yourself.
