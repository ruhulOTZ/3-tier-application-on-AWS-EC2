# Screenshots Checklist

Tick each box once you've captured the screenshot and saved it to `screenshots/` in the repo. Filenames here match the references in the main README, so the images will render automatically once committed.

> **Tip — naming convention:** save as PNG, 1200px+ wide, descriptive filename. Crop out unrelated browser tabs / desktops.

---

## 1. AWS Console — 3 EC2 instances running
- [ ] **File:** `screenshots/01-ec2-instances.png`
- **What to capture:** EC2 console → Instances list, all 3 instances showing `Running` state.
- **Make sure visible:** Instance Name tags (e.g. `presentation`, `application`, `data`), Instance state, Public IPv4, Availability Zone.
- **Why:** Proves you have the minimum 3 EC2 instances the assignment requires.

## 2. Security Groups — separation between tiers
- [ ] **File:** `screenshots/02-security-groups.png`
- **What to capture:** EC2 → Security Groups list **and** one inbound-rules detail per SG.
- **Make sure visible:** SG names (`SG-Presentation`, `SG-Application`, `SG-Data`) and that the source for ports 3001 and 5432 is **another security group**, not `0.0.0.0/0`.
- **Why:** Proves "proper separation between layers".

## 3. Data tier — psql confirming the table & rows
- [ ] **File:** `screenshots/03-psql-notes.png`
- **What to capture:** SSH into EC2 #3 and run:
  ```bash
  sudo -u postgres psql -d notesdb -c "SELECT * FROM notes;"
  ```
- **Make sure visible:** the `id`, `title`, `body`, `created_at` columns and the two seeded rows ("Welcome", "3-Tier check").
- **Why:** Proves the database is created, schema is applied, sample data loaded.

## 4. Data tier — pgAdmin web UI
- [ ] **File:** `screenshots/04-pgadmin-notes.png`
- **What to capture:** Browser open at `http://<DATA_EC2_PUBLIC_IP>/pgadmin4` after logging in. In the left tree expand → Servers → local → Databases → notesdb → Schemas → public → Tables → `notes`. Right-click → View/Edit Data → All Rows.
- **Make sure visible:** the URL bar (so the marker says you accessed it via web), the tree on the left, and the data grid showing the rows.
- **Why:** Proves pgAdmin is installed in **web** mode (the assignment specifically asked for pgAdmin in web).

## 5. Application tier — PM2 process running
- [ ] **File:** `screenshots/05-backend-pm2.png`
- **What to capture:** SSH into EC2 #2 and run, in this order, capturing both in one terminal screenshot:
  ```bash
  pm2 status
  pm2 logs notes-backend --lines 15 --nostream
  ```
- **Make sure visible:**
  - In `pm2 status`: a row for `notes-backend` with status `online`, non-zero uptime, restart count, and CPU/memory usage.
  - In the logs: the `Notes API listening on 0.0.0.0:3001` line and the `DB target: 10.0.8.229:5432/notesdb` line.
- **Why:** Proves the backend runs as a managed process that auto-restarts on crash/reboot, not just a one-off `node` command.

## 6. Application tier — API health check
- [ ] **File:** `screenshots/06-api-health.png`
- **What to capture:** On EC2 #2:
  ```bash
  curl -s http://localhost:3001/api/health | jq
  curl -s http://localhost:3001/api/notes | jq
  ```
- **Make sure visible:** `{"status":"ok","db_time":"..."}` for the first command, and the array of notes for the second.
- **Why:** Proves the App tier is alive and can talk to the Data tier.

## 7. Presentation tier — Nginx + UI (HTTPS)
- [ ] **File:** `screenshots/07-frontend-ui.png`
- **What to capture:** A side-by-side or two-pane shot:
  - Terminal on EC2 #1: `sudo nginx -t` (shows "syntax is ok / test is successful")
  - Browser at `https://<PRESENTATION_EC2_PUBLIC_IP>/` with the **URL bar showing `https://`**
- **Make sure visible:** the `https://` in the address bar (with the "Not secure" indicator since cert is self-signed — that's expected and proves you're using HTTPS), the green health badge at the top of the page ("API healthy · DB time: …"), and at least the two seeded notes.
- **Why:** Proves Presentation → Application → Data is fully wired AND HTTPS is enabled on the public-facing tier.

### 7b. (Bonus) HTTP→HTTPS redirect proof
- [ ] **File:** `screenshots/07b-http-redirect.png`
- **What to capture:** Terminal showing
  ```bash
  curl -I http://<PRESENTATION_EC2_PUBLIC_IP>/
  ```
  …with a `HTTP/1.1 301 Moved Permanently` and `Location: https://...` in the response.
- **Why:** Proves plain HTTP requests are upgraded to HTTPS automatically.

## 8. End-to-end — adding a note
- [ ] **File:** `screenshots/08-end-to-end.png`
- **What to capture:** A single image (or 2-up collage) showing:
  - Left: the React UI with a new note you just added (e.g. title "Demo run 2026-05-07")
  - Right: pgAdmin `notes` table refreshed, showing that exact same row
- **Why:** Strongest possible proof — the data flowed from browser → Nginx → API → Postgres, and you can see it in the database.

---

## How to add screenshots to the repo

```bash
# from the repo root
mkdir -p screenshots
# copy your image files into screenshots/
git add screenshots/
git commit -m "Add deployment screenshots"
git push
```

The `README.md` in the repo root already references these filenames, so once they're committed the images will render on GitHub.

---

## Pre-submission checklist

- [ ] All 9 screenshots captured and committed (1, 2, 3, 4, 5, 6, 7, 7b, 8)
- [ ] `README.md` renders cleanly on GitHub (visit your repo and check)
- [ ] Repo URL is shareable (public, or shared with whoever's grading)
- [ ] App is still reachable at `http://<PRESENTATION_PUBLIC_IP>/` at submission time
- [ ] You can answer: "Why is this 3-tier?" → because each tier (Presentation / Application / Data) lives on its own EC2 with its own security group, and tiers only talk to the tier directly below them.
