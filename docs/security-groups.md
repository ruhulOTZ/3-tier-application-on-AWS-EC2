# AWS Security Group Cheat-Sheet

Three security groups, one per tier. Each tier accepts traffic only from the tier directly above it. This enforces "proper separation between layers" as required by the assignment.

## Visual

```
   Internet
      │  TCP 443 (HTTPS)
      │  TCP 80  (redirected by Nginx -> 443)
      ▼
┌───────────────────┐    SG-Presentation   (EC2 #1, Nginx + self-signed TLS)
│  SG-Presentation  │
└─────────┬─────────┘
          │  TCP 3001  (source = SG-Presentation)
          ▼
┌───────────────────┐    SG-Application    (EC2 #2, Express)
│  SG-Application   │
└─────────┬─────────┘
          │  TCP 5432  (source = SG-Application)
          ▼
┌───────────────────┐    SG-Data           (EC2 #3, PostgreSQL + pgAdmin)
│      SG-Data      │
└───────────────────┘
```

## Inbound rules — copy these exactly

Replace `YOUR.IP.ADD.RESS/32` with your laptop's public IP (find it at https://checkip.amazonaws.com).

### SG-Presentation  → attach to EC2 #1
| # | Type  | Protocol | Port | Source                | Description                          |
|---|-------|----------|------|-----------------------|--------------------------------------|
| 1 | SSH   | TCP      | 22   | `YOUR.IP.ADD.RESS/32` | Admin SSH                            |
| 2 | HTTPS | TCP      | 443  | `0.0.0.0/0`           | Public web traffic (TLS)             |
| 3 | HTTP  | TCP      | 80   | `0.0.0.0/0`           | Redirected by Nginx to 443           |

### SG-Application  → attach to EC2 #2
| # | Type        | Protocol | Port | Source                    | Description                       |
|---|-------------|----------|------|---------------------------|-----------------------------------|
| 1 | SSH         | TCP      | 22   | `YOUR.IP.ADD.RESS/32`     | Admin SSH                         |
| 2 | Custom TCP  | TCP      | 3001 | `sg-xxxxxxxx` (SG-Presentation) | API traffic from Nginx      |

### SG-Data  → attach to EC2 #3
| # | Type        | Protocol | Port | Source                    | Description                       |
|---|-------------|----------|------|---------------------------|-----------------------------------|
| 1 | SSH         | TCP      | 22   | `YOUR.IP.ADD.RESS/32`     | Admin SSH                         |
| 2 | PostgreSQL  | TCP      | 5432 | `sg-xxxxxxxx` (SG-Application)  | DB traffic from API         |
| 3 | HTTP        | TCP      | 80   | `YOUR.IP.ADD.RESS/32`     | pgAdmin web UI (admin only)       |

> **Outbound rules:** leave the default "all traffic to 0.0.0.0/0". The instances need outbound internet to `apt-get`, `npm install`, etc.

## How to set source = "another security group" in the AWS console

1. Open the EC2 console → **Security Groups** → click **SG-Application**
2. **Inbound rules** → **Edit inbound rules** → **Add rule**
3. Type = **Custom TCP**, Port = **3001**
4. In the Source dropdown, **start typing `sg-`** — a list of your SGs appears. Pick **SG-Presentation**.
5. Save rules. Repeat the same idea on SG-Data, picking SG-Application as the source for port 5432.

This is what creates the "tier above me only" link — IPs of EC2 instances change when you stop/start them, but security-group-to-security-group rules don't break.

## Verifying the rules from the command line

From the **Presentation** EC2 (#1):
```bash
# Should succeed (App tier accepts from SG-Presentation)
nc -vz <APP_PRIVATE_IP> 3001

# Should fail / hang (Data tier does NOT accept from SG-Presentation)
nc -vz <DATA_PRIVATE_IP> 5432   # expect timeout
```

From the **Application** EC2 (#2):
```bash
# Should succeed (Data tier accepts from SG-Application)
nc -vz <DATA_PRIVATE_IP> 5432
```

From your **laptop**:
```bash
# Should return 301 redirect to https
curl -I http://<PRESENTATION_PUBLIC_IP>/
# Expect:  HTTP/1.1 301 Moved Permanently
#          Location: https://<PRESENTATION_PUBLIC_IP>/

# Should succeed (-k accepts the self-signed cert)
curl -kI https://<PRESENTATION_PUBLIC_IP>/
# Expect:  HTTP/2 200

# Should fail (App tier is not exposed to the internet)
curl --max-time 5 http://<APP_PUBLIC_IP>:3001/api/health   # expect timeout
```

If all four results match expectations, your tier separation is correct.

## Common gotchas

- **"I can curl the API directly from my laptop"** — Means SG-Application has port 3001 open to `0.0.0.0/0`. Change the source to SG-Presentation.
- **"pgAdmin loads but won't connect to localhost:5432"** — That's a Postgres auth issue, not an SG issue (SGs don't filter loopback). Set `ALTER USER postgres WITH PASSWORD '...'` on the data EC2.
- **"API returns 500 on /api/health"** — SG-Data probably isn't allowing 5432 from SG-Application, or `pg_hba.conf` is missing the App-tier CIDR.
- **"My IP changed and SSH stopped working"** — Update rule #1 in each SG with your new `YOUR.IP/32`.
