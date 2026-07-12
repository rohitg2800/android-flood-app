# Module 2: Authentication & User Management

## GitHub Branch
`feature/auth-module` → PR → `develop`

## Flutter Structure

```
lib/features/auth/
  models/
    user_model.dart
    auth_token_model.dart
  screens/
    login_screen.dart
    register_screen.dart
    forgot_password_screen.dart
  bloc/
    auth_bloc.dart
    auth_event.dart
    auth_state.dart
  repository/
    auth_repository.dart
  services/
    auth_service.dart
test/auth/
  auth_bloc_test.dart
  auth_repository_test.dart
```

## Implementation Steps

1. Implement role-based auth: `admin`, `field_agent`, `citizen`
2. JWT token storage in secure storage (`flutter_secure_storage`)
3. Auto-refresh token on expiry
4. Biometric login option (fingerprint/face)
5. Offline login with cached credentials

## Neon DB Schema

```sql
-- Run on neon/dev branch
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK (role IN ('admin', 'field_agent', 'citizen')) NOT NULL,
  name TEXT NOT NULL,
  phone TEXT,
  district TEXT,
  state TEXT DEFAULT 'Bihar',
  is_active BOOLEAN DEFAULT true,
  last_login TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  device_info JSONB,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_sessions_user_id ON user_sessions(user_id);
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/login` | Login with email + password |
| POST | `/auth/register` | Register new citizen |
| POST | `/auth/refresh` | Refresh JWT token |
| POST | `/auth/logout` | Invalidate session |
| GET | `/auth/me` | Get current user profile |
