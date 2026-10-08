"""Copy the local PostgreSQL database into an empty Neon database."""
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "backend"))
os.environ.pop("DATABASE_URL", None)
os.environ["DJANGO_SETTINGS_MODULE"] = "config.settings"

import django
import psycopg
from psycopg.conninfo import conninfo_to_dict


def main():
    url = None
    for line in (ROOT / "backend/.env").read_text(encoding="utf-8-sig").splitlines():
        if line.strip().startswith("DATABASE_URL="):
            url = line.strip().split("=", 1)[1].strip().strip("\"'")
    if not url or not url.startswith(("postgresql://", "postgres://")):
        raise RuntimeError("backend/.env must contain a PostgreSQL DATABASE_URL.")
    target = conninfo_to_dict(url)
    target.setdefault("sslmode", "require")
    target["connect_timeout"] = "10"
    django.setup()
    from django.conf import settings
    source = settings.DATABASES["default"]
    if source["HOST"] not in ("localhost", "127.0.0.1", "::1"):
        raise RuntimeError("The source database must be local.")
    if not target.get("host", "").endswith(".neon.tech"):
        raise RuntimeError("The destination must be a Neon database.")
    tools = Path(r"C:\Program Files\PostgreSQL\18\bin")
    for name in ("pg_dump.exe", "pg_restore.exe"):
        if not (tools / name).exists():
            raise RuntimeError("PostgreSQL 18 command-line tools were not found.")
    local = dict(host=source["HOST"], port=source["PORT"], user=source["USER"],
                 password=source["PASSWORD"], dbname=source["NAME"], connect_timeout=10)
    with psycopg.connect(**target) as connection:
        count = connection.execute("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p','v','m','S','f')").fetchone()[0]
        if count:
            raise RuntimeError("Destination is not empty. Stopped without restoring data.")
    print("Neon connection OK; destination is empty.")
    backup_dir = ROOT / "backups"
    backup_dir.mkdir(exist_ok=True)
    backup = backup_dir / ("bair_db_" + datetime.now().strftime("%Y%m%d_%H%M%S") + ".dump")
    source_env = os.environ.copy()
    source_env["PGPASSWORD"] = local["password"]
    source_env["PGCONNECT_TIMEOUT"] = "10"
    subprocess.run([str(tools / "pg_dump.exe"), "-h", local["host"], "-p", str(local["port"]),
                    "-U", local["user"], "-d", local["dbname"], "-Fc", "-w", "-f", str(backup)],
                   env=source_env, check=True)
    print("Fresh local backup saved:", backup.name)
    destination_env = {k: v for k, v in os.environ.items() if not k.startswith("PG")}
    destination_env.update({"PG" + k.upper(): str(v) for k, v in target.items()})
    destination_env["PGDATABASE"] = destination_env.pop("PGDBNAME")
    subprocess.run([str(tools / "pg_restore.exe"), "--no-owner", "--no-acl", "--exit-on-error",
                    "--single-transaction", "-w", "--dbname", target["dbname"], str(backup)],
                   env=destination_env, check=True)
    print("Restore completed. Checking migrations...")
    migration_env = os.environ.copy()
    migration_env["DATABASE_URL"] = url
    subprocess.run([sys.executable, str(ROOT / "backend/manage.py"), "migrate"],
                   env=migration_env, check=True)
    with psycopg.connect(**local) as a, psycopg.connect(**target) as b:
        tables = a.execute("SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename").fetchall()
        for (table,) in tables:
            query = psycopg.sql.SQL("SELECT count(*) FROM {}").format(psycopg.sql.Identifier(table))
            left, right = a.execute(query).fetchone()[0], b.execute(query).fetchone()[0]
            if left != right:
                raise RuntimeError(f"Row count mismatch for {table}. Local writes may still be running.")
    print("SUCCESS: All source table row counts match Neon. Local database remains intact.")
    print("Uploaded media files need separate persistent storage.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        # Avoid printing DSNs, passwords, or database endpoints.
        print("STOPPED:", type(exc).__name__)
        if isinstance(exc, RuntimeError):
            print(str(exc))
        else:
            print("Connection or transfer failed. Local database has not been deleted.")
        sys.exit(1)
