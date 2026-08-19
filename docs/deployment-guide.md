# Deployment guide — Hostinger + Vercel (demo / development phase)

A complete, click-by-click walkthrough for getting Playsher online for free, using the
Hostinger plan you already pay for plus Vercel's free tier.

> **This is a demo setup, not a production one.** See [Before you go live](#12-before-you-go-live)
> for the list of things that must change before real customers and real money.

---

## 1. What we are building

```
                 ┌──────────────────────────────┐
  Admin/Owner ─▶ │  Vercel — adminui (static)   │
   browser       │  admin-playsher.vercel.app   │
                 └──────────────┬───────────────┘
                                │ HTTPS  /api/v1/...
                 ┌──────────────▼───────────────┐
  Flutter app ─▶ │  Vercel — backend (Node)     │
                 │  playsher-api.vercel.app     │
                 └───────┬──────────────┬───────┘
                         │ MySQL        │ FTP (images)
                 ┌───────▼──────────────▼───────┐
                 │        Hostinger             │
                 │  MySQL DB  +  public_html/   │
                 └──────────────────────────────┘
```

Three services, all free:

| Piece | Host | Why there |
| --- | --- | --- |
| Admin + Owner panel | Vercel | Static files after build; instant, no cold start |
| REST API | Vercel | Your Hostinger plan has no Node.js |
| MySQL database | Hostinger | Already included in your plan |
| Uploaded images | Hostinger `public_html` | Vercel's disk is wiped on every restart |

Both Vercel projects deploy from the **same GitHub repo**, just with different
*Root Directory* settings. Every `git push` redeploys both — that is the CI/CD.

---

## 2. Before you start

You need:

- Your Hostinger login (hPanel)
- A GitHub account with access to `github.com/Vk2401/playsher`
- A Vercel account — sign up at [vercel.com](https://vercel.com) with **"Continue with GitHub"**

Have a text file open to paste values into as you go. You will collect:

```
DB host:        ___________________
DB name:        ___________________
DB user:        ___________________
DB password:    ___________________
FTP host:       ___________________
FTP user:       ___________________
FTP password:   ___________________
Backend URL:    ___________________   (after step 8)
Admin UI URL:   ___________________   (after step 9)
```

---

## 3. Hostinger — create the database

1. Log in to **hPanel** → pick your website → left sidebar **Databases → Management**.
2. Under *Create a New MySQL Database And Database User*:
   - **Database name**: `playsher_demo`
   - **Database username**: `playsher_user`
   - **Password**: click the generate button, then **copy it into your notes** — Hostinger
     will not show it again.
3. Click **Create**.

Hostinger prefixes both names, so the real values look like `u123456789_playsher_demo` and
`u123456789_playsher_user`. **Use the full prefixed names** — write them down exactly as shown
in the database list.

Also note the **Database host**. On most Hostinger plans it is `localhost` *for scripts running
on Hostinger*, but for an outside connection you need the actual hostname — find it in the same
page or under *Remote MySQL*. It usually looks like `srv1234.hstgr.io`.

---

## 4. Hostinger — allow Vercel to connect (Remote MySQL)

By default the database only accepts connections from inside Hostinger. Vercel is outside.

1. hPanel → **Databases → Remote MySQL**.
2. Tick **Any Host** (`%`).
3. Choose the database `u123456789_playsher_demo`.
4. Click **Create**.

> **Why "Any Host":** Vercel's servers do not have fixed IP addresses on the free plan, so
> there is no single IP to whitelist. The trade-off is that your database is now reachable from
> anywhere on the internet, protected only by the password. That is acceptable for demo data —
> it is **not** acceptable once real customer records are in there. See step 12.

---

## 5. Hostinger — create the tables

1. hPanel → **Databases → phpMyAdmin** → **Enter phpMyAdmin** next to `playsher_demo`.
2. Select the database in the left sidebar, then open the **SQL** tab.
3. Run these four files **in this order** — open each file in your code editor, copy all of it,
   paste into the SQL box, press **Go**, and wait for the green success message before the next:

   1. `backend-api/database/schema.sql` — the 20 core tables
   2. `backend-api/database/migrations/add_schedule_templates.sql`
   3. `backend-api/database/migrations/add_bank_details.sql`
   4. `backend-api/database/migrations/add_otps_table.sql`

4. Confirm the sidebar now lists **23 tables**, including `otps`, `bank_details` and
   `schedule_templates`.

> **Do not import `mobile_app/playsher_production.sql`.** Despite the name, that 4 MB file is a
> dump of the *old Laravel* Playsher system — it has `migrations`, `roles` and
> `personal_access_tokens` tables and uses different column names (`phone` not `mobile`,
> `ground_facilities` not `ground_amenities`). The Node backend's Sequelize models will not
> match it. It also contains real user data and should not be in the repo at all.

### Optional: seed demo data

If you want sports, amenities and a test ground to exist, run this locally once, pointing at
the Hostinger database:

```bash
cd "backend-api"
# temporarily set the Hostinger DB values in your local .env, then:
node database/seed.js
```

---

## 6. Hostinger — set up the uploads folder and FTP

Images uploaded through the admin panel will be pushed to Hostinger over FTP.

1. hPanel → **Files → File Manager**. Inside `public_html`, create a folder named `uploads`.
2. hPanel → **Files → FTP Accounts**. Note the **FTP hostname**, **FTP username** and the
   **FTP IP**. Set (or reset) the password and save it to your notes.
3. Decide the public address of that folder. If your Hostinger site is `playsher.com`, the
   images will be served at `https://playsher.com/uploads/...`, so your
   `UPLOAD_PUBLIC_URL` is `https://playsher.com`.

Quick check: put any `test.jpg` into `public_html/uploads/` with File Manager and open
`https://yourdomain.com/uploads/test.jpg` in a browser. If the image shows, this step is done.

---

## 7. Push your code to GitHub

The repo is already connected to `github.com/Vk2401/playsher`. From the project folder:

```bash
cd /opt/homebrew/var/www/vasanth/play
git status                 # look at what changed
git add -A
git commit -m "Add database-backed OTP, FTP upload driver and Vercel deployment config"
git push origin main
```

`.env` files are already git-ignored, so no passwords go to GitHub. Verify with
`git status --ignored | grep .env` — they should be listed as ignored, never as staged.

---

## 8. Vercel — deploy the backend

1. Go to [vercel.com/new](https://vercel.com/new) → **Import** the `playsher` repository.
2. **Project Name**: `playsher-api`
3. **Root Directory**: click **Edit** and select the **`backend-api`** folder. This is the
   single most important setting — Vercel must build from inside the backend folder, not the
   repo root.
4. **Framework Preset**: `Other`. Leave the build/output commands empty.
5. Expand **Environment Variables** and add every row below. Set each one for
   *Production, Preview and Development*:

| Name | Value |
| --- | --- |
| `NODE_ENV` | `production` |
| `DB_HOST` | your Hostinger DB host, e.g. `srv1234.hstgr.io` |
| `DB_PORT` | `3306` |
| `DB_NAME` | `u123456789_playsher_demo` |
| `DB_USER` | `u123456789_playsher_user` |
| `DB_PASSWORD` | the password from step 3 |
| `DB_SSL` | `false` |
| `DB_POOL_MAX` | `2` |
| `DB_POOL_IDLE` | `1000` |
| `JWT_SECRET` | a long random string — see below |
| `JWT_ACCESS_EXPIRES_IN` | `15m` |
| `JWT_REFRESH_EXPIRES_IN` | `7d` |
| `JWT_REFRESH_EXPIRES_DAYS` | `7` |
| `ADMIN_SECRET` | any phrase you choose; needed to create the first admin |
| `ALLOWED_ORIGINS` | leave blank for now — filled in at step 10 |
| `OTP_DEV_BYPASS` | `true` |
| `UPLOAD_DRIVER` | `ftp` |
| `UPLOAD_PUBLIC_URL` | `https://yourdomain.com` |
| `UPLOAD_FTP_HOST` | FTP hostname from step 6 |
| `UPLOAD_FTP_PORT` | `21` |
| `UPLOAD_FTP_USER` | FTP username |
| `UPLOAD_FTP_PASSWORD` | FTP password |
| `UPLOAD_FTP_SECURE` | `false` |
| `UPLOAD_FTP_BASE_DIR` | `/public_html` |
| `RAZORPAY_KEY_ID` | `rzp_test_SfE44aZxtFrhgU` |
| `RAZORPAY_KEY_SECRET` | your Razorpay **test** secret |
| `RATE_LIMIT_WINDOW_MS` | `900000` |
| `RATE_LIMIT_MAX` | `100` |
| `AUTH_RATE_LIMIT_MAX` | `10` |

Generate the JWT secret by running this locally and pasting the output:

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

> **`RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` are not optional.**
> `src/controllers/payment.controller.js:7` creates the Razorpay client the moment the file
> loads. If either is missing, the entire API crashes on startup and *every* endpoint returns
> an error — not just the payment ones. If you see `key_id is mandatory` in the Vercel logs,
> this is why.

6. Click **Deploy**, wait for the build, and note the URL — something like
   `https://playsher-api.vercel.app`.

**Test it.** Open `https://playsher-api.vercel.app/health` in a browser. You should see:

```json
{ "success": true, "message": "Playsher API is running." }
```

If you get an error instead, go to the Vercel project → **Logs** → **Runtime Logs** and read
the message. It is almost always a missing environment variable or a database connection
refused (revisit step 4).

---

## 9. Vercel — deploy the admin UI

1. [vercel.com/new](https://vercel.com/new) again → **Import the same `playsher` repository**.
   Vercel will warn that the repo is already used; that is fine and expected.
2. **Project Name**: `playsher-admin`
3. **Root Directory**: **`adminui`**
4. **Framework Preset**: Vercel should detect **Vite** on its own. Leave the build settings alone.
5. **Environment Variables** — one row:

| Name | Value |
| --- | --- |
| `VITE_API_BASE_URL` | `https://playsher-api.vercel.app/api/v1` |

   Use *your* backend URL from step 8, and keep the `/api/v1` on the end.

6. **Deploy**. Note the URL, e.g. `https://playsher-admin.vercel.app`.

> **Vite bakes this value into the JavaScript at build time.** If you change
> `VITE_API_BASE_URL` later you must trigger a **redeploy** — editing the variable alone does
> nothing to the already-built files.

---

## 10. Connect the two — CORS

Right now the backend will reject the admin panel's requests.

1. Vercel → **playsher-api** project → **Settings → Environment Variables**.
2. Edit `ALLOWED_ORIGINS` and set it to your admin UI URL, with no trailing slash:
   ```
   https://playsher-admin.vercel.app
   ```
3. Go to the **Deployments** tab → the newest deployment → **⋯** menu → **Redeploy**.

Environment variable changes only take effect on a new deployment. This catches everyone once.

---

## 11. Point the Flutter app at the API

Edit `mobile_app/lib/core/constants.dart`:

```dart
static const String baseUrl = 'https://playsher-api.vercel.app/api/v1';
```

Then `flutter run`. Log in with any Indian mobile number (10 digits starting 6, 7, 8 or 9) and
**any 6-digit code** — the `OTP_DEV_BYPASS=true` setting accepts all of them. A US number,
a 9-digit number, or one starting with 5 is still rejected, with a clear message.

### How CI/CD works from here

Both Vercel projects watch the `main` branch:

- **Push to `main`** → both projects rebuild and go live automatically.
- **Open a pull request** → Vercel builds a temporary preview URL for that branch, so you can
  check a change before merging.
- Roll back at any time: Vercel → **Deployments** → pick an older one → **Promote to Production**.

You never upload files by hand again. `git push` is the deploy.

---

## 12. Test checklist

Work through this once end-to-end before you show anyone:

- [ ] `https://playsher-api.vercel.app/health` returns the success JSON
- [ ] `https://playsher-api.vercel.app/api-docs` shows the Swagger page
- [ ] Admin UI loads and you can log in
- [ ] Refresh the browser while on a deep page like `/admin/grounds` — it must **not** 404
- [ ] Create an amenity **with an icon**, then confirm the image loads in the table *and* that
      the file appeared in Hostinger's `public_html/uploads/amenities/`
- [ ] Flutter: a valid Indian number + any 6-digit code logs you in
- [ ] Flutter: `5876543210` is rejected with "Enter a valid Indian mobile number"
- [ ] Wait 20 minutes, then load the admin UI again — the first request will be slow (cold
      start). That is expected on the free tier.

---

## 13. Before you go live

None of these matter for a demo. All of them matter the day a real customer pays.

| Issue | Why it blocks launch | Fix |
| --- | --- | --- |
| `OTP_DEV_BYPASS=true` | Anyone can log in as anyone with any code | Set to `false` and configure Twilio + DLT |
| Remote MySQL open to `%` | Database reachable from the whole internet | Move to a VPS with a private DB, or lock to fixed IPs |
| Vercel Hobby plan | Free tier forbids commercial use; Playsher takes payments | Upgrade to Pro, or move to a VPS |
| Razorpay test key in `constants.dart` | Test key is in source and public | Move to a `--dart-define` build-time value |
| `playsher_production.sql` in the repo | Real user data committed to git | Remove it and rewrite the history |
| Cold starts | First request after idle is slow | A VPS or Vercel Pro removes this |

The single change that resolves most of this list is a small VPS (~₹400/month), where the
backend runs as one long-lived process, the database is private, and uploads sit on a real
disk. When you get there, most of the settings above stay the same — you would set
`UPLOAD_DRIVER=local` and point `DB_HOST` at localhost.

---

## Troubleshooting

**`key_id is mandatory` in the logs** — `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` are missing.
Add both, then redeploy.

**Every admin panel request fails with a CORS error** — `ALLOWED_ORIGINS` does not exactly
match the admin URL. No trailing slash, and `https://` included. Redeploy after fixing.

**`ER_ACCESS_DENIED_ERROR` or connection timeout** — Remote MySQL (step 4) was not enabled,
or `DB_HOST` is set to `localhost`. From Vercel it must be the real Hostinger hostname.

**`Too many connections`** — `DB_POOL_MAX` is too high. Set it to `2`.

**Uploaded image saves but shows broken** — `UPLOAD_PUBLIC_URL` is wrong, or
`public_html/uploads` does not exist. Test the URL directly in a browser.

**Admin panel 404s on refresh** — `adminui/vercel.json` is missing from the deployment. It
must be inside the `adminui` folder, since that is the Root Directory.

**Changed an environment variable and nothing happened** — you must redeploy. Always.
