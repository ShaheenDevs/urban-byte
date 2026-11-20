# Urban Byte Restaurant Automation

Fresh monorepo for Urban Byte operations.

## Implemented
- Node.js/Express API with MySQL and Sequelize v6.
- Restaurant/branch-aware users, RBAC roles and permission overrides.
- JWT access authentication with rotating opaque refresh tokens.
- First-admin bootstrap creates Urban Byte restaurant and Shahkot branch.
- Menu categories, products, variants, branch-specific prices and deals API.
- Flutter Stacked login scaffold with secure token storage.

## Setup
1. Install Node.js 20+ and MySQL 8+.
2. `cd backend && npm install`.
3. Copy `.env.example` to `.env`, configure DB settings and unique 32+ character `JWT_ACCESS_SECRET`.
4. Run `npm run db:migrate` then `npm run db:seed`.
5. Set `ADMIN_NAME`, `ADMIN_EMAIL` or `ADMIN_PHONE`, and `ADMIN_PASSWORD` (12+ characters); run `npm run admin:create`; remove bootstrap values afterwards.
6. Run `npm run dev`. API prefix: `/api/v1`.

## Menu endpoints
- `GET /api/v1/menu/categories` — menu.view
- `POST /api/v1/menu/categories` — menu.manage
- `PATCH /api/v1/menu/categories/:categoryId` — menu.manage
- `GET /api/v1/menu/products?branchId=1&categoryId=1&search=pizza` — menu.view
- `POST /api/v1/menu/products` — menu.manage; variants require exactly one default.
- `PUT /api/v1/menu/branches/:branchId/variants/:variantId/price` — menu.manage
- `GET /api/v1/menu/deals?branchId=1` — menu.view
- `POST /api/v1/menu/deals` — deals.manage

All menu data is scoped to the restaurant in the signed access token. Branch prices are separate from base prices. Monetary values use DECIMAL and PKR.

## Next milestones
Orders, customer records, kitchen tickets/KDS, recipe-based inventory, payment verification, AI order agent and approvals, delivery, thermal printing bridge, reports and role dashboards.

Never commit `.env`, secrets, provider keys or customer data. Payment SMS is not proof of payment. MySQL integration testing requires configured database credentials.