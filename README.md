# 3-Tier Application on AWS EC2 — Module 4 Assignment

A simple **Notes** web app deployed across three EC2 instances, with each tier running on its own instance and communicating only through the next tier.

## Architecture

```
                    ┌────────────────────────────┐
   User browser ──► │ Presentation Tier (EC2 #1) │
                    │   Nginx :443 (HTTPS)       │
                    │   :80 → 301 redirect       │
                    │   serves built React app   │
                    │   reverse-proxies /api/*   │
                    └──────────────┬─────────────┘
                                   │  HTTP /api/*
                                   ▼
                    ┌────────────────────────────┐
                    │ Application Tier (EC2 #2)  │
                    │   Node.js + Express :3001  │
                    │   REST API for notes       │
                    └──────────────┬─────────────┘
                                   │  TCP 5432
                                   ▼
                    ┌────────────────────────────┐
                    │ Data Tier (EC2 #3)         │
                    │   PostgreSQL :5432         │
                    │   pgAdmin4-web :80/pgadmin4│
                    └────────────────────────────┘
```

| Tier | EC2 | Software | Public access |
|---|---|---|---|
| Presentation | #1 | Nginx, built React (Vite) bundle, self-signed TLS | Port 443 (HTTPS) + 80 (redirects to 443) — open to the internet |
| Application  | #2 | Node.js 20, Express, `pg` | Port 3001 (open **only** to EC2 #1) |
| Data         | #3 | PostgreSQL 14+, pgAdmin4-web | Port 5432 (open **only** to EC2 #2); Port 80 (pgAdmin) open to your IP |

## Repository layout

```
.
├── README.md
├── backend/                  # Application tier (Node.js + Express)
│   ├── package.json
│   ├── server.js
│   ├── .env.example
│   └── .gitignore
├── frontend/                 # Presentation tier source (React + Vite)
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   ├── src/
│   │   ├── main.jsx
│   │   ├── App.jsx
│   │   └── styles.css
│   └── .gitignore
├── database/                 # Data tier
│   ├── init.sql              # notes table + sample rows
│   ├── setup-postgres.sh     # native install of PostgreSQL
│   └── setup-pgadmin.sh      # native install of pgAdmin4 web mode
├── deployment/
│   ├── nginx-frontend.conf   # Nginx site config for EC2 #1 (HTTPS + redirect)
│   ├── generate-ssl-cert.sh  # creates the self-signed TLS cert on EC2 #1
│   └── notes-backend.service # systemd unit for the API on EC2 #2
└── docs/
    ├── security-groups.md    # detailed SG cheat-sheet + verification commands
    └── screenshots-checklist.md  # what to capture for each of the 8 screenshots
```

> See [`docs/security-groups.md`](docs/security-groups.md) for the security-group setup in more detail, and [`docs/screenshots-checklist.md`](docs/screenshots-checklist.md) for what each proof-of-work screenshot should contain.

---

## Prerequisites

- 3 running EC2 instances (Ubuntu 22.04 or 24.04 LTS recommended)
- All 3 instances in the **same VPC** (so they can reach each other on private IPs)
- A key pair `.pem` file with permissions `chmod 400 your-key.pem`
- The public IPs of all 3 instances and the private IP of EC2 #2 and EC2 #3

> **Tip:** Note down these values now — you'll paste them into config files later.
>
> | Instance | Public IP | Private IP |
> |---|---|---|
> | EC2 #1 (Presentation) | _________ | _________ |
> | EC2 #2 (Application)  | _________ | _________ |
> | EC2 #3 (Data)         | _________ | _________ |

## Security Group rules

Create three security groups (one per tier) and apply them as below. Each tier should only accept traffic from the tier directly above it.

