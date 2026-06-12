# TapeScan — on-device verification checklist (M9)

Run on your LiDAR iPhone with a signed Debug build before submitting. Each
item maps to a feature only real hardware can prove. Check items off in
order — later sections assume earlier ones passed.

## Setup
- [ ] `project.yml`: `DEVELOPMENT_TEAM` set, signing enabled → `xcodegen generate` → run on device.
- [ ] First launch walks onboarding; the camera CTA fires the REAL system
      permission prompt. Deny once → the recovery state appears with a
      working "Open Settings" deep-link → allow → continue.

## Measure accuracy (vs. a physical tape measure)
- [ ] 0.5 m reference: place two points along a tape — within ±1 cm.
- [ ] 2 m reference: within ±1 cm (LiDAR). Repeat 3× — runs agree within ±1 cm.
- [ ] 5 m reference: within ±2 cm.
- [ ] Area mode on a known rectangle (e.g. a door ≈ 0.9 × 2.0 m): area within ~3%.
- [ ] Angle mode on a wall corner reads ≈ 90°.
- [ ] Points stay world-locked while walking around them (markers don't drift).
- [ ] Cover the camera / wave fast: TRACK guidance appears ("Move slower" /
      "Aim at a textured surface"); placement at >15 m is refused, not wrong.
- [ ] Undo and redo restore points exactly; finish saves into History with
      correct values; killing the app mid-measure → relaunch offers
      "Resume previous session" with the same points.
- [ ] Backgrounding mid-measure releases the camera (green dot off); returning
      resumes tracking.

## Room scan (RoomPlan)
- [ ] Scan a real room: live wall count/area/coverage move; the mini plan
      card draws the partial plan during the scan.
- [ ] Finish → processing → the saved plan's walls/doors/windows match the
      room; dimensions within a few cm of tape-measured walls.
- [ ] Room appears in the Rooms list; reopening shows the same plan;
      quantities (perimeter / floor area / wall area / volume) are plausible.
- [ ] Scan a larger space (10+ minutes, ≥40 m²) — no crash, no overheating
      shutdown, memory stable.

## Exports (from the scanned room)
- [ ] PDF opens in Files with the plan + quantities block.
- [ ] PNG, SVG render correctly (AirDrop the SVG to a Mac browser).
- [ ] DXF opens in a CAD viewer (e.g. Autodesk Viewer online) with correct scale (mm).
- [ ] CSV opens in Numbers with rooms/walls/quantities rows.
- [ ] USDZ opens in Quick Look as the 3D room; glTF loads in a glTF viewer.
- [ ] Free quota decrements ONLY on success; at 0 the paywall appears; after
      subscribing exports are unlimited.

## Purchases (Sandbox — use a Sandbox Apple Account)
- [ ] Paywall shows 3 plans with localized prices from App Store Connect.
- [ ] Monthly with 7-day trial: disclosure names the exact post-trial price;
      purchase succeeds; Pro activates instantly (upsell card disappears).
- [ ] Delete + reinstall the app → Pro is restored from entitlements at launch
      (no stored flag).
- [ ] Restore Purchases works from Settings on a fresh install.
- [ ] Lifetime purchase activates Pro; Manage Subscription opens the sheet.
- [ ] Airplane mode → paywall shows the retry state (no crash, no plans[0]).

## Accounts & sync (after Supabase is provisioned)
- [ ] Sign in with Apple round-trips; Settings shows the account section.
- [ ] Google OAuth round-trips through the browser and back via tapescan://.
- [ ] Email code: receives a 6-digit code; wrong code shows an alert; right
      code signs in; Resend actually resends.
- [ ] Measure something → second device (or delete+reinstall) → sign in →
      the measurement syncs down.
- [ ] Delete on one device propagates to the other after foregrounding.
- [ ] Offline: measure + save with no network — instant, no errors; sync
      catches up silently on reconnect.
- [ ] Delete Account → rows gone from the Supabase dashboard; local data
      still on device; "Continue without account" everywhere never blocks.

## Accessibility & polish
- [ ] Settings → larger text sizes: paywall, Measure HUD, Settings stay
      readable (no clipped CTAs).
- [ ] Reduce Motion on: reticle pulse, status-dot blink, scan sweep, and the
      OTP caret all hold still.
- [ ] VoiceOver: tab bar, paywall plans, and export formats announce sensibly.

When every box is checked, run `scripts/build-release.sh`, then follow
`docs/ASC-SETUP.md` to submit.
