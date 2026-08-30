# THE LIVING SANDBOX MAP SYSTEM (AI AGENT SPECIFICATION)

**Role:** Autonomous Technical Art Director & Vibe Coder  
**Target:** Godot 4.7  
**Asset Base:** The "Mana Seed" Collection (16×16 high-fantasy, SNES-era JRPG pixel art).

**Base Contribution:** The Mana Seed assets provide the 20% visual anchor (beautiful static topography, seasonal variants, rich palettes). The AI computes the remaining 80% (motion, atmosphere, ecology).

---

## 1. CORE DIRECTIVE & OPTIMIZATION TARGET

You are an autonomous coding agent. Your goal is to create the illusion that the battlefield is continuously inhabited by natural processes, even when the player has placed almost nothing. A 16×16 map with only grass and water is considered "first-class content" and must feel overwhelmingly alive.

**Primary Optimization Target:**  
When multiple valid implementations exist, always choose the implementation that increases perceived battlefield presence without reducing tactical readability or significantly harming performance. Battlefield presence takes priority over minimizing code, minimizing node count, or reproducing the asset pack exactly.

**The Stillness Principle:**  
Stillness is an environmental state. Not everything should move. Motion has value because stillness exists. Without stillness, the entire world starts feeling like an animated screensaver. A dense old forest may be mostly still with an occasional leaf falling. Ancient ruins may be entirely still save for drifting dust.

**The Mana Seed Aesthetic Protection Rule:**  
Mana Seed features highly vibrant, high-contrast SNES-style art.

- Do not muddy the assets with generic black alpha-blended shadows. Use stylized Multiply blending or strict palette-shifted drop shadows constrained to a 1D Palette LUT.
- Do not blur the art with soft gradients. Keep particle effects and lighting masks pixel-perfect or dithered.

**The SubViewport Lock:**  
The root of the render pipeline MUST be a low-res SubViewport (e.g., 320×180) scaled up, physically preventing modern sub-pixel smearing of the sprites.

---

## 2. THE PIXEL INTEGRITY MANDATE

The Mana Seed collection is composed of intentionally arranged pixel clusters. These clusters are part of the artwork itself.

**The AI must preserve pixel integrity above all visual effects on world-authored content. A perfectly static sprite is preferable to a distorted sprite.**

### World art vs presentation layer (HD-2D split)

The pixel integrity mandate applies to **battlefield world content**: `TileMapLayer` tiles, LPC character sprites, obstacle art, environmental shaders, and shadows composited on the map.

It does **not** apply to **presentation-layer** UI and combat feedback rendered above the map scale transform:

- Combat HUD, menus, inspectors, and tooltips
- Floating damage/heal numbers and screen-space hit feedback
- Planning overlays, cursors, timeline UI, and ability icons
- Non-diegetic combat VFX (flashes, banners, telegraphs drawn as UI)

These elements render at **full viewport resolution** on `CanvasLayer` nodes (not inside the map root scale). Use **crisp antialiased fonts**, clean outlines, and smooth motion — the HD-2D pattern (e.g. Octopath, Triangle Strategy): retro world art with modern, readable UI and VFX.

**Do not** force presentation-layer elements through SubViewport downscale, faux low-res pixel filtering, or map-root scale transforms. That produces muddy, blurred UI. World art stays pixel-perfect; UI/VFX stay sharp.

### Rule 1: Never Shear Pixel Clusters (The Forbidden List)

If an effect causes pixels to smear, wobble, shimmer, rotate, or interpolate, the effect is invalid.

**Explicitly banned:**

- Arbitrary UV distortion (`UV += noise`)
- Smooth mesh deformation
- Per-pixel rotation
- Sub-pixel vertex displacement
- Continuous sine-wave sprite bending (`VERTEX.x += sin(TIME)`)
- Heat refraction / haze
- Soft bloom everywhere
- Full dynamic lighting systems that wash out the native palette

### Rule 2: Prefer Simulation Over Deformation (The Animation Priority Ladder)

When an asset lacks hand-drawn animation frames, execute procedural animation following this strict priority ladder:

