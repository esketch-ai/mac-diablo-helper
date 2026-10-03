<p align="center">
  <img src="dm_helper_logo.png" width="130" height="130" alt="DM_Helper Logo" style="border-radius: 26px; box-shadow: 0 8px 24px rgba(0,0,0,0.3);"/><br/>
  <h1 align="center">DM_Helper (Diablo Mac &amp; Windows Helper)</h1>
  <p align="center"><b>Native Precision Gaming Helper for Diablo 4 &amp; 3 on macOS &amp; Windows 11</b><br/>
  <i>Apple Silicon &amp; Intel · Windows x64</i></p>
  <p align="center">
    <b><a href="README.md">🇰🇷 한국어 (Korean)</a></b> | <b><a href="README_EN.md">🇺🇸 English</a></b>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/platform-macOS%2010.13+%20|%20Windows%2011-brightgreen.svg" alt="Platform"/>
    <img src="https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel%20%7C%20x64-blue.svg" alt="Architecture"/>
    <img src="https://img.shields.io/badge/languages-English%20|%20Korean-blueviolet.svg" alt="Languages"/>
    <img src="https://img.shields.io/badge/version-1.5-orange.svg" alt="Version"/>
    <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"/>
  </p>
</p>

---

> ## 🪟 Windows 11
>
> **[⬇️ Beta download](https://github.com/esketch-ai/mac-diablo-helper/releases/download/v1.6.0-beta.1/DM_Helper-1.6.0-beta.1-windows-x64.zip)**
> Unzip it and run `DM_Helper.exe` **as administrator**. No installer required.
>
> **This is a pre-release.** The build and tests pass, but behaviour in Diablo 4 is
> unconfirmed. Run `DM_Helper_Spike.exe` from the same folder first.
>
> | | |
> |---|---|
> | Status | Pre-release — awaiting hardware verification |
> | Administrator | **Required** — injection is blocked below the game's privilege level |
> | Requirements | Windows 11 x64, no separate install for the app |
> | Details | [win/README.md](win/README.md) |

---

> This project originated as a fork of [sunghyuk/D3-Skill-Assistant](https://github.com/sunghyuk/D3-Skill-Assistant).  
> It faithfully reimagines Windows **[DHelper](https://www.dhelper.co.kr/2021/01/iii.html)** on macOS, bringing all classic convenience features (Special Keys, Single Repeat Keys, Quest Key, Speed Modifier Key, In-Game 8 UI auto-pause, Mouse Wheel/Side buttons).  
> Furthermore, it introduces **modern Diablo 4 tailored mechanisms** (Opener & Ramp-up Buff Sequence, Generator-to-Spender Combo Cycles, Channeling Hold Mode, and Google Sheets Cloud Preset Hub).

👉 **For detailed instructions and deep-dive explanations, refer to [📖 Complete User Manual (MANUAL.md)](MANUAL.md).**

---

<p align="center">
  <img src="03_screen_en.png?raw=true" alt="DM_Helper English Interface" width="850"/>
</p>

---

## ⚡️ 3-Minute Quick Start

```
[1. Launch App] ──▶ [2. Apply Class Preset] ──▶ [3. Press '[' In-Game]
                        (e.g., Warlock)             (Hunt with full auto!)
```

1. **Launch App & Grant Permission**:
   - On first launch, grant permission in `System Settings > Privacy & Security > Accessibility`.
2. **Apply One-Click Class Preset**:
   - In the top bar dropdown, select **Warlock (Fiery Scream)**, **Sorcerer**, **Barbarian**, **Rogue**, etc.
3. **Start In-Game**:
   - Switch to Diablo 4 (or 3) and press **`[` (Left Bracket)**.
   - An audible chime (`Tink`) plays, and status switches to **`● Running`**, running the opener sequence before transitioning into the main combat loop!
   - Press **`[`** again to stop (`Pop` chime).

---

## 🎮 D4 Class Presets (One-Click Ready)

| Class / Build | Core Mechanism | Pre-configured Settings |
|---|---|---|
| 🔥 **Warlock**<br/>(Fiery Scream) | **The Pit 150 Autobomber**<br/>Summon → Metamorphosis Dominance buff → Dark Prison CC → Continuous Fiery Scream spam | • **Opener**: Summon Abodian → Metamorphosis → Dark Prison → Seal Buff<br/>• **Main Loop**: Maintain Metamorphosis/Prison on cooldown + Right Click (Fiery Scream) 120ms high-speed spam |
| 🔮 **Sorcerer**<br/>(Lightning Spear / Tal Rasha) | **Barrier & 4-Element Tal Rasha Stack Build-Up** | • **Opener**: Ice Armor → Teleport → Lightning Spear → 3x Basic stack<br/>• **Main Loop**: Maintain Barrier/Teleport on cooldown + auto-rotate core skills |
| ⚔️ **Barbarian**<br/>(Whirlwind Channeling) | **3 Shouts Fury Burst & Continuous Whirlwind (Hold)** | • **Opener**: Rallying Cry → Challenging Shout → War Cry in sequence<br/>• **Main Loop**: Maintain shouts on cooldown + **Right Click (Whirlwind) [Hold (Channel)] mode** |
| 🏹 **Rogue**<br/>(3 Combo Points) | **3 Combo Points (Puncture x3) → Twisting Blades x1 Cycle** | • **Opener**: Shadow Imbuement → Shadow Step engage<br/>• **Combo Loop**: Generator (Key 3) 3 hits ↔ Spender (Right Click) 1 hit auto-alternate |
| 💀 **Necromancer**<br/>(Bone Spear & Corpse Expl.) | **Golem/Decrepify CC & Bone Spear / Corpse Burst** | • **Opener**: Golem active → Decrepify curse → Corpse Tendrils<br/>• **Main Loop**: Bone Spear (200ms) + Corpse Explosion (120ms) rapid spam |
| 🦅 **Spiritborn**<br/>(Aspect & Overpower) | **Stance Buff & Resolve Stack Overpower Cycle** | • **Opener**: Stance buff → Resolve stack accumulation<br/>• **Combo Loop**: Feather throw 3 hits ↔ Overpower skill 1 hit alternating |

---

## 💎 Features & 3-Tab Interface

### Tab 1: Basic Helper
<p align="center">
  <img src="03_screen_tab1_en.png?raw=true" alt="Tab 1: Basic Helper" width="850"/>
</p>

- **Start / Stop & Opener Keys**: Supports one-touch toggle (`[`) or separate stop key. You can also configure opener trigger key and toggle directly from the main header.
- **Skill 1~8 Slots**: Full support for Keyboard keys, Mouse Wheel (Up / Down), Middle Click, and Side Buttons (XButton 1 / 2).
- **Cast Modes (Spam vs Hold)**:
  - Instant spam for cooldown/burst skills.
  - **Hold (Channeling) Mode** for continuous skills like Barbarian Whirlwind or Sorcerer Incinerate.
- **Special Keys (Up to 3)**: Temporarily pause checked skills while holding key, with an option to wait for cooldown or fire immediately upon release.
- **In-Game UI Pause Keys (8 shortcuts)**: Automatically suspends the helper whenever you open Inventory (`I`), Skill Tree (`S`), Follower (`F`), Map (`M`), World Map (`Tab`), Town Portal (`T`), Chat (`Enter`), or Whisper (`R`).

---

### 🌐 Google Sheets Preset Hub (`[ 🌐 Sheet... ]`)
- **Real-Time Cloud Preset Sync**: Browse official and user-shared community builds by author, season (Season 6, 7, Eternal, etc.), and class.
- **One-Click Import**: Pick any build and target slot (1~5) to instantly load it into your helper.
- **Share Your Build & Copy TSV Row**: Share your custom configuration with the community or copy TSV row data for direct `Cmd + V` paste into Google Sheets.
- **Clan / Private Sheet Support**: Point to your guild's private Google Sheet URL or Apps Script Web App for team-only presets.

---

### Tab 2: Rotation & Opener
<p align="center">
  <img src="03_screen_tab2_en.png?raw=true" alt="Tab 2: Rotation & Opener" width="850"/>
</p>

- **Opener & Ramp-up Sequence**:
  - Automatically executes up to 5 sequential buff/summon/stack stages upon starting (or via manual `F1` / header `⚡️ Opener` button) before seamlessly transitioning into the main combat loop.
- **Skill Combo Cycle (Generator-to-Spender)**:
  - Precise alternating timer that hits Generator A for `N` times to build stacks/resources, then unleashes Core Spender B for `M` times (e.g., Rogue 3:1 ratio).

---

### Tab 3: Single Repeat & Utility
<p align="center">
  <img src="03_screen_tab3_en.png?raw=true" alt="Tab 3: Single Repeat & Utility" width="850"/>
</p>

- **Single Repeat Keys (Independent loops while held)**:
  - `~` (Grave): 50ms Mouse Left Click (Lightning item & gem looting from ground).
  - `Tab`: 60ms Mouse Right Click (Kadala & vendor bulk gambling in seconds).
- **Quest Key**: Completely suspends all skill actions while held to prevent accidental dialogue closure during NPC interactions.
- **Speed Modifier Key (Pylon Toggle)**: Speed up or slow down all timers by a set offset (ms) when grabbing a Channeling or Conduit pylon.
- **Anti-Disturbance Deadzone Filter**: Automatically skips simulated left clicks whenever your mouse cursor hovers over the bottom skillbar, health/resource orbs, or minimap to avoid UI misclicks.

---

### 🌐 Real-Time Bilingual Localization (English & Korean)
- **Instant One-Click Switch**: Change language anytime via the top-bar dropdown (`🌐 EN` / `🌐 KO` / `🌐 Auto`) or macOS Menu Bar (Status Item).
- **100% Non-Destructive**: Switching language immediately updates the UI without restarting the app, preserving all active key bindings, intervals, memos, and checkbox states.
- **Full Coverage**:
  - Main Window (Top bar, all 3 tabs, tooltips, and explanatory notes)
  - In-App Help & Guide Window (`Cmd + ?`) with complete dual HTML manuals
  - Google Sheets Preset Hub & English class preset names (`Warlock`, `Sorcerer`, `Barbarian`, `Rogue`, `Necromancer`, `Spiritborn`)
- **System Language Auto-Detection**: Launches in English on English macOS systems, and Korean on Korean systems.

---

## 🛠 Installation & Accessibility Permissions

DM_Helper requires macOS Accessibility permissions to monitor hotkeys and dispatch game events.

1. Launch **DM_Helper**.
2. Go to **System Settings > Privacy & Security > Accessibility**.
3. Toggle the switch to **ON** for `DM_Helper`.
4. The helper activates immediately (no app restart required).

> [!TIP]
> If macOS updates or app re-installation breaks accessibility, remove `DM_Helper` from the list with the **`(-)`** button and re-add it with the **`(+)`** button.

---

## 📦 Download

A single tag carries builds for both platforms; the OS is named in each filename.

### macOS

- **[Download Latest v1.5 (dm_helper-1.5.zip)](https://github.com/esketch-ai/mac-diablo-helper/releases/download/v1.5/dm_helper-1.5.zip)** — macOS 10.13+ (Apple Silicon & Intel Universal)
- [v1.3 Release](https://github.com/esketch-ai/mac-diablo-helper/releases/download/1.3/d3d4a-1.3.zip)
- [Original v1.2 Repository](https://github.com/sunghyuk/D3-Skill-Assistant/releases/download/1.2/d3a-1.2.zip)

After installing, grant the app permission under
**System Settings > Privacy & Security > Accessibility**.

### Windows 11

> **[⬇️ Download Windows 11 beta (v1.6.0-beta.1)](https://github.com/esketch-ai/mac-diablo-helper/releases/download/v1.6.0-beta.1/DM_Helper-1.6.0-beta.1-windows-x64.zip)**
> Unzip it and run `DM_Helper.exe` **as administrator**. No installer required.

**This is a pre-release.** The build passes and all 162 unit tests pass, but it has not
been confirmed working in Diablo 4 yet. If input injection is blocked, the app runs
normally while the macro silently does nothing.

**Run `DM_Helper_Spike.exe` from the same folder first, as administrator.** It checks nine
things and reports PASS/FAIL. We recommend this before the app.

| | |
|---|---|
| Status | Pre-release — awaiting hardware verification |
| Administrator | **Required** — injection is blocked below the game's privilege level |
| Requirements | Windows 11 x64. No separate install for the app |
| Spike tool | Needs the .NET 8 runtime ([download](https://dotnet.microsoft.com/download/dotnet/8.0)) |
| Details | [win/README.md](win/README.md) |

If it does not work, please open an [Issue](https://github.com/esketch-ai/mac-diablo-helper/issues)
and include the results of **check 1 (elevation)** and **check 6 (hook capture)**.

<details>
<summary>Building it yourself</summary>

You need the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0):

```bash
cd win
dotnet publish src/DM_Helper.Wpf -c Release -r win-x64
```

</details>

---

## 📝 Release Notes

### v1.5 (Rebranding, Cloud Preset Hub, Full Bilingual Localization & Ultimate Stability)
- **Brand Rebranding**: Rebranded to **DM_Helper (Diablo Mac Helper)** with new high-resolution retina icon (1024x1024) and menu bar icon.
- **Full English & Korean Bilingual Support**:
  - `D3LocalizationManager` with system language auto-detection and real-time one-click switching.
  - Zero loss of user configuration during instant live UI rebuilds.
  - Complete English manuals and dual HTML in-app guide.
- **Header Opener Controls**: Added Opener trigger key and Enable toggle directly in the main header bar.
- **Google Sheets Preset Hub**:
  - Real-time cloud preset search by author, season, and class.
  - One-click slot loading, preset sharing, and clipboard TSV export.
- **Single Repeat & Key Field Hardening**:
  - Fixed unintentional key resets and focus release anomalies.
  - Added full support for clearing keys via `ESC`, `Delete`, or right-click context menu.
- **18 Unit Tests Passing 100%**: Regression prevention covering input serialization, localization, opener step workflows, and safety deadzones.

---

## 📄 License

MIT License. Diablo III and Diablo IV are registered trademarks of Blizzard Entertainment, Inc. This project is not affiliated with or endorsed by Blizzard Entertainment.