**SG-Presentation (attached to EC2 #1)**

| Type  | Port | Source        | Purpose                              |
|-------|------|---------------|--------------------------------------|
| SSH   | 22   | Your IP       | Admin                                |
| HTTPS | 443  | `0.0.0.0/0`   | User traffic (TLS)                   |
| HTTP  | 80   | `0.0.0.0/0`   | Redirected by Nginx to 443           |

**SG-Application (attached to EC2 #2)**

| Type | Port | Source | Purpose |
|---|---|---|---|
| SSH | 22 | Your IP | Admin |
| Custom TCP | 3001 | `SG-Presentation` | API traffic from Nginx |

**SG-Data (attached to EC2 #3)**

| Type | Port | Source | Purpose |
|---|---|---|---|
| SSH | 22 | Your IP | Admin |
| PostgreSQL | 5432 | `SG-Application` | DB traffic from API |
| HTTP | 80 | Your IP | pgAdmin web UI |

---

## Setup

The order matters: **Data → Application → Presentation**. The database has to exist before the API tries to connect.

### Step 0 — Clone the repository on each EC2

On each of the three EC2 instances:

```bash
sudo apt-get update -y
sudo apt-get install -y git
git clone <YOUR_GIT_REPO_URL> ~/app
cd ~/app
```

---

### Step 1 — Data Tier (EC2 #3)

**1.1 — Edit values, install PostgreSQL, create DB and user**

```bash
cd ~/app/database
# Open setup-postgres.sh and edit:
#   DB_PASSWORD       -> a strong password
#   APP_TIER_CIDR     -> your VPC CIDR (e.g. 172.31.0.0/16) or App-tier private IP /32
nano setup-postgres.sh

chmod +x setup-postgres.sh
sudo ./setup-postgres.sh
```

When this finishes you should be able to run:

```bash
sudo -u postgres psql -d notesdb -c "SELECT * FROM notes;"
```

…and see the two sample rows.

**1.2 — Install pgAdmin4 in web mode**

```bash
chmod +x setup-pgadmin.sh
sudo ./setup-pgadmin.sh
```

The script will prompt you for a pgAdmin admin email and password. Pick anything you'll remember — this is just for logging into the pgAdmin web UI.

After it finishes, set a password for the OS-level `postgres` Postgres role so pgAdmin can connect to it:

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'pick_a_strong_password';"
```

**1.3 — Verify pgAdmin web UI**

Open in your browser:

```
http://<DATA_EC2_PUBLIC_IP>/pgadmin4
```

Log in with the admin email/password you set. Then register a server:

- General → Name: `local`
- Connection → Host: `127.0.0.1`, Port: `5432`, Maintenance DB: `postgres`, Username: `postgres`, Password: the one you just set above

You should now see `notesdb` in the tree, and the `notes` table inside it.

---

### Step 2 — Application Tier (EC2 #2)

**2.1 — Install Node.js 20**

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node --version    # v20.x
```

**2.2 — Install backend dependencies**

```bash
cd ~/app/backend
npm install
```

**2.3 — Configure environment**

```bash
cp .env.example .env
nano .env
```

Set:

```
PORT=3001
DB_HOST=<PRIVATE_IP_OF_DATA_EC2>     # e.g. 172.31.20.30
DB_PORT=5432
DB_NAME=notesdb
DB_USER=notesuser
DB_PASSWORD=<the password you set in setup-postgres.sh>
```

**2.4 — Smoke test**

```bash
node server.js
# In another terminal on the same instance:
curl http://localhost:3001/api/health
# Expect: {"status":"ok","db_time":"..."}
```

Press `Ctrl+C` to stop.

**2.5 — Run as a systemd service (so it survives reboots)**

```bash
sudo cp ~/app/deployment/notes-backend.service /etc/systemd/system/notes-backend.service
sudo systemctl daemon-reload
sudo systemctl enable --now notes-backend
sudo systemctl status notes-backend
```

Logs:

```bash
sudo journalctl -u notes-backend -f
```

---

### Step 3 — Presentation Tier (EC2 #1)

**3.1 — Install Node.js + Nginx**

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs nginx
```

**3.2 — Build the React app**

```bash
cd ~/app/frontend
npm install
npm run build
# This produces a 'dist/' directory containing static HTML/CSS/JS
```

**3.3 — Publish the build to Nginx's web root**

```bash
sudo mkdir -p /var/www/notes-frontend
sudo rm -rf /var/www/notes-frontend/*
sudo cp -r dist/* /var/www/notes-frontend/
sudo chown -R www-data:www-data /var/www/notes-frontend
```

**3.4 — Generate the self-signed TLS certificate**

```bash
cd ~/app/deployment
chmod +x generate-ssl-cert.sh
sudo ./generate-ssl-cert.sh
# Produces:
#   /etc/ssl/notes/notes.crt
#   /etc/ssl/notes/notes.key
# The cert is bound to this EC2's public IP and valid for 365 days.
```

If for any reason the script can't auto-detect the public IP (rare), pass it explicitly:

```bash
sudo PUBLIC_IP_OVERRIDE=<EC2#1_PUBLIC_IP> ./generate-ssl-cert.sh
```

**3.5 — Configure Nginx**

```bash
sudo cp ~/app/deployment/nginx-frontend.conf /etc/nginx/sites-available/notes-frontend
# Edit the upstream line and replace APP_TIER_HOST with the *private* IP of EC2 #2
sudo nano /etc/nginx/sites-available/notes-frontend
#   server APP_TIER_HOST:3001;   ->   server 172.31.10.20:3001;

sudo ln -sf /etc/nginx/sites-available/notes-frontend /etc/nginx/sites-enabled/notes-frontend
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t                     # should report "syntax is ok / test is successful"
sudo systemctl reload nginx
```

---

## Application access result

Open in your browser:

```
https://<PRESENTATION_EC2_PUBLIC_IP>/
```

> **First-visit warning:** Because the cert is self-signed, your browser will show a "Your connection is not private" / "Not secure" warning. Click **Advanced → Proceed anyway** (Chrome) or **Advanced → Accept the Risk and Continue** (Firefox). This warning is expected and does not mean anything is broken — it just means the cert wasn't issued by a public CA. The connection itself is encrypted with TLS.

You should see the **3-Tier Notes** UI with:

- A green health badge ("API healthy · DB time: …") confirming Presentation → Application → Data is fully wired up
- Two sample notes from the data tier
- A form to add a new note — submit it and it appears in the list, then verify in pgAdmin with `SELECT * FROM notes;`

Plain `http://...` requests are auto-redirected to HTTPS (HTTP 301) by Nginx. Test it:

```bash
curl -I http://<PRESENTATION_EC2_PUBLIC_IP>/
# HTTP/1.1 301 Moved Permanently
# Location: https://<PRESENTATION_EC2_PUBLIC_IP>/
```

API can also be reached directly via Nginx (use `-k` so curl accepts the self-signed cert):

```
https://<PRESENTATION_EC2_PUBLIC_IP>/api/health
https://<PRESENTATION_EC2_PUBLIC_IP>/api/notes
```

```bash
curl -k https://<PRESENTATION_EC2_PUBLIC_IP>/api/health
```

pgAdmin is reachable at (still HTTP — internal admin only, restricted to your IP):

```
http://<DATA_EC2_PUBLIC_IP>/pgadmin4
```

---

## Screenshots (proof of work)

> Replace each placeholder with a screenshot once you've verified the deployment. Save them in a `screenshots/` folder in the repo and reference them like `![desc](screenshots/file.png)`.

1. **EC2 console** showing 3 running instances with their tags
   `![3 EC2 instances](screenshots/01-ec2-instances.png)`

2. **Security groups** showing the three SGs and their inbound rules
   `![Security groups](screenshots/02-security-groups.png)`

3. **Data tier** — `psql` output of `SELECT * FROM notes;` on EC2 #3
   `![psql notes](screenshots/03-psql-notes.png)`

4. **Data tier** — pgAdmin web UI showing the `notes` table with rows
   `![pgAdmin notes](screenshots/04-pgadmin-notes.png)`

5. **Application tier** — `systemctl status notes-backend` showing it's active
   `![systemd status](screenshots/05-backend-systemd.png)`

6. **Application tier** — `curl http://localhost:3001/api/health` returning `status: ok`
   `![api health](screenshots/06-api-health.png)`

7. **Presentation tier** — `nginx -t` success and the React app loaded in a browser
   `![nginx + UI](screenshots/07-frontend-ui.png)`

8. **End-to-end** — adding a note in the UI, then seeing it in pgAdmin
   `![end-to-end](screenshots/08-end-to-end.png)`

---

## Troubleshooting

**Browser shows "Your connection is not private" warning**
- Expected — the cert is self-signed. Click Advanced → Proceed anyway. The connection is still encrypted with TLS, the browser just doesn't trust the cert issuer (you).

**Frontend loads but the health badge is red ("Could not fetch notes")**
- On EC2 #1: `curl -k https://localhost/api/health` — if this fails, Nginx isn't reaching EC2 #2. Check `nginx-frontend.conf` `upstream` IP and SG-Application rule.
- On EC2 #2: `sudo journalctl -u notes-backend -f` — look for DB connection errors.

**HTTPS doesn't work / `nginx -t` fails after copying the config**
- Did you run `generate-ssl-cert.sh` first? Check `ls -la /etc/ssl/notes/` — both `notes.crt` and `notes.key` must exist.
- Check Nginx error log: `sudo tail -n 50 /var/log/nginx/error.log`

**API returns 500 on `/api/health`**
- DB unreachable. On EC2 #2: `psql -h <DATA_PRIVATE_IP> -U notesuser -d notesdb` (use the password from `.env`). If this fails:
  - Check `pg_hba.conf` has the App-tier CIDR allowed
  - Check `listen_addresses = '*'` in `postgresql.conf`
  - Check SG-Data inbound rule for port 5432 from SG-Application

**pgAdmin shows "Internal Server Error"**
- Apache likely needs a restart: `sudo systemctl restart apache2`
- Make sure you ran `sudo /usr/pgadmin4/bin/setup-web.sh` after install

**SSH not working to a tier**
- Verify port 22 is allowed from your IP in that tier's SG
- Verify the key pair: `ssh -i your-key.pem ubuntu@<public-ip>`

---

## Notes & design choices

- **No Docker** — every service runs as a native package or systemd unit, per the assignment constraint of using only EC2.
- **Private IPs between tiers** — the API only ever talks to the DB over its private IP, and Nginx talks to the API over its private IP. This keeps DB and API off the public internet.
- **`.env` is gitignored** — never commit secrets. `backend/.env.example` is the template.
- **Nginx as the single internet-facing surface** — only EC2 #1 has 80/443 open to the world. The API is reached by clients indirectly through `/api/*`.
- **TLS terminates at Nginx** — the Presentation tier handles HTTPS with a self-signed cert. Inside the VPC the API and DB hops are plain HTTP/TCP, which is fine because they're over private IPs and locked to specific security groups. For a real production deploy you'd swap the self-signed cert for Let's Encrypt (with a domain) or AWS ACM behind an ALB.

---

## Submission checklist

- [ ] All three EC2 instances running and reachable
- [ ] Security groups configured per the tables above
- [ ] `setup-postgres.sh` ran cleanly on EC2 #3
- [ ] pgAdmin web UI accessible at `http://<DATA_PUBLIC_IP>/pgadmin4`
- [ ] `notes-backend` systemd service is `active (running)` on EC2 #2
- [ ] React build deployed to `/var/www/notes-frontend` on EC2 #1
- [ ] Self-signed TLS cert generated at `/etc/ssl/notes/`
- [ ] `nginx -t` succeeds and Nginx reloaded
- [ ] App opens at `https://<PRESENTATION_PUBLIC_IP>/` with green health badge (after accepting the self-signed-cert warning)
- [ ] `http://<PRESENTATION_PUBLIC_IP>/` returns a 301 redirect to `https://`
- [ ] All 8 screenshots captured under `screenshots/`
- [ ] Repo pushed to git with this README at the root
