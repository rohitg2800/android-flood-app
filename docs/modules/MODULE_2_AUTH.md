# Module 2: Authentication & User Management

## GitHub Branch: `feature/auth-module`

## Implementation Steps
1. Create `lib/features/auth/` folder with:
   - `login_screen.dart`
   - `register_screen.dart`
   - `auth_bloc.dart`
   - `auth_repository.dart`
   - `user_model.dart`
2. Implement role-based auth: Admin, Field Agent, Citizen
3. JWT token storage using `flutter_secure_storage`
4. PR → `develop` with code review

## Folder Structure
```
lib/
  features/
    auth/
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
      models/
        user_model.dart
```

## Neon DB Schema
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK (role IN ('admin','field_agent','citizen')),
  name TEXT,
  phone TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL,
  device_info TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_sessions_user_id ON user_sessions(user_id);
```

## Role Permissions
| Feature | Admin | Field Agent | Citizen |
|---|---|---|---|
| View Alerts | ✅ | ✅ | ✅ |
| Create Alerts | ✅ | ✅ | ❌ |
| Manage Users | ✅ | ❌ | ❌ |
| View Reports | ✅ | ✅ | ❌ |
| Report Incident | ✅ | ✅ | ✅ |
