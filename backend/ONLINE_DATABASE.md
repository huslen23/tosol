# Online PostgreSQL

Settings accept DATABASE_URL from the server environment. Copy the direct
connection URL from Neon; keep sslmode=require and channel_binding=require.
Use a direct connection for migrations and data transfer.

`.env.example` lists server variables. Django does not automatically load .env;
set these in your hosting dashboard or PowerShell environment.

Local credentials are stored in Git-ignored `.local-secrets.json` for development
only. Production reads credentials from environment variables. Revoke the old
Gmail App Password: removing it from the latest code does not remove Git history.

## Transfer existing data

Run from backend with PostgreSQL command-line tools installed. Do not set a new
DATABASE_URL until the local backup has completed. Keep the backup outside Git.
Pause writes during the final transfer, and keep the local database intact.

```powershell
New-Item -ItemType Directory -Force ..\backups
pg_dump -h localhost -U postgres -d bair_db -Fc -f ..\backups\bair_db.dump
# Set DATABASE_URL securely in this terminal to the direct Neon connection URL.
# Restore into a NEW, EMPTY database only.
pg_restore --dbname=$env:DATABASE_URL --no-owner --no-acl --exit-on-error ..\backups\bair_db.dump
.\venv\Scripts\python.exe manage.py migrate
.\venv\Scripts\python.exe manage.py check --database default
```

Verify account login, listing counts and ratings before switching the deployed
API to this database. Uploaded images in backend/media are separate files and
must be transferred to persistent storage separately.
