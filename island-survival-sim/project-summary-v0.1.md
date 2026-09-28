# Island Survival Life Sim — Project Summary v0.1

*Working title TBD. Pieced together from `project_overview.md` (Gemini chat) and creator notes, 2026-09-28.*

---

## 1. The Pitch (one paragraph)

A 4K stereoscopic (3D side-by-side) life simulator built in Unreal Engine 5. It opens with a
plane hijacking at night: your spouse straps a parachute on you and shoves you out the hatch
seconds before the plane explodes. You free-fall over moonlit ocean, get the chute on, and
wash up on an unknown tropical island. Other real players wash up too. Some hijackers
survived and are hunting witnesses. You find a way off the island — and **that's only the
beta**. The real game starts 7 months later, back in civilization, living the life that
your character and your rescue path set up.

---

## 2. Game Structure

| Act | What happens | Status |
| :--- | :--- | :--- |
| **Cold open** | Hijacking → spouse's sacrifice → pushed out the hatch → plane bursts into flames → free-fall, put on chute mid-air → ocean in every direction, moon on the water. | Concept |
| **Act 1: The Island** *(beta / prologue)* | Survival sandbox. Other real players wash ashore in real time. Possible hijacker survivors searching for witnesses (threat + mystery). Multiple ways to escape. | Concept |
| **Time skip** | 7 months pass. | Concept |
| **Act 2: Return to Life** *(main game)* | Life sim. **Where you live** depends on (a) which character you picked and (b) how you were rescued. | Concept |

### Return-to-life destinations (from the overview doc)
- Urban City Apartment
- Wilderness Forest Cabin
- Rural Farmhouse

These load as separate maps (UE5 level streaming) after the island.

---

## 3. Story Hooks Worth Keeping

- **The spouse** — saved you, then vanished. Alive? Dead? Involved? Natural thread into Act 2.
- **The hijackers** — why did they take the plane? Why hunt witnesses? Can follow you home.
- **Other survivors** — real players. Ally, trade, betray, or escape together.
- **Rescue path = your future** — the escape choice isn't just an ending, it's your character creator for Act 2.

---

## 4. Tech Plan (from overview doc)

| Area | Choice |
| :--- | :--- |
| Engine | Unreal Engine 5 |
| Output | 4K Side-by-Side stereoscopic (VR / 3D displays) |
| Multiplayer | Single-player + co-op peer-to-peer (P2P) |
| Matchmaking | Epic Online Services (EOS) — free |
| Hosting cost | $0 base (players' own machines do the work) |
| Characters | Daz 3D Genesis 9 → Blender (sculpt, no vertex changes) → UE5 |
| Skin detail | SKAP 16K face maps, TexturingXYZ alphas, tiled MicroSkin, baked UDIM normals |
| Runtime tricks | Virtual Texturing (hi-res only when close); Hemoglobin/Melanin maps drive blushing, pale/sick states |

### Character cost (first character)
~**$160–$240**. Later characters ~**$55** each (skin maps are reusable).

---

## 5. Shared Assets With Other Projects

| Project | Overlap |
| :--- | :--- |
| **Life Forge Sim** | Same life-sim DNA — Act 2 is basically this. Share character pipeline + life systems. |
| **Pokémon-style photo game** | Same tropical island. **Build the island once, use it in both games.** |
| **Everwell Wilds demo** (`Blender-automation/demo`) | Already has a 4-biome island (beach, forest, meadow, highlands) + ocean + day/night. Useful as a blockout reference. |

---

## 6. Open Questions / Gaps

1. **Real players washing up "in real time" vs. P2P co-op.** P2P works for friends in a
   private session. Strangers joining a shared island live usually needs a host that stays
   online (dedicated server = monthly cost). Decide which one you actually want.
2. **Beta scope** — is the island a free demo, early access, or a paid prologue?
3. **How many playable characters** at launch, and what makes each one different?
4. **Escape routes** — list them (raft, signal fire, boat, hijackers' vessel, rescue plane…)
   and map each to an Act 2 destination.
5. **The 7-month gap** — played, cutscene, or flashbacks during Act 2?
6. **Stereoscopic 4K cost** — rendering two 4K views is heavy; set a target GPU early.
7. **Mature content** — the character pipeline includes adult features; this sets the age
   rating and which stores can sell it. Decide early.

---

## 7. Suggested Next Steps

1. Lock the island layout (shared with the photo game).
2. Storyboard the cold open (it's the trailer).
3. Write the escape-route → destination table.
4. Build one character through the full Daz → Blender → UE5 pipeline as a test.
5. Prototype P2P co-op on the island with EOS before promising "real-time strangers."
