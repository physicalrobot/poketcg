# Custom pastel palette — Pokémon TCG (poketcg)

Reference for porting the Crystal Legacy pastel scheme to this repo
(pret's Pokémon Trading Card Game disassembly). It records what we learned in
the research and audit, which decisions we made, and where the work stands.
Read this before touching palettes.

Companion doc for the original scheme:
`C:\Users\kimbo\Documents\Pokemon_Crystal_Legacy\custom-palette.md`.

---

## 1. Status

| Stage | What | Status |
|---|---|---|
| 1 | Toolchain + baseline build | **Done.** Unmodified source builds; `poketcg.gbc: OK`, `poketcg.patch: OK` against `rom.sha1`. |
| 2 | Overworld maps + their textbox palette | **Applied** (2026-10-13) to `src/data/palettes1.asm`; builds. Needs in-game check in mGBA. |
| 3 | Duel board + menus (`CGBDefaultPalettes`) + link / printer / Card Pop backgrounds | **Applied** (2026-10-13); builds. Needs in-game check (duel board can't be rendered from source). |
| 4 | Title / logo / booster screens (backgrounds only) | Not started |

Repo state: base commit `2d81ec3`; `build.sh`, `build.bat` added and
`src/data/palettes1.asm` changed by Stage 2; `src/engine/duel/core.asm` and
`src/data/palettes2.asm` changed by Stage 3; half-width player name fix (§7).
All uncommitted. The proposal
was regenerated from source and was byte-identical to the previewed file:
724 `rgb` lines in the 24 map sets, no other lines. (`git diff --stat` shows
857 because of how it aligns blank lines; a line-by-line compare gives 724.)

User rules for this project:
- Nothing may change by accident. Audit every user of a palette before
  editing, preview, and get approval before each stage is applied.
- **Protected (never change):** card artwork, medals, attack/effect
  animations, character portraits, and any Pokémon artwork (intro and booster
  Pokémon).
- Player/NPC overworld sprites (`OverworldOAMPal`) stay unchanged.

---

## 2. Target scheme (from Crystal)

RGB values are 5-bit (0–31).

| Role | RGB |
|---|---|
| Cream (backgrounds, textboxes) | 31,29,24 |
| Blue-purple (text, thin outlines) | 10,8,25 |
| Lilac gray / muted purple (UI grays) | 26,24,27 / 17,15,24 |
| Pink / light pink | 30,11,22 / 31,20,26 |
| Aqua-mint (grass, plants) | 18,28,28 |
| Periwinkle | 20,15,29 |
| Water blue / light blue / lightest | 6,20,28 / 15,25,31 / 24,30,31 |
| Tree shade (cool) | 13,16,28 |
| Peach / coral | 31,25,17 / 30,15,18 |
| Dusty rose / plum | 26,21,21 / 17,12,21 |

Crystal rule carried over: blue-purple only for thin outlines and text, never
large areas.

---

## 3. Build setup

- Needs **RGBDS 1.0.x** (`src/rgbdscheck.asm` fails on older versions). Crystal
  needs 0.5.2, so the two use separate toolchains.
- We use the official **Linux** RGBDS **v1.0.4** binaries in
  `C:\Users\kimbo\rgbds-1.0` (from
  `https://github.com/gbdev/rgbds/releases/download/v1.0.4/rgbds-linux-x86_64.tar.xz`).
  They run natively in WSL Ubuntu, so no `.exe` path issues.
- `build.sh` (repo root) runs
  `make <targets, default tcg> RGBDS=/mnt/c/Users/kimbo/rgbds-1.0/`.
  - `build.bat` runs it from Windows.
  - `./build.sh compare` builds and checks against `rom.sha1`. It reports OK
    only on unmodified source; after palette edits, use the default `tcg`.
- Output: `poketcg.gbc` (and `poketcg.patch` / `poketcg_vc.gbc` for compare).
- Build tools (`tools/*.c`) compile with WSL `gcc`. Makefile vars: `RGBDS`,
  `RGBASM`, `RGBLINK`, `RGBFIX`, `RGBGFX`.

---

## 4. How poketcg handles color (architecture)

- **No `.pal` files** for screens and maps. Every color is an `rgb r, g, b` line
  in:
  - `src/data/palettes1.asm` and `src/data/palettes2.asm`, indexed by
    `src/data/palette_pointers.asm` (`palette_pointer Label, numBG, numOBJ`;
    constants `PALETTE_*`).
  - `src/engine/duel/core.asm:4180` `CGBDefaultPalettes` (BGP0–4, also copied
    to OBP0) plus SGB packets `Pal01Packet_Default` (SGB only, leave alone).
- **Palette data format** (top of `palettes1.asm`): first byte 0/1/2 = how many
  DMG OBP bytes follow, then a count byte, then `rgb` lines, 4 per palette.
- **One palette set per screen or map**, not shared time-of-day tables like
  Crystal. There's no day/night.
- **Colors are not ordered light→dark.** For example, world map palette 1 is
  white / green / blue / near-black. Map colors by hue and role, never by slot
  position.
- **Map loading** (`src/engine/overworld/load_overworld.asm:44-56`): loads
  `wCurMapInitialPalette` (always `PALETTE_DEFAULT_CGB` = `DefaultCgbPal`),
  then the map's own palette set (`wCurMapPalette`) **overwrites all 8 BG
  palettes**. So `DefaultCgbPal` has essentially no visible effect on maps.
- **Map headers** (`src/data/map_headers.asm`): SGB tilemap, CGB tilemap,
  initial CGB palette (always default), SGB palette, final CGB palette, song.
- **Map palette 0** in every map set is the textbox/UI palette
  (white / 20,20,16 / 8,8,8 / black).
- **Many map sets contain identical "filler" palettes**: black / 28,0,0 /
  28,12,0 / 28,28,0, the `DefaultCgbPal` pattern. These are probably unused
  slots, but that's unproven, so they are left untouched.
- **Card art palettes** are generated from `src/gfx/cards/*.png` (INCBIN `.pal`
  in `src/gfx.asm`), so they're safe if we don't touch the PNGs.
- **Scenes** (title, logos, boosters, link, printer, Card Pop) choose palettes
  in `src/data/scenes.asm`.

### Map tilemaps (for rendering previews)
- CGB tilemaps: `src/data/maps/tiles/cgb/<map>.bin` = interleaved
  **(tile, attribute)** byte pairs, row-major. `.bgmap` is the build-time
  row-split version (`tools/bgmap.c`).
- Size: `src/data/maps/tiles/dimensions/<map>.dimensions` (2 bytes: width,
  height in tiles).
- Attribute bits: 0–2 = palette number, bit 3 = VRAM bank, bit 5 = X flip,
  bit 6 = Y flip.
- Tile IDs: maps load at VRAM `$8800` (`wVRAMTileOffset = $80`), so tile ID
  `$80–$FF` → tileset index 0–127, and `$00–$7F` → index 128+.
- Tilemap → tileset table: `src/engine/gfx/tilemaps.asm`. Tileset graphics:
  `src/engine/gfx/tilesets.asm` → `src/gfx/tilesets/*.2bpp` (world map:
  `src/gfx/overworld_map.2bpp`).

| Map tilemap | Tileset | Palette set |
|---|---|---|
| overworld_map | overworld_map | OverworldMapPal |
| mason_laboratory, deck_machine_room | masonlaboratory | MasonLaboratoryPal |
| ishihara | ishihara | IshiharasHousePal |
| `<type>`_club_entrance (×8) | clubentrance | `<Type>`ClubEntrancePal |
| challenge_hall_entrance | clubentrance | FightingClubEntrancePal |
| club_lobby (all 8 lobbies) | clublobby | ClubLobbyPal |
| `<type>`_club (×8) | `<type>`club | `<Type>`ClubPal |
| challenge_hall | challengehall | ChallengeHallPal |
| pokemon_dome_entrance | pokemondomeentrance | PokemonDomeEntrancePal |
| pokemon_dome | pokemondome | PokemonDomePal |
| hall_of_honor | hallofhonor | HallOfHonorPal |

### World map palette roles (confirmed by rendering)
- pal 1: sea (white waves / green coast / **water 9,3,31** / outline)
- pal 2: grassland (green fill 8,26,0 / dark-green trees 1,15,0)
- pal 3: desert sand (browns 25,18,6 / 15,6,0)
- pal 6: gold textbox frame at the top

---

## 5. Audit — who uses each palette

| Palette set | Used by | Decision |
|---|---|---|
| `OverworldMapPal` | world map | Stage 2 |
| `MasonLaboratoryPal` | Mason's Lab **and** Deck Machine Room | Stage 2 |
| `IshiharasHousePal` | Ishihara's House | Stage 2 |
| `FightingClubEntrancePal` | Fighting Club entrance **and** Challenge Hall entrance | Stage 2 |
| other `*ClubEntrancePal` | their entrance | Stage 2 |
| `ClubLobbyPal` | **all 8** club lobbies | Stage 2 |
| `*ClubPal` (8) | their club | Stage 2 |
| `ChallengeHallPal`, `PokemonDomeEntrancePal`, `PokemonDomePal`, `HallOfHonorPal` | their map | Stage 2 |
| `DefaultCgbPal` | initial map palette (immediately overwritten); debug | **Don't change** (no benefit; its pals 1–7 are black-backed) |
| `CGBDefaultPalettes` (duel/core.asm) | duels, deck machine, deck selection, card album, link duel, game loop, via `SetDefaultConsolePalettes`; BGP0 is also copied to OBP0 (menu cursors/arrows) | Stage 3 |
| `CardPopBGPal`, `GBLinkBGPal`, `GBPrinterBGPal` | Card Pop / link / printer scenes | Stage 3 (pal 0 only) |
| `TitleScreenPal`, `CopyrightPal`, `NintendoPal`, `CompaniesPal`, `*BoosterPal` | title/logo/booster scenes | Stage 4 (backgrounds only, after rendering) |
| `OverworldOAMPal`, `*PicPal`, `MedalsPal`, effect pals (`GlowPal`…`DuelResultPal`), intro pals, card `.pal`s, SGB packets | — | **Don't change** |

Stage 3 as applied:
- `CGBDefaultPalettes` BGP0: 28,28,24 → cream, 21,21,16 → 26,24,27,
  10,10,8 → 17,15,24, black → 10,8,25. BGP1–3: only color 0 → cream; color 3
  stays **black** (user choice, "Option 1") so the hand-list card-type icons,
  duel separator and deck/hand icons keep their original outlines. BGP4
  (duel/menu textbox frames, `wTextBoxFrameType = $04`): color 0 → cream,
  color 3 → 10,8,25. SGB `Pal01Packet_Default` untouched.
- Card-type icons use BGP1–3 via `GetCardTypeIconPalette`
  (`deck_configuration.asm`); the Colorless icon uses BGP0, so it still has
  the blue-purple outline (would need a spare palette slot to change).
- `GBLinkBGPal` / `GBPrinterBGPal` / `CardPopBGPal`: **every** 28,28,24 → cream
  (rendering showed the Game Boy art in pals 1–5 shares that background, and
  Card Pop's screen background is **pal 6**, not pal 0); pal 0 grays/black
  mapped as above. Game Boy / printer / logo art colors kept.
- Known side effect (accepted, protected): portraits with a 28,28,24 background
  (Ken, Mitch, Gene, Courtney, John, Adam, Jonathan, Imakuni) and medals sit in
  a faint gray box on the cream screens.

Original Stage 3 note: `CGBDefaultPalettes` BGP1–4 carry **energy-type colors** (keep
the hues). Only change color 0 (28,28,24 → cream) and color 3 (black →
blue-purple). Credits reuse map palettes, so they'll follow Stage 2
automatically.

---

## 6. Stage 2 color mapping (applied)

Applied only to the 24 map sets above; filler palettes skipped.

1. Exact UI grays: 20,20,16 → 26,24,27; 8,8,8 → 17,15,24; steel gray
   18,18,24 → 22,20,26.
2. True black / near-black (r+g+b ≤ 7) → blue-purple 10,8,25.
3. White / near-white (min channel ≥ 28, or a neutral ≥ 26 in color 0) →
   cream 31,29,24.
4. Everything else: family by HSV hue, level by perceived lightness
   (`0.30r + 0.59g + 0.11b`, over 31).
   - **Families by hue:** saturation < 0.18 → gray; hue < 15 or ≥ 330 →
     red; < 40 → orange (brown if dark); < 65 → yellow (brown if dark);
     < 165 → green; **< 262 → blue**; else purple.
   - **Levels:** pale tint (min ≥ 20 and lum > 0.82) / light (> 0.55) /
     mid (> 0.28) / dark.
   - **Saturated dark blues** (blue channel ≥ 20) use the mid level, so water
     and screens become water blue 6,20,28.
5. Duplicates inside one palette are nudged so each palette keeps 4 distinct
   colors.

| Family | pale | light | mid | dark |
|---|---|---|---|---|
| green | 24,30,28 | 18,28,28 | 9,22,22 | 13,16,28 |
| blue | 24,30,31 | 15,25,31 | 6,20,28 | 12,12,26 |
| red | 31,25,29 | 31,20,26 | 30,11,22 | 22,8,19 |
| orange | 31,28,22 | 31,25,17 | 30,15,18 | 22,10,16 |
| yellow | 31,29,22 | 31,27,18 | 31,25,17 | 26,18,18 |
| brown | 31,27,26 | 26,21,21 | 21,15,21 | 17,12,21 |
| purple | 29,25,31 | 24,19,30 | 20,15,29 | 13,10,24 |
| gray | 29,27,29 | 26,24,27 | 22,20,26 | 17,15,24 |

Fixes made during review:
- Blue/purple hue cutoff raised to 262 so the world-map sea (9,3,31) becomes
  water blue, not dark purple.
- Near-black threshold lowered from 16 to 7. Thick dark-brown wall frames now
  become plum instead of solid blue-purple, which follows the Crystal rule.

Verification of the proposed file: changes only in the 24 labels; only `rgb`
lines differ; 1,460 `rgb` lines before and after; all values 0–31.

Still open after in-game testing (applied with defaults):
- Keep the Lightning Club's dark night-sky room darker?
- Adjust any club's identity colors?

---

## 7. Half-width player name (not a palette change)

Vanilla stores the player name in the full-width font (`textfw`), and
`TX_RAM1` (`<RAMNAME>`) switches dialogue to full width for it, so the name
looks big and spaced out. Fix: `src/engine/halfwidth_name.asm`
(`ConvertNameToHalfWidth`, "Input Name" section, bank 6) converts the copied
name in `wStringBuffer` to `TX_HALFWIDTH` text; it's called via `farcall` from
`ProcessTextHeader.tx_ram1` in `src/home/print_text.asm`. It covers A–Z, 0–9,
space and `? & + - ' !` (everything the naming keyboard offers); names that
are already half-width (NPC names) or contain anything else stay unchanged.
All 179 `<RAMNAME>` uses are in half-width text. The save data and the naming
screen are untouched.

## 8. Helper scripts (session scratchpad, temporary)

They live in a Claude session scratchpad (last seen in
`%TEMP%\claude\c--Users-kimbo-Documents-Pokemon-Crystal-Legacyb93ebab-...\scratchpad`)
and may be gone. Recreate from these
descriptions if needed. All run in WSL `python3` (no PIL; PNGs written with
`zlib`).

- `tcg_pastel.py`: parses `palettes1.asm`, applies the §6 mapping to in-scope
  labels, and writes `palettes1_proposed.asm`, `stage2_mapping.txt` (every
  old → new color) and `stage2_preview.png` (swatches).
- `tcg_render.py` / `tcg_sheet.py`: render maps from `.bin` + tileset `.2bpp` +
  palette label (see §4). The sheet script writes `maps_1..7.png` with original
  on the left and proposed on the right. `--labels` mode marks each tile's
  palette number with a colored dot (white 0, red 1, green 2, blue 3, yellow
  4, magenta 5, cyan 6, black 7).
- `tcg_stage3.py`: writes `core_proposed.asm` / `palettes2_proposed.asm` and
  `stage3_preview.png` using the Stage 3 rules above.
- `tcg_scene.py`: renders link / printer / Card Pop scenes (tile offset $90
  for link and printer, $80 for Card Pop), one panel per `.asm` given.
- `tcg_verify.py`: compares original vs proposed `.asm`. Same line count,
  only `rgb` lines differ, values ≤ 31, and lists changed labels.

Applying Stage 2 = copy `palettes1_proposed.asm` over
`src/data/palettes1.asm`, re-run `tcg_verify.py`, then build with `./build.sh`
and test in mGBA.
