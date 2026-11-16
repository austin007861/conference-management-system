ALTER TABLE users ADD COLUMN role_name TEXT;

UPDATE users SET role_name = 'admin' WHERE role_id = 'role-1';
UPDATE users SET role_name = 'organiser' WHERE role_id = 'role-2';
UPDATE users SET role_name = 'speaker' WHERE role_id = 'role-3';
UPDATE users SET role_name = 'attendee' WHERE role_id = 'role-4';
