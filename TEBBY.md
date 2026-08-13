# TEBBY.md - pickle_lottery

## Overview

`pickle_lottery` is a FiveM resource by Pickle Mods that adds a fully-featured, immersive lottery system to GTA V roleplay servers. Players interact with lottery kiosks placed at configurable world coordinates to purchase scratch-off tickets, Keno tickets, and Moneyball tickets; play games through a NUI overlay; insert filled tickets for draws; and redeem receipts or scratchers for cash prizes. Society (faction job bank) accounts receive a configurable cut of every purchase. The resource supports ESX and QBCore out of the box and exposes an open bridge layer for custom frameworks.

---

## Code Design

### Architecture

The resource follows the standard Pickle Mods layered pattern:

1. **Shared layer** (`config.lua`, `core/shared.lua`, `locales/`) — loaded on both client and server. `config.lua` holds all operator-editable settings. `core/shared.lua` defines the `_L()` locale helper and a few math utilities used everywhere.
2. **Core client** (`core/client.lua`) — global UI and interaction helpers: `CreateBlip`, `CreateProp`, `CreateNPC`, `PlayAnim`, `PlayEffect`, `CreateInteraction` / `UpdateInteraction` / `DeleteInteraction`, and the single poll loop that renders entities and detects keypress/target interactions. Defines the shared `ShowInteractText`, `FormatOptions`, and `SelectInteraction` functions consumed by all modules.
3. **Core server** (`core/server.lua`) — auto-bootstraps the three DB tables (`lottery_keno`, `lottery_moneyball`, `lottery_receipts`) with `CREATE TABLE IF NOT EXISTS` via `MySQL.Sync.execute` at resource start. Sets `SchemaReady = true` once done so modules can guard against early queries.
4. **Bridge layer** (`bridge/`) — framework-specific adapters loaded via glob patterns. Only the matching bridge file runs (guarded by `GetResourceState` checks at the top of each file). Provides a uniform API: `ShowNotification`, `AddMoney`, `RemoveMoney`, `GetMoney`, `AddSocietyMoney`, `RemoveSocietyMoney`, `RegisterUsableItem`, inventory access through the `Inventory` table, and `lib.callback.register("pickle_lottery:getInventory")`.
5. **Module layer** (`modules/`) — game logic split into two modules:
   - `modules/locations/` — spawns kiosk props/blips, registers `CreateInteraction` for each `Config.Locations` entry, and drives the in-game ox_lib context menus (purchase, insert, redeem, view drawings).
   - `modules/lottery/` — client-side NUI display and NUI callbacks; server-side game draw scheduling (`lib.cron`), receipt/scratchoff generation, ticket redemption, society payouts, and Discord webhook notifications.
6. **NUI** (`nui/`) — vanilla HTML/CSS/JS. Entry point is `nui/index.html`. Game-specific UI modules: `keno.js`, `moneyball.js`, `scratch.js`, `scratch-it.js` (canvas scratcher), `receipt.js`. Communicates with Lua via `SendNUIMessage` / `RegisterNUICallback`.
7. **Discord** (`discord.lua`) — a simple configuration table (`Discord`) for webhook URL and drawing notifications. Consumed by `modules/lottery/server.lua`.

### Main Flows

**Purchase → Insert → Redeem (Keno/Moneyball)**
1. Player interacts with kiosk → `LotteryMenu` (client) → `PurchaseMenu` → `TriggerServerEvent("pickle_lottery:shopPurchase")`.
2. Server deducts cash, pays society cut, calls `Inventory.AddItem` for a blank `lottery_keno` / `lottery_moneyball` item.
3. Player uses blank ticket from inventory → `RegisterUsableItem` fires → `TriggerClientEvent("pickle_lottery:interactItem")` → `DisplayApp` opens NUI.
4. NUI collects number selections → `RegisterNUICallback("saveTicket")` → `TriggerServerEvent("pickle_lottery:saveTicket")` stores selections as item metadata via `Inventory.SetMetadata`.
5. Player inserts ticket at kiosk → `TicketInventoryMenu` → `TriggerServerEvent("pickle_lottery:purchaseTicket")` → server deducts panel cost, pays society, calls `GiveReceipt` which inserts into `lottery_receipts` and gives a `lottery_receipt` item with metadata.
6. `lib.cron` fires on `drawingFrequency` → `GenerateGame` inserts a new row into `lottery_keno`/`lottery_moneyball`, matches receipts for that game window, updates the DB, optionally posts a Discord embed.
7. Player redeems receipt at kiosk → `RedeemInventoryMenu` → `TriggerServerEvent("pickle_lottery:redeemTicket")` → server queries DB, computes matching numbers and prize, calls `WinnerEvent` (pays player, optionally removes society money).

