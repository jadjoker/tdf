# Murmuration — Steam Publishing Runbook

Everything needed to go from this repo to a live Steam page. Items marked
**[YOU]** require the developer's identity/accounts/money and cannot be automated.

---

## 1. Account & app setup — [YOU], do once

- [ ] Create a Steamworks partner account: https://partner.steamgames.com/newpartner
      (legal name, address; sole proprietorship under your own name is fine)
- [ ] Pay the **$100 app fee** (recoupable after $1,000 gross revenue)
- [ ] Complete the **tax interview** (W-9 for US) and **bank details** —
      the store page cannot go live before these clear
- [ ] Create the app → note the **AppID** and the auto-created **depot IDs**
- [ ] Fill AppID + depot IDs into `steam/app_build.vdf`

Timeline: identity/tax verification typically takes **2–5 business days**.

## 2. Technical readiness — status in this repo

| Requirement | Status |
|---|---|
| Windows x86_64 build | ✅ `export_presets.cfg` preset "Windows" → `build/windows/murmuration.exe` (single file, PCK embedded) |
| Linux x86_64 build (serves Steam Deck) | ✅ preset "Linux (Steam Deck)" → `build/linux/murmuration.x86_64` |
| Export templates 4.4.1 installed | ✅ (this machine) |
| Game icon (window/taskbar) | ✅ `icon.svg` — murmuration swirl, original art |
| Windows .exe embedded icon | ⬜ needs **rcedit** (free tool) configured in Godot editor settings + an .ico; cosmetic, not blocking |
| Version number | ✅ `application/config/version`, shown on menu (bump per release) |
| Controller + Deck support | ✅ full pass done; pointer steering covers trackpad/touch |
| Settings / pause / quit | ✅ |
| Save location (for Steam Cloud) | `user://` → configure **Steam Auto-Cloud** for the app_userdata path; file: `save.cfg` |
| All assets original / license-clean | ✅ 100% procedural code + script-generated audio |
| Steamworks SDK (achievements, rich presence) | ⬜ optional at launch — overlay works without it; add **GodotSteam** later if achievements wanted |

Export commands (headless, from repo root):

    Godot_v4.4.1-stable_win64_console.exe --headless --export-release "Windows" build/windows/murmuration.exe
    Godot_v4.4.1-stable_win64_console.exe --headless --export-release "Linux (Steam Deck)" build/linux/murmuration.x86_64

## 3. Build upload (SteamPipe) — after step 1

1. Download **steamcmd**: https://developer.valvesoftware.com/wiki/SteamCMD
2. Export both builds (commands above)
3. Upload:

       steamcmd +login YOUR_STEAM_LOGIN +run_app_build ..\path\to\steam\app_build.vdf +quit

4. On partner site → App → SteamPipe → Builds: set the uploaded build live
   on the **default** branch
5. Install the game through Steam yourself and verify it launches on both OSes

## 4. Store page assets — required before "Coming Soon"

All uploaded on the partner site. Exact sizes enforced:

| Asset | Size | Notes |
|---|---|---|
| Header capsule | 460×215 | main search/browse image |
| Small capsule | 231×87 | lists/recommendations |
| Main capsule | 616×353 | front-page features |
| Vertical capsule | 374×448 | seasonal sales layout |
| Library capsule | 600×900 | user's library grid |
| Library hero | 3840×1240 | library page banner |
| Library logo | 1280×720 transparent PNG | overlaid on hero |
| Screenshots | 1920×1080, **min 5** | ✅ generated set in `steam_assets/screenshots/` — refresh before launch |
| Trailer | 1920×1080+, mp4 upload | cut from gameplay recordings; needed for meaningful traffic |
| Client icon | 32×32 .ico + community icon 184×184 .jpg | derive from icon.svg |

**Capsule art is the one strongly-recommended artist purchase** — it's the
game's face in every Steam list. Text on capsules must be readable at small size.

Also required for the page: short description (~300 chars), long description,
genre tags (Action, Arcade, Roguelite…), content survey (no mature content →
straightforward), system requirements (modest: any Vulkan-capable GPU).

## 5. Launch sequence

- [ ] Page submitted for review (human review, ~2–5 business days)
- [ ] Page live as **"Coming Soon"** — must be up **at least 2 weeks** before launch
      (realistically: months, to accumulate wishlists)
- [ ] Free **demo** as its own app when v0.5 exists (own AppID, no fee for demos)
- [ ] **Steam Next Fest** registration (one entry per game, time it 1–2 months pre-launch)
- [ ] Build review for launch (automated + spot checks)
- [ ] Price: $4.99 (launch discount 10–15% recommended)
- [ ] Steam Deck compatibility review happens automatically post-launch;
      native Linux build + full controller support = strong Verified candidate

## 6. Ongoing

- Bump `application/config/version` every upload; tag releases in git
- Steam Cloud on from day one (players expect it)
- Wishlist emails go out automatically at launch — the payoff for the early page
