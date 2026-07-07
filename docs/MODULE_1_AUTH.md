# Module 1: Authentication & User Management

## Overview
Handles user registration, login, role-based access control (Admin, Field Agent, Citizen).

## Implementation Status
- [x] AuthBloc (login, register, logout)
- [x] Login Screen UI
- [x] Neon DB Schema (users table)
- [ ] Register Screen
- [ ] JWT token management
- [ ] Password reset flow

## Neon DB
- Migration file: `db/migrations/01_users_schema.sql`
- Table: `users`
- Roles: `admin`, `field_agent`, `citizen`

## Branches
- Feature: `feature/auth-module`
- Merges into: `develop`

## Environment Variables
```
NEON_DATABASE_URL=postgresql://...
JWT_SECRET=...
```
