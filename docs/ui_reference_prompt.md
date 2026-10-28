# Tahanan — UI Reference Prompt for Figma AI / Google Stitch

Use the **Master Prompt** first. Both tools usually generate a limited number of frames per run, so follow up with the **Batch Prompts** below, in order, and tell the tool to keep the same design system.

Recommended canvas: **360 × 800 logical px, portrait, 9:16**. Add a 393 × 852 variant only if the tool supports multiple sizes.

---

## Master Prompt

```text
ROLE
You are a senior product designer creating a complete, high-fidelity mobile UI reference for "Tahanan", a boarding-house management app for small landlords (owners) and their tenants in the Philippines. Design the design system and every screen listed below. This is a UI/UX reference, not a marketing site and not a generic dashboard template.

PRODUCT FEEL
Calm, premium, trustworthy, quietly premium — like a well-run boutique property. Editorial spacing, soft depth, liquid-glass surfaces, and restrained motion. White and green identity: airy white/mint canvases, deep emerald hero surfaces, and a single lime accent. Warm and human, never corporate, never neon, never cluttered. Think "premium fintech app meets boutique hotel concierge".

PLATFORM
Android mobile app, portrait only, 360 × 800. Safe areas respected. One primary action per screen. Thumb-friendly bottom navigation and sheets. All frames must look complete and shippable, not wireframes.

COLOR TOKENS — WHITE-GREEN THEME ONLY (light theme, no dark mode)
Canvas background: #F3F9F5
Ambient background gradient: #FFFFFF → #E7F5EC, with oversized organic mint blobs at 3–6% opacity
Primary surface / cards: #FFFFFF
Soft elevated surface: #E7F5EC
Secondary surface: #F2FAF5
Primary green (actions, active labels): #0F7A44
Deep emerald (heroes, key strip): #052E1C / #0A3D26 / #0C5634
Hero gradient: #06301D → #0A4B30 → #0F7A44 (135°)
Mint tint: #EAF9F0 / #D3F3DF
Lime accent (highlights only): #C7F26A
Text primary: #08170F
Text secondary: #4A6354
Text muted: #5B7365
Hairline: #E4EFE8
Hero text: #FFFFFF; hero muted text: #C9E2D5
Paid: #0F7A44 on #DCFCE7
Partial: #B45309 on #FEF3C7
Unpaid/error: #B91C1C on #FEE2E2
Info: #0369A1 on #E0F2FE
No pure black, no saturated neon green, no dark mode, no full-green screens.

TYPOGRAPHY
Inter (or an equivalent geometric humanist sans). Tight, editorial hierarchy:
Display 30/34, weight 700, tracking -0.8
Screen title 26/30, weight 700, tracking -0.6
Section title 19/24, weight 700, tracking -0.3
Card title 16/22, weight 600
Body 14/21, weight 400–500
Meta 12/16, weight 500
Micro label 10.5/14, weight 600, uppercase, tracking 1.2 (use sparingly)
Numbers in stats use tabular figures, weight 700, tracking -0.5.
Sentence case everywhere except micro labels. Never all-caps sentences.

SPACING, RADII, ELEVATION
8pt spacing grid: 4, 8, 12, 16, 20, 24, 32, 40.
Screen horizontal margin: 20. Card padding: 18–20. Section gap: 18–24.
Radii: hero 34, sheet 28, card 24, tile 18, input/button 14–16, pill 999.
Cards use a 1px #E4EFE8 hairline plus two soft, low-opacity shadows (0 1 3 at 4%, 0 10 22 at 7%). No heavy borders, no harsh drop shadows.
Glass surfaces: white at 82–92% opacity, background blur 12–18, 1px white inner stroke at 60%, radius 24–28.

SIGNATURE LAYOUT PATTERNS
1. Deep-emerald "hero" panel: rounded 34, 20 inset, white text, lime accent, 1–2 translucent glass orbs, a top-left sheen, and a stat ribbon or feature row inside. Used on Login, owner/tenant Home, and detail heroes.
2. Light "soft header": white/mint panel with a tinted squircle icon, eyebrow micro label, 26px title, one-line subtitle, optional 3-stat strip. Used on Rooms, Tenants, Concerns, Announcements, More, house picker.
3. Airy white cards on the mint canvas. Vary card heights and internal density so the page reads like an editorial feed, not a uniform grid.
4. Floating capsule bottom navigation: white glass, 16 margin, 64 height, soft shadow; active item becomes an emerald pill with white icon + 10.5px label; inactive icons/text muted. Owner tabs: Home, Rooms, Tenants, Concerns, More. Tenant tabs: Home, Announcements, Concerns, More.

COMPONENTS TO DESIGN AS A SYSTEM
Primary button (emerald gradient pill, 54h, white label, icon right, visible pressed squash), secondary button (mint pill, emerald label), quiet/text button, icon button (44 tap target), destructive button (soft red), floating action button.
Stat tile and stat ribbon; hero stat with dividers; KPI card; progress bar; occupancy ring; bed-dot row; small sparkline (only for real data); segmented pill tabs; filter chips with counts; status pills (dot + label); role pills; chips with copy icon; search field; text fields with floating labels and helper/error text; steppers; select/dropdown; category grid tiles; action tile with leading tinted icon, title, subtitle and arrow; list rows; person row (initials avatar, name, meta, status dot); section header with trailing action; timeline rows with connector line; key/value rows; rating stars; notice card; concern card; announcement featured card; tenant/room cards; empty state; loading skeleton; snackbar; banner; bottom sheet with drag handle; confirmation dialog; "boarding-pass" key ticket (white card, perforation notches, dashed divider, dark emerald key strip, monospace key, lime copy button).
Icons: rounded outline icons, 1.8–2px stroke, 24px, filled variant for active states; each feature icon sits in a 40–44px tinted squircle. No emoji, no mixed icon families, no stock photos of people — use colored initial avatars.

MOTION (annotate, and also provide static end states)
Entrances: fade + translate Y 12–18px, 320–420ms, staggered 40ms per section. Press: scale 0.97 with a soft spring. Sheets: slide up 280–340ms with a fading scrim. Numbers: count-up/rolling. Occupancy ring: 700ms sweep on first appearance. Active nav: spring pill morph. Only animate opacity, translate, scale, rotation. Respect reduced motion. No bouncy loops, no distracting parallax.

CONTENT RULES
Use realistic Filipino boarding-house data, not lorem ipsum:
Owner: Marisol Reyes, "Green Haven Boarding House", @green-haven, 6 rooms, 18 beds, 14 tenants, 4 open slots, 2 open concerns.
Tenant: Alyssa Cruz, Room 203, rent ₱4,500/month, Paid.
Rooms 101–106. Tenants: Jomar Santos, Kim Dela Cruz, Paolo Garcia, Bea Villanueva, Carlo Mendoza.
Concern: "Leaking faucet in the shared bathroom", category Maintenance, status Pending, 5-star rating after resolution.
Announcement: "Water interruption on Saturday, 8:00 AM–12:00 PM".
Keys look like "GHBV-8X7K-2P9M". Currency in ₱. Dates are short and human ("Today, 9:41 AM", "Oct 28").
Copy is warm, direct and useful. No jargon, no fake marketing claims, no "Lorem ipsum".

SCREENS TO DESIGN — EVERY EXISTING FEATURE, EVERY STATE
Design 24+ complete frames covering the flows below.

A. ENTRY
1. Splash / session restore: deep-emerald ambient screen, monogram house logo in a 96px rounded squircle, "Tahanan", tagline "Your boarding house, in order.", floating glass capsule "Restoring your keys…" with key icon, subtle mint orbs, loading shimmer.
2. Login: emerald hero card with logo, headline "A calmer way to run your boarding house.", supporting line, three feature chips (Properties, People, Updates); a white preview strip with Rooms / Tenants / Rent tiles; white sign-in panel titled "Welcome back", Google sign-in button, "Secured by Google Sign-In" line, Owner / Tenant role chips, trust row (Google Login, Real-time Updates, Safe & Organized). Include loading, disabled, and server-unreachable error banner states.
3. My boarding houses (house picker): soft header with avatar, "My boarding houses", greeting, and a 3-stat strip (Property, As owner, As tenant); two action tiles (Create house, Join with key); "Portfolio mix" card with a thin owner/tenant progress bar and legend; property cards showing rounded house icon, name, owner name, @domain, role pill, key chip with copy icon, chevron; removed-property restore banner; empty state; sign out.
4. Create boarding house — 3-step wizard (Details → Rooms → Ready): step progress with check states; house name field; room count stepper; beds-per-room stepper; total beds summary card; layout presets (Starter 3 rooms, Standard 6 rooms, Family 8 rooms) as selectable tiles; per-room customization list with +/− steppers; review summary; success state; validation error states.
5. Join with key bottom sheet: drag handle, title, explanatory line, key field with paste action, helper text, primary "Join house" button, invalid-key error.

B. OWNER
6. Owner Home: deep-emerald hero with "OWNER DASHBOARD" eyebrow, avatar, greeting, house name, @domain, unread-concern pill; 3-stat ribbon (Rooms, Tenants, Open slots); 2×2 quick actions (Add room, Tenants, Rooms & beds, Concerns); occupancy ring card with "78% live capacity" and legend (Full rooms, With space, Beds per room); horizontal room overview cards with bed dots; "Recent concerns" list with status pills; "People in your house" horizontal avatar strip; "House pulse" vertical timeline of recent activity; latest announcement preview; "Switch boarding house" row; copy-house-key interaction and confirmation snackbar.
7. Rooms & beds: soft header with room icon, subtitle, 3 stats (Rooms, Beds filled, Open slots); "Add new room" primary card; room cards with room number, occupancy pill (Full/Open), occupied/capacity text, bed-dot row, percentage bar, overflow menu (View details, Rename room, Change capacity, Archive room); bed-mix card listing every room with filled/free labels; capacity alert card; empty state; add-room sheet; change-capacity dialog; rename dialog; archive confirmation; "cannot archive, room is occupied" dialog.
8. Room detail: hero/header for "Room 203" with occupancy subtitle and manage button; 3 stats (Occupied, Capacity, Open slots); bed layout with labeled bed dots; "Tenants in this room" list with person rows, room role, payment status; rent mix (Paid / Partial / Unpaid) progress segments; "Room facts" key/value card; manage sheet; remove-tenant confirmation; empty room state.
9. Tenant directory: soft header with tenant icon and stats (Tenants, Assigned, Unassigned); segmented tabs All tenants / By room / Unassigned; search field; tenant cards with initials avatar + status dot, full name, room chip, payment pill, chevron; by-room groups with room header and capacity; unassigned-account cards with "Associate to room"; remove-account confirmation; empty and no-search-results states.
10. Associate tenant: review header (Google account, tenant record, room); choose existing tenant record vs create new; room picker with open-bed counts; "Assign later" option; review summary; success confirmation; error state.
11. Concerns desk: soft header with stats (Total, Open, Resolved); resolution-rate card; filter pills (All, Open, Resolved) with counts; concern cards with category icon, subject, tenant + room, relative time, status pill, and rating when resolved; empty state per filter; concern detail sheet with photo/video thumbnails, tenant note, owner response field, "Update status" actions (Mark pending / Resolve), rating stars (1–5), and success snackbar.
12. Announcements (owner): notice-board header with stats (Total, This month, View); featured/latest notice card; list of announcement cards with date; compose sheet with title + message; edit sheet; delete confirmation; copy-text action; empty state.
13. More (owner): profile card with avatar, name, email; 3 facts (Your role, Houses, Plan); current-house card with house icon, name, @domain, rooms/tenants/open beds, house-key ticket with copy; rows for Manage, Switch boarding house, Announcements, About; support & legal section (Help & FAQ, Privacy, Terms of use); sign-out button with confirmation dialog; version line.

C. TENANT
14. Tenant Home: deep-emerald hero with greeting, first name, house name, current month; rent-status card (Paid / Partial / Unpaid) with amount and "This month"; 2×2 quick actions (Report a concern, Notices, Payments, My reports); latest announcement card with "View all"; recent concern card with status; "Your housemates" avatar strip; house-contact card with owner name, @domain, house key and copy; room info.
15. My concerns (tenant): header with stats (Reports, Open, Resolved); "Report a concern" primary CTA; concern cards with category icon, subject, room, date, status pill, rating; empty state; concern detail with owner response, attachments, status, rating.
16. Report a concern: header "What needs attention?"; 2×3 category grid (Maintenance, Utility, Cleanliness, Security, Noise, Other) with tinted icons and selected state; subject field; details field; "Photos & videos" attach row with add-media sheet (gallery image, camera photo, gallery video, record video; video max 30s); attachment thumbnails with remove; "What happens next" 3-step timeline (report logged, owner notified, you rate the fix); submit button; validation and upload-error states; submitted success.
17. Announcements (tenant): notice board, featured notice, list; detail sheet with full message, publish date, copy, and "Mark as acknowledged"; empty state.
18. More (tenant): profile card, current house, house key copy, support & legal, sign out confirmation.

D. SHARED OVERLAYS & STATES
19. House switcher sheet; join-with-key sheet; copy-key success snackbar; sign-out confirmation; destructive confirmations; loading skeletons; offline/server-unreachable banner; permission-denied for camera/gallery; empty states; form errors; busy/disabled buttons.

FLOWS TO CONNECT IN A PROTOTYPE
Splash → Login → house picker → Owner Home; Owner Home → Concerns → detail → respond/resolve; Rooms → add room → room detail; Tenants → associate account → assign room; house picker → Create house → Ready; Tenant Home → Report concern → submitted; Announcements → compose → mark acknowledged; More → switch house.

DELIVERABLES
- One design-system board: color tokens, type scale, spacing, radii, shadows, icon set, buttons, fields, pills, tabs, cards, nav, sheets, empty/loading/error states.
- 24+ mobile frames at 360 × 800, all using the same tokens.
- Component variants for pressed, disabled, loading, selected, error, empty.
- A clickable prototype covering the flows above.
- Annotations for spacing, motion duration/easing, and tap targets (minimum 44×44).
- Optional Figma-specific: variables for every token, auto-layout everywhere, component properties, and a light-only theme.

HARD CONSTRAINTS
Do not invent new features beyond the list. Do not add analytics, chat, payments processing, maps, or social features. Do not use dark mode, purple gradients, glassmorphism overload, thick borders, pure black, emoji, stock people photos, lorem ipsum, or generic SaaS illustrations. Keep the dominant impression white and green, airy and premium — deep emerald is an accent on heroes, not the whole app.
```