**Scratch-off Flow**
1. Purchase deducts cash → server calls `GenerateScratchoff` → random numbers are generated, stored in `lottery_receipts`, item metadata written to inventory.
2. Player uses scratch item → NUI opens scratch canvas. On redeem: `TriggerServerEvent("pickle_lottery:redeemTicket")` → server reads DB record, computes matches, awards prize, deletes DB record, removes item.

### Conventions

- All server-to-client notifications go through `ShowNotification(source, text)` (bridge-provided).
- Society payouts go through `AddSocietyMoney(jobName, amount)` / `RemoveSocietyMoney(jobName, amount)` (bridge-provided).
- Inventory operations always go through the `Inventory.*` table (never directly to framework inventory exports outside the bridge).
- Locale strings are retrieved with `_L("key", ...)` — missing keys return `ERR_TRANSLATE_<key>_404`.
- Modules never `require` each other; shared functions are globals declared in `core/`.
- `lib` (ox_lib) is used for: context menus (`lib.registerContext`/`lib.showContext`), input dialogs (`lib.inputDialog`), alert dialogs (`lib.alertDialog`), callbacks (`lib.callback.register`/`lib.callback`), text UI (`lib.showTextUI`/`lib.hideTextUI`), and cron jobs (`lib.cron.new`).

---

## Important Files

| Path | Purpose |
|---|---|
| `fxmanifest.lua` | FiveM resource manifest — defines load order, escrow scope, NUI page, and `dependency /assetpacks` |
| `config.lua` | **Primary operator config** — all locations, store items, game parameters (Keno/Moneyball prizes/wagers/draw frequency), scratch-off definitions, render/interact distances |
| `discord.lua` | Discord webhook config (`Discord.Drawings.webhook`, `Discord.Drawings.enabled`) |
| `core/shared.lua` | `_L()` locale helper, `GetRandomInt`, `v3()` — loaded on both sides before any module |
| `core/server.lua` | Auto-bootstraps the three DB tables at resource start; sets `SchemaReady` flag |
| `core/client.lua` | All interaction/entity helpers, the main render + keypress poll loop, `DisableCamera` toggle |
| `locales/en.lua` | All player-facing strings (English). Copy to add new languages |
| `modules/locations/client.lua` | Spawns all kiosk interactions and blips; drives all ox_lib menus |
| `modules/locations/server.lua` | `shopPurchase` and `purchaseTicket` net events; `SocietyProfit` helper |
| `modules/lottery/client.lua` | `DisplayApp`/`HideApp` NUI wrappers; `saveTicket` NUI callback |
| `modules/lottery/server.lua` | Game draws (cron), receipt generation, scratchoff generation, `redeemTicket` net event, `WinnerEvent`, Discord embeds |
| `bridge/esx/server.lua` | ESX server bridge — money, society (via `esx_addonaccount`), `RegisterUsableItem` |
| `bridge/qb/server.lua` | QBCore server bridge — money, society auto-detection (`Renewed-Banking` → `qb-banking` → `qb-management`), fallback inventory |
| `bridge/inventory/ox_inventory/server.lua` | ox_inventory `Inventory.*` implementation and `getInventory` callback registration |
| `bridge/inventory/qs-inventory/server.lua` | qs-inventory `Inventory.*` implementation |
| `bridge/target/ox_target/client.lua` | ox_target zone/model registration wrappers |
| `bridge/target/qb-target/client.lua` | qb-target zone/model registration wrappers |
| `bridge/target/qtarget/client.lua` | qtarget zone/model registration wrappers |
| `bridge/custom/client.lua` | Stub for unsupported frameworks (prints warning, does nothing) |
| `bridge/custom/server.lua` | Stub for unsupported frameworks (prints warning, does nothing) |
| `nui/index.html` | NUI entry point for all lottery game UIs |
| `nui/assets/js/keno.js` | Keno ticket selection UI |
| `nui/assets/js/moneyball.js` | Moneyball panel selection UI |
| `nui/assets/js/scratch.js` | Scratch-off ticket reveal UI |
| `nui/assets/js/scratch-it.js` | Canvas scratcher library |
| `nui/assets/js/receipt.js` | Receipt display UI |
| `_INSTALL/install.sql` | Manual SQL import (equivalent to what `core/server.lua` auto-runs) |
| `_INSTALL/Items/ox_inventory.lua` | Item definitions paste for ox_inventory |
| `_INSTALL/Items/qbcore.lua` | Item definitions paste for QBCore shared items |
| `_INSTALL/Items/qs-inventory.lua` | Item definitions paste for qs-inventory |

