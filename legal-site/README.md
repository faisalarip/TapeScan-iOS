# TapeScan legal & support site

Static pages App Review requires: privacy policy, terms, and support — plus a
tiny landing page. Publish them on GitHub Pages (free) in ~3 minutes:

1. Create a public GitHub repository named `tapescan-legal` (any name works).
2. Copy the four `.html` files in this folder to the repository root and push.
3. Repository **Settings → Pages → Source: Deploy from a branch → main / root**.
4. After it deploys, your URLs are:
   - `https://<your-github-username>.github.io/tapescan-legal/privacy.html`
   - `https://<your-github-username>.github.io/tapescan-legal/terms.html`
   - `https://<your-github-username>.github.io/tapescan-legal/support.html`

Then update the app + store config to the real URLs:

- `Sources/Services/PurchaseService.swift` → `LegalLinks.privacy`
  (and `LegalLinks.terms` if you prefer your own terms page over Apple's
  standard EULA — the in-app terms page already incorporates the EULA).
- App Store Connect → App Information → **Privacy Policy URL** and
  **Support URL**.

Keep the effective dates in the documents current when you change them.
