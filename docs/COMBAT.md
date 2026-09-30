# Combat

The first step past the port: samurai board the boat and try to kill you.

## Characters

Everyone on screen - the player and every enemy - is a `CharacterStats`: a level, health,
chi (気), a weapon inventory and an equipped weapon. One class, so the player has no special
case and an enemy could be made playable without rewriting anything.

- **Health** is the obvious one. At zero the player is *struck down* rather than dead: the
  attackers go over the side, you come round after 3.5 s at 60 % health, and the river carries
  you on. A bad fight costs progress, not the session.
- **Chi (気)** refills on its own and buys heavy strikes, worth 2.2x damage. It is the only
  choice in the fight: chip away safely, or spend for a blow that ends it sooner.
- **Levels** add 11 health, 8 chi and 9 % damage. Experience comes from kills and is worth
  `base x level`, so a Sohei is worth roughly four Ashigaru.

## Weapons

| | kanji | damage | reach | swing | 気 |
| --- | --- | --- | --- | --- | --- |
| Bo staff | 棒 | 11 | 2.8 | 0.55 s | 12 |
| Katana | 刀 | 15 | 2.1 | 0.45 s | 16 |
| Naginata | 薙刀 | 19 | 2.9 | 0.70 s | 20 |
| Yari | 槍 | 12 | 3.1 | 0.60 s | 14 |
| Tetsubo | 鉄棒 | 26 | 2.2 | 0.95 s | 24 |

You start with the bo staff - the pole the boatman already poles with. Beating an enemy takes
his weapon, so the inventory fills as you go down the river. Q cycles what is in hand.

## The enemies

| | kanji | levels | health | 気 | weapon | the tell |
| --- | --- | --- | --- | --- | --- | --- |
| Ashigaru | 足軽 | 1-2 | 42 | 12 | Yari | wide straw jingasa, light plate |
| Ronin | 浪人 | 2-4 | 64 | 22 | Katana | bare head, topknot, small shoulder guards |
| Samurai | 侍 | 4-6 | 96 | 38 | Katana | red lacquer, gold lacing, kabuto with horns, iron mask |
| Sohei | 僧兵 | 5-7 | 84 | 64 | Naginata | hooded robe, no helmet, deepest chi |

Each has its own lacquer, lacing and cloth colour, so they read apart at a distance. All are
built the same way as the boatman - lathes, cones and squashed spheres, no skinned meshes.

## The asymmetry

This is the point of the whole design. The player is a boatman, not a swordsman, and the
combat says so.

**He knows two things.** Sweep the staff left, sweep it right. Every click alternates: left,
right, left. Both are the same move mirrored - same damage, same timing, same flat two-handed
arc, because it is a punt pole and he is using it the only way he knows how. The heavy strike
is not a technique either; it is the same sweep with his weight and his 気 behind it.

A sweep only catches what is on the side it is travelling toward, plus whatever is straight
ahead. Two boarders on opposite sides therefore have to be taken in turn, and that alternation
is the entire tactical content of fighting with a pole.

**They know four.** Even a level 1 ashigaru is trained:

| technique | kanji | what it looks like | note |
| --- | --- | --- | --- |
| Kesa cut | 袈裟斬り | up over the shoulder, down across the body | slowest, hits hardest |
| Body swing | 胴斬り | drawn back to the side, swung flat through the waist | widest reach |
| Rising cut | 斬り上げ | dropped low, whipped up from the opposite hip | fastest, weakest |
| Thrust | 突き | cocked beside the hip, driven straight out | longest, for spears |

Which techniques a fighter has comes from his weapon: a katana carries the kesa cut, the body
swing and the rising cut; a naginata swings, cuts and thrusts; a yari mostly thrusts. He never
plays the same one twice in a row, so the pattern stays unreadable.

Every technique spends its first half winding up somewhere visible before the blade comes
back. That telegraph is what makes them fair - you can see a kesa cut coming, and it is the
only warning you get.

## How an attack happens

1. Past **z = -150** - a couple of minutes downstream - skiffs start appearing astern.
2. A skiff closes on the boat faster than you can row, so you cannot simply outrun it, though
   steering does buy time.
3. Within 3.2 m the samurai steps across in an arc, clears the gunwale, and is reparented onto
   the boat so he rides with it.
4. On deck he closes to his weapon's reach, turns to face you, and swings on a cycle. The first
   swing is delayed 1.3-2.2 s and staggered per attacker, so a boarding party cannot land three
   blows on one frame.
5. You have a 0.7 s mercy window after each hit taken.

Both the size of a wave and the calibre of who is in it scale with how far downstream you are,
from one Ashigaru near the start to three of the worst by the far end, capped at four aboard.

## Controls

| | |
| --- | --- |
| Left click, or Space | strike |
| Shift | heavy strike, costs 気 |
| Q | swap weapon |
| Right-drag | look around (moved off the left button to make room for the strike) |
| W/S, A/D | pole and steer, as before |

## Known rough edges

This was built as a rough first pass, deliberately.

- **Balance is a first guess.** The numbers above are tuned by arithmetic, not by playing.
  Arriving at the far end under-levelled is a beating. Every constant is at the top of its file.
- **No blocking or dodging.** Steering is the only defence, and only before they board, and
  there is no way yet to answer a telegraph other than by hitting first.
- **The player's two sweeps are the same move mirrored.** Deliberate for now - he is a boatman -
  but it is where new techniques should go as he levels.
- **Hits are distance checks**, not hitboxes - anything within reach of the swing is hit,
  regardless of facing.
- **Abandoned skiffs sit where they were left** rather than drifting away.
