-- Convene seed accounts.
--
-- Apply with:
--   wrangler d1 execute convene_db --remote --file=./scripts/seed.sql
--
-- Idempotent: existing rows are updated in place, missing rows are inserted.
-- Password hashes are PBKDF2-SHA256 (see Backend/src/middleware/auth.ts).
-- Regenerate a hash with: node scripts/hash-password.mjs "YourPassword"

INSERT OR IGNORE INTO roles (id, name, created_at) VALUES ('role-1', 'admin', datetime('now'));
INSERT OR IGNORE INTO roles (id, name, created_at) VALUES ('role-2', 'organiser', datetime('now'));
INSERT OR IGNORE INTO roles (id, name, created_at) VALUES ('role-3', 'speaker', datetime('now'));
INSERT OR IGNORE INTO roles (id, name, created_at) VALUES ('role-4', 'attendee', datetime('now'));

-- Samuel Makokha — Administrator
INSERT INTO users (id, role_id, name, email, password_hash, phone, avatar_url, role_name, status, created_at)
VALUES ('seed-admin-2', 'role-1', 'Samuel Makokha', 'samuel@convene.com',
        'pbkdf2$10000$uHm9ZCE8T8SAVJ/lyIynuA==$L/c253wGU7KURtbQHlsOAapSXDIT39fePPs7o+HSkz8=',
        '+254700111222', NULL, 'admin', 'active', datetime('now'))
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  email = excluded.email,
  password_hash = excluded.password_hash,
  role_id = excluded.role_id,
  role_name = excluded.role_name,
  status = excluded.status;

-- Austin Omondi — Organiser
INSERT INTO users (id, role_id, name, email, password_hash, phone, avatar_url, role_name, status, created_at)
VALUES ('seed-organiser-2', 'role-2', 'Austin Omondi', 'austin@convene.com',
        'pbkdf2$10000$OQD+sKv1hMbNkmZCdsyVxg==$sCTVkiOQRU4QfkosMQCYlCUg1zjziPCVMQU60dvO6OY=',
        '+254700333444', NULL, 'organiser', 'active', datetime('now'))
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  email = excluded.email,
  password_hash = excluded.password_hash,
  role_id = excluded.role_id,
  role_name = excluded.role_name,
  status = excluded.status;