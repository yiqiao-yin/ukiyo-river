# Running it

Two ways. The editor is faster to iterate in; the .exe is what the game actually is.

## From the editor

Open `C:\Dev\ukiyo-river` in Godot 4.7.2 and press **F5**.

## As a standalone game

`build\UkiyoRiver.exe` - double-click it. Nothing else needs to be installed; everything is
packed into the one file, which is why it is around 120 MB.

To rebuild after a change:

```
godot --headless --path 'C:\Dev\ukiyo-river' --export-release "Windows Desktop" 'C:\Dev\ukiyo-river\build\UkiyoRiver.exe'
```

`build/` is gitignored - the binary is too big to keep in the repo.

## Controls

| | |
| --- | --- |
| W / S | pole forward and back |
| A / D | steer |
| Left click, or Space | strike |
| Right click (hold), or F | guard |
| Shift | heavy strike, costs 気 |
| Q | swap weapon |
| Middle-drag | look around |
| Scroll | zoom |

The buttons top right cycle Weather, Time and View, and toggle Drift and Sound.

## Getting to the fighting quickly

Combat does not start until **z = -150**, which is a couple of minutes of drifting from the
start. That is right for playing and wrong for testing, so there are debug keys:

| | |
| --- | --- |
| **F1** | send a wave now |
| **F2** | jump 120 m downstream, toward the dangerous end |
| **F3** | heal to full |
| **F4** | hand over every weapon, to try them with Q |

Press **F2** three or four times from the start and you are in the thick of it. F1 then puts a
boarding party on you immediately.

These live in `scripts/combat/debug_keys.gd` on one node in `main.tscn`. Deleting that script
and that node removes them; nothing else refers to them.

## What to look for

- **Cast off** lifts the title. The boat poles itself downstream on Drift until you touch
  W/A/S/D.
- A **skiff comes up astern**, pulls alongside, and a samurai steps across onto the deck.
- He **winds up visibly** before every blow. Guard inside the last quarter-second of that
  windup and it is turned aside for nothing; guard early and a quarter still gets through and
  drains 気; guard with no 気 and it breaks.
- Your sweeps **alternate left and right**, and each only catches what is on that side. Two
  boarders on opposite sides have to be taken in turn.
- Beating someone gives experience and **takes his weapon** - press Q to use it.
- At zero health you are **struck down**, not dead: the attackers leave and the river carries
  you on at 60 % health.

## Known rough edges

- Balance is a first guess. Getting to the far end under-levelled is a beating.
- No evade yet; guarding is the only answer to a telegraph.
- Enemies guard on a weighted coin flip, not by reading your swing.
- Pressing F1 repeatedly can put four attackers on you at once, which is the cap.
