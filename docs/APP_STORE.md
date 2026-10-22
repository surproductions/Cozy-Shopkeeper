# App Store submission kit — Cozy Shopkeeper 1.0

Everything to paste into App Store Connect, plus the order to do it in.

## 1. One-time setup (in order)

1. **Let CI register the bundle ID.** The first CI run with the `APPLE_TEAM_ID` / `ASC_*` secrets registers `com.surproductions.cozyshopkeeper` and creates the signing certificate and profile automatically. The API key needs the **Admin** role for this.
2. **Create the app record.** App Store Connect → Apps → **+** → New App:
   - Platform: iOS
   - Name: **Cozy Shopkeeper** (if it's taken, try *Cozy Shopkeeper: Corner Shop* or *Maple Corner Shop*)
   - Primary language: English (U.S.)
   - Bundle ID: `com.surproductions.cozyshopkeeper`
   - SKU: `cozyshopkeeper-ios`
   - User access: Full Access
3. **Push any change to `main`** (or re-run CI). The signed build uploads automatically and appears under TestFlight after about 10–30 minutes of Apple processing.
4. Fill in sections 2–8 below, attach the build, and submit for review.

## 2. App information

| Field | Value |
|---|---|
| Name | Cozy Shopkeeper |
| Subtitle (≤30) | `Run a little fantasy shop` |
| Primary category | Games → **Simulation** |
| Secondary category | Games → **Casual** |
| Content rights | No, it does not contain, show, or access third-party content |
| Privacy Policy URL | Your published privacy policy (see section 7) |
| Support URL | A page with a way to contact you (see section 7) |
| Copyright | `2026 Sur Productions` (use your legal name or company) |
| Price | Free |
| Availability | All countries |
| Made for Kids | **No.** Opting in adds Kids-category rules; the 4+ rating still lets anyone download it. |

## 3. Version 1.0 text

**Promotional text (≤170, editable any time)**
```
Open your own cozy corner shop! Set fair prices, befriend regulars, decorate every nook and grow from Maple Corner to Flower Lane.
```

**Description**
```
Welcome to Maple Corner, where a little shop with a creaky floor and a bell above the door is waiting for you.

Cozy Shopkeeper is a relaxing shop-keeping game with no timers, no stress and no internet required.

SET YOUR OWN PRICES
Every neighbor has a budget and a personality. Price too high and they'll hesitate; price fair and they'll leave a happy tip. Find your sweet spot.

STOCK 25 CHARMING GOODS
Honey buns, berry cordial, quill pens, star lanterns, porcelain teapots and more, from everyday treats to rare treasures.

MEET 13 NEIGHBORS
A cheerful hedge-gardener, a bargain hunter with a ledger, a retired ferry captain, a sir with a waistcoat for every day of the year. Turn them into regulars, earn hearts and receive heartfelt keepsakes.

DECORATE EVERY CORNER
30 decorations: wallpapers, floors, counters, plants, fairy lights, rugs, paintings and seasonal touches. Preview before you buy. Cozier shops make happier customers.

UPGRADE AND EXPAND
Add shelves, grow your stockroom, polish the window display and open a second shop on Flower Lane.

A REASON TO RETURN
Fresh daily goals, a gentle 7-day welcome gift that never punishes a missed day, achievements and collections to complete.

• Plays fully offline
• No account, no ads, no tracking
• Original hand-crafted art and music
• Accessibility options: reduced motion, larger text, high contrast, haptics toggle
```

**Keywords (≤100, no spaces after commas)**
```
shop,store,simulator,cozy,relaxing,merchant,tycoon,idle,cafe,bakery,decorate,cute,offline,casual
```

**What's New:** `First release. Welcome to Maple Corner!`

## 4. Age rating (questionnaire answers → 4+)

Answer **None / No** to every question:

| Question | Answer |
|---|---|
| Cartoon or fantasy violence | None |
| Realistic violence; prolonged graphic or sadistic violence | None |
| Violent themes | None |
| Profanity or crude humor | None |
| Mature or suggestive themes | None |
| Sexual content or nudity | None |
| Horror or fear themes | None |
| Alcohol, tobacco, drug use or references | None (the "berry cordial" and "spiced cider" are presented as ordinary drinks) |
| Medical or treatment information; health or wellness topics | None |
| Simulated gambling | None |
| Contests | No |
| Loot boxes / paid random items | No |
| Unrestricted web access | No |
| User-generated content, messaging or chat | No |
| Social sharing / account creation | No (the issue report uses the iOS share sheet; there are no accounts) |
| In-app controls (parental controls, age assurance) | No |

Expected result: **4+**.

## 5. App Privacy (nutrition label)

- "Do you or your third-party partners collect data from this app?" → **No, we do not collect data from this app.**
- Result: **Data Not Collected**. This matches `App/Resources/PrivacyInfo.xcprivacy` (no tracking, no collected data types).

## 6. Export compliance

`ITSAppUsesNonExemptEncryption = NO` is already in the Info.plist, so App Store Connect won't ask about encryption for each build.

## 7. URLs you must provide

- **Privacy Policy URL:** must be a public page. `docs/privacy-policy.html` is ready to host. Easy free options: GitHub Pages (needs a public repo or a paid GitHub plan), Netlify Drop, or a free site builder.
- **Support URL:** must give users a way to contact you, normally a support email. `docs/support.html` has a placeholder; add your support email there and in the app before submitting (see section 9).

## 8. Screenshots

- Required: **6.9-inch iPhone, 1320 × 2868 px**, 1–10 images. Apple scales them down for smaller iPhones.
- CI captures 7 of them on the iPhone Pro Max simulator from a showcase save. They're in the `screenshots/` folder of the run's `ci-logs/run-N` branch and in the workflow artifact.
- Suggested order: Shop (01), Decor (03), Journal (04), Stockroom (02), Goals (05), Upgrades (06), Map (07).
- iPad screenshots are not needed: the app is iPhone-only.

## 9. Review notes (App Review Information)

- Sign-in required: **No**
- Contact: your name, phone and email (required by Apple; only the reviewer sees these)
- Notes:
```
Cozy Shopkeeper is a single-player offline game. No account is needed.
A short tutorial starts on first launch: tap "Open the shop", sell the honey bun to the first customer, then restock any item from Stock.
The app contains no ads, no in-app purchases in this version, and collects no data.
```

## 10. In-app purchase

None in 1.0. The "Remove Ads" StoreKit code is built in but hidden, because selling Remove Ads in an app with no ads would be rejected (guideline 2.3.1). Create the IAP `com.surproductions.cozyshopkeeper.removeads` only in the version that adds an ad network.

## 11. Before you press Submit

- [ ] Build attached (from TestFlight), tested on a real iPhone through TestFlight
- [ ] Privacy Policy URL and Support URL open in a private browser window
- [ ] Support email added to the support page and the in-app "Report an issue"
- [ ] Screenshots uploaded (6.9-inch)
- [ ] Age rating questionnaire done (4+)
- [ ] App Privacy: Data Not Collected
- [ ] Price: Free; availability set
