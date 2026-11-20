# Urban Byte Restaurant Automation

Fresh monorepo for the Urban Byte restaurant operations platform.

## Repository layout
- `backend/` — Node.js, Express 4, JavaScript CommonJS, MySQL and Sequelize v6 REST API.
- `flutter/` — Flutter application using Stacked and role-based navigation.
- `docs/` — architecture and implementation notes.

## Implemented foundation
- Express server, environment validation, CORS allow-list, Helmet security headers, API rate limiting and centralized error handling.
- MySQL/Sequelize connection and initial restaurant, branch, user and RBAC migrations.
- Admin, Supervisor, Waiter, Kitchen and Delivery roles with permission grants.
- Multi-role permission resolution and explicit user deny overrides.
- JWT access-token authentication, opaque refresh-token rotation (SHA-256 hashes stored in DB), logout/revocation and current-user endpoint.
- First-admin bootstrap script; credentials are supplied locally and are not committed.
- Initial Flutter Stacked scaffold.

## Backend setup
1. Install Node.js 20+ and MySQL 8+.
2. Run `cd backend && npm install`.
3. Copy `.env.example` to `.env`; configure DB credentials, a unique `JWT_ACCESS_SECRET` (32+ characters) and `APP_ORIGIN`.
4. Run `npm run db:migrate` then `npm run db:seed`.
5. Temporarily set `ADMIN_NAME`, `ADMIN_EMAIL` (or `ADMIN_PHONE`) and `ADMIN_PASSWORD` (12+ characters) in `.env`; run `npm run admin:create`, then remove those bootstrap values.
6. Start with `npm run dev`. API prefix: `/api/v1`; health endpoint: `/api/v1/health`.

## Authentication endpoints
- `POST /api/v1/auth/login` — identifier and password.
- `POST /api/v1/auth/refresh` — rotates the refresh token; old token is revoked.
- `POST /api/v1/auth/logout` — revokes the supplied refresh token.
- `GET /api/v1/auth/me` — authenticated profile and resolved permissions.

## Pending business modules
Orders, menu, customers, kitchen tickets, inventory and recipes, payment verification, AI order tools and approvals, delivery dispatch, thermal printing bridge, reporting and complete role dashboards.

## Security
Never commit `.env`, database credentials, JWT secrets, provider API keys, customer data or production exports. Payment SMS notifications are not proof of payment.

## Verification
Permission resolver unit tests and JavaScript syntax checks run without MySQL. Migrations and auth endpoints still require integration tests against a configured MySQL database.