---

## Intended Behaviors

### Escrow / partial source
`fxmanifest.lua` has an `escrow_ignore` block that explicitly lists the files shipped as plain Lua and those that are escrow-protected. The `modules/**/*.*` and `core/*.*` lines are **commented out**, meaning those directories are currently escrow-protected in production builds. The bridge, config, locales, and discord files are always open. A fix PR must not assume `modules/` or `core/` source is freely editable in a customer build — only the files in `escrow_ignore` that are **uncommented** are guaranteed to be readable.

### `Config.Debug = true` default
`config.lua` ships with `Config.Debug = true`. This is intentional for new installs (makes setup issues visible in the console) and is expected to be set to `false` in production. Do not treat debug prints in the console as a bug if `Config.Debug` is true.

### Keno ticket price is always `0` in the store
The `lottery_keno` and `lottery_moneyball` items in `Config.DefaultStore` (and all location stores) have `price = 0`. This is intentional — players obtain the blank slip for free, but pay the actual wager when they **insert** the filled ticket via `pickle_lottery:purchaseTicket`. Reporting "free keno tickets" as a bug is incorrect.

### `GenerateScratchoff` inserts with no explicit `id`
`modules/lottery/server.lua` calls `MySQL.Async.insert` for scratch-offs with the column list `(id, type, data)` but passes only `@type` and `@data` parameters — there is no `@id` binding. MySQL will auto-increment `id`. The `@id` in the column list resolves to `NULL` in mysql-async, which triggers the AUTO_INCREMENT. This is not a bug; the returned `game_id` is the new auto-increment value.

### Society payouts happen even when `canSocietyLose = false`
`SocietyProfit` (in `modules/locations/server.lua`) always runs on purchases — society accounts always receive their cut of ticket sales. `Config.Lottery.canSocietyLose` only controls whether society money is **removed** when a player wins (`WinnerEvent`). Setting `canSocietyLose = false` (the default) means the house never loses, but society still profits from sales.

### QBCore society auto-detection delay (2-second wait)
`bridge/qb/server.lua` has a `CreateThread` with `Wait(2000)` before resolving the banking resource. This delay is intentional — it allows the banking resource to finish starting before the detection runs. It is not a race condition bug; it is a deliberate startup ordering workaround.

### `RegisterNetEvent("pickle_lottery:saveTicket")` uses bare `source`
In `modules/lottery/server.lua` the `saveTicket` handler captures `source` without declaring it locally (`local source = source`). This relies on the FiveM implicit `source` global present inside registered net event handlers. It is consistent with how the rest of the file uses `source` and is not a bug — though it differs from the pattern used in other net events in the same file which do `local source = source`.

