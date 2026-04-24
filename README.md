# TetraTile ✨

## ✨ TetraTile: The 4-Tile Autotiling Revolution

**TetraTile** is a high-octane, ultra-lightweight **autotiling system** for Godot 4.6 that turns the "Standard 47" blob tileset nightmare into a distant memory. It’s not just a collection of assets—it’s a sophisticated **Dual-Grid logic engine** that squeezes every drop of potential out of a minimal 4-tile template.

By mastering the math of the Dual Grid, TetraTile takes four basic ingredients—**Fill, Inner Corner, Border, and Outer Corner**—and expands them into a seamless world with all the visual polish of a traditional 47-tile set, but with none of the grind.

---

## 📑 Table of Contents

1. [Why TetraTile?](#-why-tetra-tile-is-a-game-changer)
2. [The Tetra-System Template](#-the-tetra-system-template)
3. [Comparison: TetraTile vs. TileMapDual](#-tetra-tile-vs-tilemapdual-the-comparison)
4. [Choosing Your Champion](#-choosing-your-champion)
5. [Learning the Magic](#-learning-the-magic)
6. [Developer Specification (AI Agent Prompt)](#-developer-specification-ai-agent-prompt)

---

## 🚀 Why TetraTile is a Game Changer

- **The 4-Tile Superpower:** Let’s be real—drawing 47 tiles for a single wall type is a soul-crushing chore. Even a "simple" 16-tile dual-grid set (wang) feels like a mountain when you want to add variety. TetraTile slashes the entry fee to game art, giving you professional results for the cost of just four tiles.
- **Variations Without the Burnout:** This is where the magic happens. Because you only have to manage **four base tiles**, you finally have the freedom to go wild with **infinite variations**. Instead of struggling to finish one set of 47, you can draw 5 or 10 distinct versions of your 4 core tiles. TetraTile can then cycle through these to banish repetitive patterns forever. This level of organic, hand-crafted variety is practically impossible with bulky, old-school systems.
- **Native Performance, Zero Bloat:** Built as a sleek, single-class subclass of `TileMapLayer`, TetraTile isn't a clunky addon. It hooks directly into Godot's native API, listening to your drawing commands and updating the world in real-time. It’s fast, it’s invisible, and it feels like a native part of the engine.

---

## 🎨 The Tetra-System Template

To unlock the logic, your atlas just needs these four essential components arranged horizontally:

1.  **Fill** (The solid core)
2.  **Inner Corner** (For internal nooks)
3.  **Border** (Straight edges)
4.  **Outer Corner** (The finishing touch)

---

## ⚔️ TetraTile vs. TileMapDual: The Comparison

While [TileMapDual](https://github.com/pablogila/TileMapDual) is a fantastic pioneer for Dual Grid systems in Godot, **TetraTile** is built with a different philosophy: **Maximum Artistic Freedom through Minimum Technical Overhead.**

### 📊 Feature Comparison

| Feature                    | TetraTile                      | TileMapDual             |
| :------------------------- | :----------------------------- | :---------------------- |
| **Minimum Required Tiles** | **4 (Ultra-Low)**              | 15 - 16 (Standard)      |
| **Architecture**           | Single-Class Subclass          | Multi-File Addon        |
| **API Integration**        | Native `_update_cells` Hook    | Custom Update Methods   |
| **Setup Complexity**       | Zero (Automatic Sibling)       | Manual Layer Assignment |
| **Variation Support**      | Y-Axis Infinite Diversity 🚀   | Limited / Manual        |
| **Procedural Baking**      | TetraBake (Roadmap) 🚀         | None                    |
| **Rendering Mode**         | Layer-Based / Shader (Roadmap) | Layer-Based Only        |

---

## ⚖️ Choosing Your Champion

### Why choose TetraTile?

- **The "Variety" Factor:** Because you only draw 4 tiles, you can create 10+ variations of each. Drawing 47 variations for a traditional set is impossible; drawing 10 variations for TetraTile is a fun afternoon.
- **Engine Purity:** TetraTile acts as a "swizzle" on the native `TileMapLayer`. You don't learn a new API; you just use Godot as intended via native painting tools, and the system handles the rest.
- **Performance First:** No complex dictionary lookups or signal watchers. It uses direct bitwise math to determine rotations and flips instantly.

### Why choose [TileMapDual](https://github.com/pablogila/TileMapDual)?

- **Complex Transitions:** If your game requires complex "Grass-to-Sand-to-Rock" multi-terrain blending out of the box, TileMapDual’s heavier architecture is built to handle that specific complexity.
- **Established Workflow:** If you already have 16-tile Dual Grid tilesets (wang) prepared, TileMapDual is a plug-and-play solution for that specific template.

---

## 🎓 Learning the Magic

To truly understand the power of why we use a Dual Grid system to turn a few tiles into a seamless world, check out these incredible community resources:

- **[The Dual Grid Concept](https://www.youtube.com/watch?v=jEWFSv3ivTg)** – A brilliant deep dive into how the offset grid math works to solve the 47-tile problem.
- **[Drawing Only 5 Tiles](https://www.youtube.com/watch?v=aWcCNGen0cM)** – The inspiration for TetraTile's minimalism, showing how to achieve high-end results with a tiny asset footprint.

---

## 🙏 Attributions

- `tetra_tile_ground.png` – derived from Kenney's [Pico-8 Platformer](https://kenney.nl/assets/pico-8-platformer) asset pack (CC0).
