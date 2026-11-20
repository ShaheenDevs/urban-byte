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
- Inventory catalog, supplier directory, branch stock/reorder thresholds, purchase receiving, recipe management and immutable stock movement history.
- AI conversation intake, customer/staff message history, structured order-draft risk checks and Admin/Supervisor approval queue.
- Optional branch-level recipe consumption on order completion; missing recipes or insufficient stock block completion atomically.
- Flutter Stacked login scaffold with secure token storage.
- Flutter inventory screen with live branch selection, catalog count, low-stock count, stock balances and item creation.

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

## Inventory endpoints
- `GET /api/v1/inventory/branches` — active branches for the authenticated restaurant; inventory.view.
- `GET /api/v1/inventory/items` — inventory.view.
- `POST /api/v1/inventory/items` — inventory.manage; body includes name, itemType (`ingredient`, `finished_good`, `packaging`, `other`), unit (e.g. `g`, `kg`, `ml`, `l`, `piece`, `pack`), optional SKU and lowStockThreshold.
- `GET /api/v1/inventory/stock?branchId=1` — inventory.view.
- `POST /api/v1/inventory/stock/adjust` — inventory.adjust; body includes branchId, inventoryItemId, quantityChange (positive or negative), optional movementType (`adjustment`, `waste`, `return`) and note. Negative balances are rejected and each change is recorded.
- `GET /api/v1/inventory/movements?branchId=1&inventoryItemId=1` — inventory.view.
- `POST /api/v1/inventory/suppliers` and `GET /api/v1/inventory/suppliers` — inventory.manage / inventory.view.
- `POST /api/v1/inventory/purchases` — create a draft purchase with branchId, optional supplierId and item lines (inventoryItemId, quantity, unitCost).
- `POST /api/v1/inventory/purchases/:purchaseId/receive` — receive a draft once; stock and purchase movements are committed in one transaction.
- `GET /api/v1/inventory/purchases` — list purchases.
- `PUT /api/v1/inventory/recipes` — save recipe for productVariantId with yieldQuantity and ingredient lines (inventoryItemId, quantity).
- `GET /api/v1/inventory/recipes` — list active recipes.
- `PUT /api/v1/inventory/stock/reorder-level` — set branchId, inventoryItemId and reorderLevel.
- `GET /api/v1/inventory/stock/low?branchId=1` — list low-stock items.
- `PATCH /api/v1/inventory/branches/:branchId/auto-deduction` — settings.manage only; body `{ "enabled": true }` checks that every active prepared or retail product has a recipe before enabling branch-level deductions.

Recipe-based auto-deduction is disabled by default per branch. Enable auto deduction through the Admin-only branch endpoint only after recipes and opening stock have been reconciled. When enabled, order completion deducts ingredient quantities in the same transaction; missing recipes or insufficient stock block completion. The deduction timestamp and stock movement references prevent repeat deductions.

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

## AI agent endpoints
- `POST /api/v1/ai/conversations` — ai.view; opens a manual/WhatsApp/phone/web conversation.
- `GET /api/v1/ai/conversations` — ai.view; lists restaurant-scoped conversations.
- `GET /api/v1/ai/conversations/:conversationId` — ai.conversations.view; loads conversation and history.
- `POST /api/v1/ai/conversations/:conversationId/messages` — ai.view; appends a customer, assistant, staff or system message.
- `POST /api/v1/ai/conversations/:conversationId/order-draft` — ai.view; validates a structured order draft and creates a pending approval request.
- `GET /api/v1/ai/approvals` and `POST /api/v1/ai/approvals/:requestId/review` — ai.orders.approve; Admin and authorized Supervisor approval workflow.

The current AI milestone provides deterministic intake, backend risk checks, order conversion and staff approvals. A draft is auto-approved only when the customer explicitly confirms it, branch and order type are valid, required delivery/table details are present, quantities are valid, and no discount/custom price is requested. Backend order creation revalidates active products and calculates prices from server-side menu/branch prices. Drafts with any risk reason remain pending for an authorized Admin/Supervisor. Approved drafts create normal orders with source `ai`; payment remains unpaid and is never auto-marked paid. This is not yet a connected LLM or WhatsApp integration. Provider credentials and webhooks are required before connecting external messaging or AI services.

## Flutter inventory setup
Run `cd flutter && flutter pub get && flutter test`. Set `API_BASE_URL` with `--dart-define` for a physical device or deployed API. The inventory dashboard reads the active branch list from the backend; it does not assume branch ID 1.

## Remaining milestones
Customer records, verified payment workflow, AI order agent and approvals, delivery workflow, thermal printing bridge, reporting and full role-based Flutter dashboards.