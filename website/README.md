# Mind Tiles website

A static marketing site and privacy policy for the game. It uses plain HTML and CSS with no build step and no tracking scripts.

```
website/
  index.html        landing page (features, how to play, modes, FAQ)
  privacy.html      privacy policy (matches the app: AdMob + Firebase)
  404.html          not-found page
  app-ads.txt       AdMob authorised-sellers file (fill in your publisher ID)
  robots.txt, sitemap.xml
  assets/styles.css, assets/img/*, assets/fonts/* (Lilita One, OFL)
```

## 1. Fill in the placeholders (required)

Search and replace in every file under `website/`:

| Placeholder | Replace with |
|---|---|
| `[DEVELOPER_NAME]` | Your name or company as shown on the store listing |
| `[CONTACT_EMAIL]` | A support email you read (stores require a working contact) |
| `[WEBSITE_DOMAIN]` | The final domain, e.g. `mindtiles.web.app` or `mindtiles.com` |

```bash
grep -rn "\[DEVELOPER_NAME\]\|\[CONTACT_EMAIL\]\|\[WEBSITE_DOMAIN\]" website/
```

Then edit `app-ads.txt`: put in your AdMob publisher ID and uncomment the line.

Have the privacy policy reviewed for the countries you publish in. It is written to match the current app, but it is not legal advice.

## 2. Preview locally

```bash
cd website && python3 -m http.server 8000   # open http://localhost:8000
```

## 3. Deploy (Firebase Hosting, free tier)

The repository root already has `firebase.json` (with `hosting.public = "website"`) and `.firebaserc` (default project `mind-tiles-9t1li`).

```bash
firebase deploy --only hosting
```

The site will be at `https://mind-tiles-9t1li.web.app`. You can add a custom domain under Firebase Console → Hosting → Add custom domain. Any static host also works (GitHub Pages, Netlify, Cloudflare Pages): just upload the `website/` folder.

## 4. After deploying

- Play Console → App content → **Privacy policy** → `https://<domain>/privacy.html`
- Play Console → Store settings → **Website** → `https://<domain>` (needed for app-ads.txt verification)
- App Store Connect → App Privacy → **Privacy Policy URL**, and **Support URL** (`https://<domain>/#faq`)
- AdMob → Apps → app-ads.txt tab → verify (can take up to 24 h)

## 5. Checked

- Layout fits widths of 320 px, 375 px and 1280 px with no horizontal overflow (measured in headless Chrome)
- Respects `prefers-reduced-motion`. Content is semantic, with alt text, a skip link and visible focus.
