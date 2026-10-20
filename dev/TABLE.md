# The table: everyone in 3D around one round table (plan, 20 Oct 2026)

Arn, 20 Oct:

> Rethink the big gamba window with the table with 3d models moving, people with the addon can move them around and everyone sees we only read where they walk and we draw on our client and have them if they don't have the addon if the enter the game their 3d models still interact as if they are standing around gambling around a table. That window can still start small because of raids and I'm not opposed to the idea that people can full screen like out other survivor window with back drops and such

## Phase 1 — built (Table.lua, branch feat/table-scene, stacked on feat/pay-walk)

**The view.** A third view, "table", beside 2d and 3d: the header's `table` button, `/bisgamba view table`, or `/bisgamba table`. `InitDB` keeps it across logins.

**The room.**
- One round table, made from discs (the portraits' round mask): a shadow, a wood rim, green felt, a lamp glow, and the pot's coin.
- Table space runs 0..999 both ways, with the table's middle at 500,500.
- **Every client turns the room so that YOU stand at the front.**
- People stand on a circle around the table, in `Game.order`.
- Depth decides each person's size and frame level. People behind the table draw behind it, people in front draw over it.

**Bodies.** Same as the seats, through `G.Kit.ApplyModel`:
- `SetUnit` when the person is in range;
- otherwise their race's checked stand-in;
- otherwise a wisp.

**People without the addon stand there too.** They roll, cheer, cry and pay like everyone else, because every client already hears the rolls.

**Walking.**
- Click the floor and you walk there, kept off the table and inside the room. You stay there across refreshes.
- Locally only for now; phase 2 tells everyone else.

**The pay walk crosses the room.** The loser walks up to the winner wherever they stand, begs, and walks back (`Tb.PayWalk`; `UI:PayWalk` hands actors to it).

**Big.**
- The square in the stage's corner, or `/bisgamba table big`.
- The window becomes FULLSCREEN_DIALOG, up to 1.5x bigger, centred, over a dark backdrop. Clicking the backdrop makes it small again.
- Never remembered (raids). `UI:CombatHide` drops it to small.

**Demo.** `/bisgamba table demo [n]` seats n pretend people (the 16 stand-ins), and `table demo round` plays a pretend round:
- everyone reaches for the dice;
- the top roll cheers;
- the bottom roll cries and walks over to pay.

It only draws. Nothing is sent, booked or paid. `table demo off` ends it.

**Cost.**
- One walker frame ticks only while somebody walks.
- Six walkers for a second ask the client 0 things; budget 10.
- Ten refreshes of the view ask 430, nearly all of them the window's own name questions; budget 500.

## Phase 2 — tell the others where you walk (needs two clients)

**The `SPOT` message.**
- Format: `SPOT\t<x>\t<y>`, in table space, integers 0..999.
- Sent at click time, on RAID or PARTY.
- At most one every 2 s. The latest click wins; a SPOT still waiting is overwritten.
- Lowest priority: it waits behind any game op.
- Dropped if older than 5 s, or during chat lockdown.

**Receiving a SPOT.**
- Only from group members, and only about the sender themselves.
- At most one every 0.5 s per sender.
- Stored in `Table.spots[sender]`.

**Catch-up.** `Game.Replay` adds `SPOTS\tName:x:y...` in pieces under 250 bytes (it's a whisper).

**The drain fix comes first.** `Comm.drain()` sends one message every 0.15 s and never reads the client's answer. On Forever (about 1 addon message a second per player, across all addons) a burst can be lost silently. Read the answer the way LibBiSComm's `ResultKind` does, and hold the queue on a throttle.

**Whole names.** `UnitFor` and `InGroup` should ask `GetUnitName(u, false)` first, so names with surnames match.

## Phase 3

- Small idle animations: one person at a time, every 8-15 s.
- Faces turn to whoever rolls.
- Drag your own model.
- Spectators at the rail.
- Looks for people outside the group, from target or mouseover.
- 2D tokens beyond 20 models in the small window (40 in big).

## Phase 4 (after probes)

- A real 3D table: a `SetModel(fileID)` doodad, or a ModelScene.
- Table as the default view (dbver 8).

## Probes for Arn

1. **Phase 1, alone:**
   ```
   /bisgamba table demo 8
   ```
   Click the floor, then run:
   ```
   /bisgamba table demo round
   ```
   Then the square, then the square again.
2. **Frame rate.** Run this before and after `/bisgamba table demo 30`, small and big:
   ```
   /run print(GetFramerate())
   ```
3. **The message burst on Gamba's prefix**, in a party:
   ```
   /run local n=0 for i=1,60 do local r=C_ChatInfo.SendAddonMessage("BiSGamba","PROBE","PARTY") if r and r~=0 then print("refused at",i,"code",r) return end n=i end print("all",n,"left")
   ```
4. **Names**, in a party:
   ```
   /run print(UnitName("player"), GetUnitName("player",false), UnitName("party1"), GetUnitName("party1",false))
   ```
5. **Is there a ModelScene?**
   ```
   /run local ok,s=pcall(CreateFrame,"ModelScene",nil,UIParent) print(ok, s and s.CreateActor)
   ```

## Risks

- **The message budget.** See phase 2.
- **Frame rate** with 40 full-body models. See probe 2.
- **Models are not clipped by the window.** The floor is clamped inside the room.
- **A hidden model may never load.** The stage is shown before bodies are asked for.
