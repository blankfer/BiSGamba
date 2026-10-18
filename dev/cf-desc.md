# BiS Gamba — CurseForge page text

Paste everything below the line into the project description, in the Markdown editor. Kept here since
1.7.0 (18 Oct 2026); the page before it still said TBC Classic Anniversary. Big features update this
file and the live page together (Arn's rule); fixes stay in the changelog. House voice:
`_bisdev/docs/voice.md`.

---

# BiS Gamba

**Gold gambling for raid nights, in the BiS theme. For WoW Forever.**

`/bisgamba` opens the table (`/gamba` works too). `/bisgamba help` lists every command.

## The table

Type a roll range and hit **start**. The game goes up in raid chat, and people join by typing **1**, no addon needed, or with the **join** button. **last call** gives ten seconds, then the rolls start themselves. Nobody joins after seeing a roll land, and anyone called who doesn't roll forfeits. Highest wins, lowest pays the difference.

You stand big, in 3D, on the left, with your buttons under you: join, roll, leave, pay. Only the next one to press is lit. Everyone else sits on the right, as class portraits or 3D models. Anyone can host the next round, and the window hides itself in combat.

## The team game

Press **team** and the number is the wager. It needs an even number of players, four or more. The sides are dealt at random and the wager is shared out: 100 between five a side is everyone `/roll 20`. A wager that won't split evenly gets an **audible**, moved to the nearest even split, and the table tells you. Each side's rolls are added up. A tie rolls again. Then each loser pays one winner.

## Deathroll

One on one, as a duel. You on the left, your opponent on the right, the rolls down the middle. Pick them from your party or raid, or type a guildmate's whole name, and type the gold: 500g starts at `/roll 500`. They accept or decline. Every roll is out of the last one, and whoever rolls a 1 pays. Tick **for fun** to roll without betting. Button bottom left on the table, or `/bisgamba dr <name>`.

## Who owes who

Every result goes into a debts book that survives logout. Yours come first; everybody else's fold into one line. **pay** opens a trade with the next person you owe and hands you the amount to paste into the gold field, because no addon may fill it on this client. When the trade completes, the book settles itself.

You can't fib a debt away: only the person who was owed can clear it. Pay someone who doesn't run BiS Gamba and your own finished trade counts. When neither of you runs it, no addon ever sees the trade, so the debt says "on their honour" and leaves the book the next day.

## Leaderboard

Biggest winners and losers, all-time, with win and loss records. Deathrolls count too. Each round is stamped with the guild it was played in, so a guildie's bad night in a pug doesn't drag your guild's board down. A new guildie can take the most complete ledger with one button.

## Sound and settings

Short sounds for last call, your turn to roll, wins and losses. With [FojjiCore](https://www.curseforge.com/wow/addons/fojjicore) installed, one of its voice packs speaks them instead. Never the raid-warning sound. Settings live behind the **options** button or `/bisgamba config`.

## Works with

- **Other addons** can read the leaderboard, standings, debts and recent rounds through `BiSGambaAPI`. Read-only: nothing else can move gold or settle a debt.
- Part of the BiS family. Talks to the other BiS addons over one shared channel; `/biscomm off` silences it.
