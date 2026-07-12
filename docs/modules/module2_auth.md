# Module 2: Authentication & User Management

## GitHub Branch: `feature/auth-module`

## Flutter Implementation Steps
1. Create folder: `lib/features/auth/`
   - `login_screen.dart`
   - `register_screen.dart`
   - `auth_bloc.dart`
   - `auth_repository.dart`
   - `user_model.dart`
2. Implement role-based access: `admin`, `field_agent`, `citizen`
3. Use Firebase Auth or JWT with Neon user validation
4. Store JWT securely using `flutter_secure_storage`
5. PR → `develop` with code review

## Neon DB Schema
```sql
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  role TEXT CHECK (role IN ('admin','field_agent','citizen')) NOT NULL DEFAULT 'citizen',
  name TEXT,
  phone TEXT,
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
```

## Test File: `test/auth/auth_test.dart`
- Test login with valid credentials
- Test login with invalid credentials
- Test role assignment
- Test JWT token expiry handling