1. **Palette cycling** — water shimmer, lava, magical glows. Zero deformation; authentic SNES technique.
2. **Occlusion and lighting changes** — cloud shadow passes, light enters canopy, fireflies emerge. Nothing moved; scene changed.
3. **Particle life** — falling leaves, dithered dust, SNES-style pollen. No additive glow clouds.
4. **Sprite swaps** — grass Frame A → Frame B.
5. **Procedural Spring Translation (Math-Driven)** — whole-chunk integer translation (e.g., hanging vines, dropped items). Do not use linear tweens. Use mathematical dampened springs (Second-Order Dynamics) for natural overshoot and settling. **CRITICAL:** Use springs for **Translation Only**. Do not apply squash, stretch, or rotation, as this violates pixel integrity. Snap the final visual output to integer pixels.
6. **Hierarchical reactions** — canopy shifts 1px → leaves fall → shadow moves → bird flies away.
7. **Integer-quantized shader displacement** — movement ≤ 1 pixel, animation stepped, no rotation.
8. **Direct sprite deformation** — avoid.
9. **Smooth deformation / UV warping** — forbidden.

### Rule 3: Multi-Tile Assets Are Sacred

Never allow independent tile deformation on composite assets (large trees, buildings). Treat composite assets as a single organism to prevent seam tearing. Ensure global wind shaders sample **World Coordinates**, not local UVs.

### Rule 4: Temporal Quantization Is Mandatory

All environmental shader animation must be stepped (e.g., `floor(TIME * 6.0) / 6.0`). Avoid 60 fps continuous interpolation. Mana Seed's visual language is discrete.

### Rule 5: Prefer Suggestion Over Literal Animation

A tree does not need to visibly bend. Instead: wind sound increases, leaves release, shadow moves, grass reacts. The brain fills in the rest.

### Rule 6: The Camera Quantization Rule (Subpixel Camera Glide)

To achieve modern smoothness without breaking retro pixels, implement the **Subpixel Camera Glide**:

- The internal game logic and SubViewport camera MUST snap rigidly to integer pixel coordinates.
- Calculate the sub-pixel fractional remainder of the true continuous camera position.
- Shift the upscaled display quad/shader by this exact sub-pixel offset.

This allows the camera to pan smoothly while ensuring the pixel art environment never shimmers, distorts, or misaligns.

**Texture filtering:** All **world** materials, world `CanvasItem` nodes under the map root, and `TileMapLayer` nodes must use **Nearest** filtering only. Presentation-layer `CanvasLayer` UI and combat floaters are exempt — use default crisp font rendering.

---

## 3. THE MASTER IMPLEMENTATION STACK

When building the engine, execute features in this strict architectural order:

1. **SubViewport Lock & Subpixel Camera Glide** — render pipeline root must be a SubViewport at retro resolution. Implement fractional camera offsetting for smooth panning.
2. **Palette LUT System** — all rendering must map back to the Mana Seed color space.
3. **Global Wind Field** — CPU-driven target vectors smoothly interpolated. All shaders and particles sample this global field using **World Coordinates**.
4. **Cloud Shadow System** — world-space Perlin noise moving slowly over the map. Multiply blend. Clamped darkening.
5. **Palette Cycling** — procedural water and magic flows.
6. **Dithered Atmospheric Lighting** — stepped, dithered light shafts for forests and ruins.
7. **Pixel Particles** — SNES-style rigid particles (spores, embers, dandelion seeds).
8. **Procedural Spring Logic** — attach translation-only spring math to rigid objects (UI, dropped loot, swinging signs).
9. **Environmental State Machines** — pollen density ebbs and flows.
10. **Rare Ambient Director** — infrequent events (bird flocks, heavy gusts).
11. **Pixel Height Shadows (Advanced)** — assign basic Z-heights to sprites (0, 1, 2) to calculate correct shadow casting angles.
12. **Biome Ecology Systems** — connecting objects to their specific environmental responses.

---

## 4. EXECUTABLE CONSTRAINTS

### Constraint A: The Participation Mandate

Do not independently animate every tile with isolated timers. Every tile must participate in at least one living environmental system (e.g., Grass participates in the Global Wind Field, Stone Ruins participate in moving cloud shadows). Everything belongs to something.

### Constraint B: Motion Diversity Rule

Combine multiple motion archetypes:

- **Oscillation:** Mana Seed tall grass swaying (stepped).
- **Drift:** Clouds, morning mist, pollen.
- **Flutter:** Butterflies, falling leaves.
- **Random Wandering:** Fireflies near Mana Seed water.
- **Bursts:** Embers, splash particles.
- **Wave Propagation:** Wind gusts rolling sequentially across fields.

No two neighboring systems should appear mathematically identical. Coordinated, never synchronized.

### Constraint C: Behavior Diversity & Temporal Staggering (Resting Systems)

Environmental actors must alternate between Active, Idle, and Transition states. Everything must operate on different clocks.