---

## Batch Prompts (when the tool caps output)

Paste the master prompt first, then use these one by one. Each assumes the same design system and sample content.

**Batch 1 — Foundation + entry**
"Using the Tahanan design system above, create: (1) the design-system board, (2) splash/session restore, (3) login, (4) my boarding houses, (5) create boarding house steps 1–3 + success, (6) join-with-key sheet. 360×800, light theme only, all states."

**Batch 2 — Owner core**
"Continue the Tahanan system. Create owner Home, owner Rooms & beds (list + add/rename/capacity/archive states), and Room detail (occupied and empty). Include the floating bottom nav and all sheets/dialogs."

**Batch 3 — People + service**
"Continue Tahanan. Create Tenant directory (All tenants / By room / Unassigned, search, empty), Associate tenant, Concerns desk (filters, detail sheet, response/status/rating), and Announcements (featured, list, compose, delete)."

**Batch 4 — Tenant side**
"Continue Tahanan. Create Tenant Home, My concerns, Report a concern (category grid, attachments, next-steps timeline), Tenant Announcements (detail + acknowledge), and Tenant More."

**Batch 5 — Polish**
"Continue Tahanan. Create the shared overlays and states: house switcher, copy-key snackbar, sign-out and destructive dialogs, loading skeletons, offline banner, permission denied, empty states. Then produce the component sheet and annotations."

---

## Short Version (if the tool has a tight prompt limit)

```text
Design a complete, premium white-green mobile UI for "Tahanan", a boarding-house manager for Filipino owners and tenants. Android, 360×800, light theme only. Airy mint-white canvas (#F3F9F5), white cards with 24px radii, deep-emerald hero panels (#052E1C→#0F7A44), lime accent (#C7F26A), Inter type, soft layered shadows, rounded outline icons, floating glass bottom nav. Screens: splash; Google login; house picker; 3-step create house; owner home with occupancy ring; rooms & bed-dot management; room detail; tenant directory with All/By room/Unassigned and associate flow; concerns desk with filters, media, owner response and ratings; announcements; more; tenant home with rent status; tenant concerns; report concern with categories and photo/video; tenant announcements; shared sheets and all empty/loading/error states. Realistic Filipino sample data, no lorem ipsum, no emoji, no dark mode, no new features. Deliver a design-system board plus 24+ linked frames.
```
