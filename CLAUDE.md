Read ../_bisdev/CLAUDE.md first.

## Layout (Gamba only)

- `BiSGamba.toc`: the load order, and the only place the version lives (`## Version`). `release.ps1`, the harness and LibBiSComm all read it from there.
- `BiSGamba.lua`: the whole addon, about 3.9k lines, split into sections by `----` banners:
  - theme fallback and sounds
  - DB defaults and migrations (`dbver`, currently 8: Forever 1.0, 7 Nov 2026 - the defaults are a NEW install's, quiet; a save from before 8 gets autoOpen/sound/whisper written in as on where it never stored them)
  - guild and roll parsing
  - `Ledger`
  - `Comm` (the `BiSGamba` addon-message prefix)
  - `Game` (the state machine `IDLE → JOIN → ROLL → DONE`)
  - round-ledger adoption and `Trade`
  - `UI` (2d/3d seat grid; stand-ins by checked display id, `DISPLAY`; the pay walk, `UI:PayWalk`)
  - Options (the `Own` owners)
  - slash commands (`/bisgamba` main; `/gamba`, `/gamble` kept as aliases)
- `Deathroll.lua` (16 Oct 2026): one-on-one deathroll, loaded straight after `BiSGamba.lua` and built on its `G.Kit` (buttons, names, money words, db). Party, raid or guild only, by whole name; ops `DRASK/DRYES/DRNO/DRROLL/DRBYE` whispered on Gamba's prefix (`Game.OnComm` hands anything starting `DR` to it before its own group-only check). The wager goes through `Ledger.Add` and `AddRound` (round `mode = "dr"`).
- `Table.lua` (20 Oct 2026): the "table" view (`G.Table`): everyone in 3D around one round table, the room turned so you stand at the front; click-to-walk (local), the pay walk across the room, big (FULLSCREEN_DIALOG, never remembered, a fight drops it), `/bisgamba table demo`. Built on `G.Kit` (`ApplyModel`); BiSGamba.lua hands it the scene in `UI:Layout`, `SeatOf`, `UI.Everyone`, `UI:PayWalk` and `UI:CombatHide`. Plan and phases: `dev/TABLE.md`.
- `API.lua`: `BiSGambaAPI` (major 1, version 1), the last TOC line, for other addons (playbook 5a). Read-only copies (leaderboard, standing, debts, recent rounds, the table) plus `Open()`; the header is its documentation. Event `BiSGamba_RoundEnded`, fired from `Book` through `G.Fire`, which API.lua sets. Nothing in it moves gold or edits the books.
- `Libs/`: embedded copies of LibBiSComm-1.0, RezComm-1.0 and BiSTheme Console/Options/Settings (Settings.lua: the BiS> Gamba page in the game's options, registered at login by `G.SettingsHome`, is the kit's dashboard - `T.Dashboard` from `UI:DashModel()`, Settings minor 3, 8 Nov. Sections: table (roll range, flat stakes, seating, announce; button opens the table), timing (last call, settle grace, straggler reminder), ledger (board scope, whisper, select amount, wipes), deathroll (nothing to set; button opens its window), team game (nothing to set; its command), sound (its own switch through `Own.sound`, the same setter as `/bisgamba sound`; cues, channel, voice, test), display (portraits, scale, zoom, combat, pop-up, never open), gamba (minimap, BiS channel, reset position; button shows the options window as it always was). Its rows are the options window's very tables - `UI:Sections()` makes `UI:OptionSections()` once and both use it; the window is never squeezed inside the page. The minimap's right-click toggles the OWN options window, `UI:ToggleConfig` via `Mini.Options`, never the game's options - 8 Nov). See the libs rules in `../_bisdev/CLAUDE.md`.
- `dev/tests.lua`: the headless harness. It loads every Lua file the TOC lists, in order, and needs the addon to expose `BiSGamba` (as `G`) and its event frame as `G._ev`. It fails if an internal leaks into `_G` or if the `dbver` migrations break. Use `runTimers(maxDelay)` for countdowns. `dev/harness.lua` is only a shim that `dofile`s it.
- `dev/release.ps1`: builds the zip (without `dev/` or the dotfiles) and uploads it to CurseForge project 1682133. It sends the top entry of `CHANGELOG.md` as the changelog.
- `.github/workflows/check.yml`: calls the reusable CI workflow in `bisdev`.
