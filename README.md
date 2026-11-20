# Urban Byte Restaurant Automation

Fresh monorepo for Urban Byte restaurant operations.

## Implemented
- Node.js/Express API with MySQL and Sequelize v6.
- Restaurant/branch-aware users, RBAC roles and permission overrides.
- JWT access authentication with rotating opaque refresh tokens.
- First-admin bootstrap creates Urban Byte restaurant and Shahkot branch.
- Menu categories, products, variants, branch-specific prices and deals API.
- Order creation, item name/price snapshots, order listing/details, status history and controlled status transitions.
- Kitchen tickets generated from confirmed orders, kitchen queue, prepare/ready actions and synchronized order status updates.
- Flutter Stacked login scaffold with secure token storage.

## Setup
1. Install Node.js 20+ and MySQL 8+.
2. `cd backend && npm install`.
3. Copy `.env.example` to `.env`, configure DB settings and unique 32+ character `JWT_ACCESS_SECRET`.
4. Run `npm run db:migrate` then `npm run db:seed`.
5. Set `ADMIN_NAME`, `ADMIN_EMAIL` or `ADMIN_PHONE`, and `ADMIN_PASSWORD` (12+ characters); run `npm run admin:create`; remove bootstrap values afterwards.
6. Run `npm run dev`. API prefix: `/api/v1`.

## Order endpoints
- `POST /api/v1/orders` — orders.create. Send an `Idempotency-Key` header for safe retries.
- `GET /api/v1/orders` — orders.view_own or orders.view_all; supports branchId, status, orderType, limit and offset.
- `GET /api/v1/orders/:orderId` — orders.view_own or orders.view_all.
- `PATCH /api/v1/orders/:orderId/status` — orders.status.update.

Order types: `dine_in`, `takeaway`, `delivery`. Status flow: placed → confirmed → preparing → ready → (out_for_delivery) → completed. Cancellation is only allowed before preparation. Server calculates item prices from active variants and branch prices; client-supplied totals/discounts are ignored. Taxes and delivery charges currently remain zero pending configured policies. Order creation cannot mark a payment as paid.

## Kitchen display endpoints
- `GET /api/v1/kitchen/tickets` — kitchen.orders.view; supports branchId and status filters.
- `PATCH /api/v1/kitchen/tickets/:ticketId/prepare` — kitchen.orders.prepare.
- `PATCH /api/v1/kitchen/tickets/:ticketId/ready` — kitchen.orders.ready.

A kitchen ticket is created when an order is confirmed. Kitchen actions update both the ticket and the linked order status in one database transaction.

## Menu endpoints
- `GET /api/v1/menu/categories` — menu.view
- `POST /api/v1/menu/categories` — menu.manage
- `PATCH /api/v1/menu/categories/:categoryId` — menu.manage
- `GET /api/v1/menu/products?branchId=1&categoryId=1&search=pizza` — menu.view
- `POST /api/v1/menu/products` — menu.manage
- `PUT /api/v1/menu/branches/:branchId/variants/:variantId/price` — menu.manage
- `GET /api/v1/menu/deals?branchId=1` — menu.view
- `POST /api/v1/menu/deals` — deals.manage

All menu and order data is scoped to the restaurant in the signed access token. Never commit `.env`, secrets, provider keys or customer data. MySQL integration testing requires configured database credentials.

## Next
Customer records, kitchen tickets/KDS, recipe-based inventory, verified payment workflow, AI order agent and approvals, delivery, thermal printing bridge, reports and role dashboards.