### `?` (nil-safe) operator usage
Several places in `modules/lottery/server.lua` use the Lua 5.4 / FiveM nil-safe navigation operator (`?.`) e.g. `itemData.metadata?.game`. This is valid in FiveM's Lua 5.4 runtime (`lua54 'yes'` in the manifest). It is not a syntax error.

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|---|---|---|
| Locale strings show as `ERR_TRANSLATE_<key>_404` | `Config.Language` value doesn't match the key inside `locales/en.lua` (e.g. resource folder was renamed) | Ensure the resource folder is named exactly `pickle_lottery`. The `Config.Language = "en"` key must match `Language["en"]` in `locales/en.lua` |
| Resource folder renamed (e.g. `pickle_lottery_v2`) | Breaks locale loading, NUI asset paths, and escrow validation | Always keep the folder name `pickle_lottery` |
| Items not in inventory after purchase | `_INSTALL/Items/` definitions not imported into the target inventory | Paste the appropriate `_INSTALL/Items/*.lua` contents into your inventory config and restart |
| Scratch-off tickets don't stack / disappear | `stack = false` for scratch-off items is intentional (each has unique metadata) | Not a bug — each scratch-off is a unique item with embedded winning numbers |
| Society money not credited on QBCore | None of `Renewed-Banking`, `qb-banking`, or `qb-management` is running | Start a supported banking resource, or set `Config.Lottery.societyResource = 'none'` to disable |
| `Config.Lottery.societyResource` has no effect | Value misspelled or set before resource starts | Valid values: `'auto'`, `'Renewed-Banking'`, `'qb-banking'`, `'qb-management'`, `'none'` |
| Keno/Moneyball draws never fire | `lib.cron` scheduling string is wrong or ox_lib not started | Verify `Config.Games.keno.drawingFrequency` is a valid cron expression; ensure ox_lib starts before pickle_lottery |
| DB tables missing / query errors on first boot | `_INSTALL/install.sql` not imported AND `core/server.lua` auto-bootstrap failed | Check mysql-async is running and the DB connection is healthy; `core/server.lua` auto-creates tables but needs a live DB |
| NUI does not open when using a ticket item | `RegisterUsableItem` not wiring up — usually means no supported inventory bridge loaded | Confirm `ox_inventory` or `qs-inventory` is started; for QBCore without those, the fallback bridge registers items via `QBCore.Functions.CreateUseableItem` |
| Targeting not working | `Config.UseTarget = true` but no supported target resource started | Start `ox_target`, `qb-target`, or `qtarget` before `pickle_lottery`, or set `Config.UseTarget = false` |
| `Config.NoModelTargeting = true` spawns invisible bricks | Intentional — without a `model` defined and with target enabled, an invisible `ng_proc_brick_01a` prop is spawned so players can third-eye the interaction zone | Not a bug |
| Winner sound plays globally | `TriggerClientEvent("pickle_lottery:locationSound", -1, ...)` broadcasts to all clients; volume is attenuated by distance in the handler | Intentional design; only players near the kiosk will hear meaningful volume |

---

## Conventions

- **Naming**: item names use `lottery_` prefix (`lottery_keno`, `lottery_moneyball`, `lottery_pickle`, `lottery_wildcherry`, `lottery_luckyseven`, `lottery_receipt`). New items must follow this prefix pattern.
- **Locale keys**: snake_case, all lowercase (e.g. `menu_main_purchase`). New locale keys must be added to `locales/en.lua` under `Language["en"]` and use `string.format` `%s`/`%d` placeholders.
- **Bridge pattern**: each bridge file starts with a guard `if GetResourceState('resource_name') ~= 'started' then return end`. All framework-specific code stays inside bridge files; modules never call framework exports directly.
- **Inventory abstraction**: all inventory reads/writes go through the `Inventory.*` table (set up by the active inventory bridge). Never call `exports.ox_inventory` or `QBCore.Functions` directly from module code.
- **Net events**: server-side handlers always capture `local source = source` at the top of the handler body (most do; see noted exception above). Client-side handlers use `RegisterNetEvent` + `AddEventHandler` pattern via `RegisterNetEvent`/shorthand.
- **ox_lib dependency**: `lib.*` (context menus, dialogs, callbacks, cron, textUI) is the sole UI/utility library. Do not introduce other UI frameworks.
- **MySQL**: use `MySQL.Async.*` for non-blocking queries from callbacks and `MySQL.Sync.*` only in the schema bootstrap (`core/server.lua`). Match the existing parameter binding style (`@param` named parameters).
- **Lua 5.4**: the manifest declares `lua54 'yes'`. Nil-safe navigation (`?.`) and other Lua 5.4 features are in use; fix PRs may use them.
- **No side-effects in `config.lua`**: `config.lua` is a pure data table file — no function calls or requires. Keep it that way.
- **`discord.lua`**: keep it as a flat config table. Discord embed logic stays in `modules/lottery/server.lua`.
- **Style**: 4-space indentation in Lua files (tabs used in some bridge files — follow the surrounding file's style). No trailing semicolons.