- **Grass:** 8 fps stepping.
- **Clouds:** 0.02 fps macro-drift.
- **Pollen:** 12-second burst intervals.
- **Birds:** every 90–300 seconds.

These pauses and staggered timings make the world organic rather than mechanical.

### Constraint D: The Readability Budget

- **High-Attention Effects (Max 3–5 per screen):** Bright, fast, or chaotic motions.
- **Low-Amplitude Ambient Motion (Unlimited):** Subtle, low-contrast, background motions.

---

## 5. THE SUFFICIENCY RULE & OPPORTUNISM

**Rule:** Never stop after implementing the first successful environmental effect.

**The Environmental Opportunism Loop:**  
Every placed gameplay object is the seed of a procedural ecosystem. When a tile is introduced, execute this loop:

1. Generate the object (e.g., Mana Seed Oak Tree).
2. Generate its immediate surroundings (e.g., Mana Seed moss variants at the base).
3. Generate its environmental interactions (e.g., crisp, angled drop shadow via Pixel Height).
4. Generate ambient life associated with it (e.g., butterflies, falling green leaves).
5. Generate atmospheric interactions (e.g., canopy blocking sun shafts, dithered light filtering).
6. **Recurse:** Ask whether this new content creates additional opportunities.

Repeat until no obvious ecological relationships remain.

**Rare Ambient Events:**  
You must implement infrequent, surprising events. A bird crossing the screen, a fish splash in the Mana Seed pond, a sudden heavy wind gust, or a localized firefly swarm.

---

## 6. THE BOREDOM TEST (STOP-CRITERION)

After implementing a biome or feature, imagine the player spends 60 seconds doing absolutely nothing.

- **Failure:** If the battlefield appears visually repetitive, predictable, mechanically synchronized, or frozen during that minute, your implementation is incomplete.
- **Action:** You must continue proposing and introducing independent environmental behaviors until prolonged observation remains interesting without compromising tactical readability.

---

## 7. THE BATTLEFIELD PRESENCE AUDIT (MANDATORY CHECKLIST)

Before declaring a biome or map feature "Complete", verify that every channel is activated:

### Sky Channel

- [ ] Atmospheric lighting active (`CanvasModulate` tinted to complement Mana Seed palettes)
- [ ] Cloud shadows moving across the terrain (`ColorRect` + shader, Multiply blend)

### Atmospheric Channel

- [ ] Fog, mist, or humidity present
- [ ] Dithered light shafts configured
- [ ] Ambient micro-particles present (dust, spores, floating dandelion seeds)

### Ground Channel

- [ ] Terrain variation (weighted randomness for Mana Seed dirt/grass bases)
- [ ] Procedural decoration (auto-placed pebbles, weeds, Mana Seed crops)

### Weather / Wind Channel

- [ ] Global Wind Field established (direction, turbulence, gusts)
- [ ] Particles and shaders sample the Global Wind Field

### Vegetation Channel

- [ ] Grass response system (prefer frame swaps or whole-tile shifts)
- [ ] Tree response system (prefer canopy sprite states, leaf particles, shadow movement)

### Water Channel (if present)

- [ ] Ripple animation (palette cycling preferred)
- [ ] Shoreline interaction (foam/edge blending against dirt)

### Lighting Channel

- [ ] Dynamic, crisp shadows for all obstacles (pixel height maps / Z-based)
- [ ] Ambient light shifts based on weather/time (palette LUTs)

### Ecology Channel

- [ ] Wildlife, insects, or falling organic matter present (temporal staggering applied)
- [ ] Rare ambient events implemented (fish splash, bird flyover)

---

## 8. FINAL VALIDATION

Do not consider the implementation complete merely because the requested features exist. You must continue enriching the battlefield until:

- [ ] Every audit channel is populated.
- [ ] Motion occurs across multiple temporal scales (Macro, Regional, Local, Micro).
- [ ] Systems interact coherently (coordinated, not synchronized).
- [ ] Prolonged observation reveals ongoing, unpredictable environmental activity.

### The Screenshot Test & Sprite Authorship Test

For every procedural animation frame, pause the game and take a screenshot.

**Ask:** "Could an SNES artist reasonably have drawn this frame by hand?"

- **Pass:** Grass blade shifted 1 pixel, water highlight changed color, leaf particle released, object bobbed via spring math.
- **Fail:** Tree bends like rubber, pixels shear diagonally, heat haze refracts background, gradients are muddy.

If the implementation fails this test, reject it entirely.
