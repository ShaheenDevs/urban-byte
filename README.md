# Urban Byte Restaurant Automation

Fresh monorepo for Urban Byte restaurant operations.

## Implemented
- Node.js/Express API with MySQL and Sequelize v6.
- Restaurant/branch-aware users, RBAC roles and permission overrides.
- JWT access authentication with rotating opaque refresh tokens.
- First-admin bootstrap creates Urban Byte restaurant and Shahkot branch.
- Menu categories, products, variants, branch-specific prices and deals API.
- Order creation, item name/price snapshots, order listing/details, status history and controlled status transitions.
- Kitchen tickets generated from confirmed orders, branch-filtered kitchen queue, prepare/ready actions, kitchen notes and synchronized order status updates.
- Flutter restaurant operations workspace with orders, Kitchen Display System, branch filtering and manual order creation.
- Persistent role-targeted notifications for new orders, kitchen progress/ready events and AI approval requests; per-user inbox, unread count and read actions.
- Role-scoped dashboard summary API with Pakistan-local daily metrics, payment-confirmed revenue, order status breakdown and recent orders.
- Inventory catalog, supplier directory, branch stock/reorder thresholds, purchase receiving, recipe management and immutable stock movement history.
- AI conversation intake, customer/staff message history, structured order-draft risk checks, Admin/Supervisor approval queue and deterministic menu/deal replies.
- Optional branch-level recipe consumption on order completion; missing recipes or insufficient stock block completion atomically.
- Flutter Stacked login scaffold with secure token storage.
- Flutter inventory screen with live branch selection, catalog count, low-stock count, stock balances and item creation.
- Flutter AI Agent workspace for conversation monitoring and Admin/Supervisor approval actions.

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

## Notification endpoints
- `GET /api/v1/notifications` — authenticated user's notification inbox; supports `unread=true` and `limit`.
- `GET /api/v1/notifications/unread-count` — current user's unread notification count.
- `PATCH /api/v1/notifications/:notificationId/read` — mark one of the current user's notifications as read.
- `PATCH /api/v1/notifications/read-all` — mark all of the current user's notifications as read.

Notifications are persisted in MySQL and targeted using current role grants plus explicit user permission overrides. An explicit deny suppresses a role grant; an explicit allow can grant notification eligibility. New orders notify `orders.view_all` staff, confirmed orders notify kitchen staff, kitchen-ready events notify order staff, and AI drafts requiring review notify users with `ai.orders.approve`. Notification writes are best-effort after the business transaction commits so a notification outage does not undo an order. Flutter exposes an inbox sheet and unread badge on role dashboards and the operations workspace.

## Kitchen display endpoints
- `GET /api/v1/kitchen/tickets` — kitchen.orders.view; supports branchId and status filters.
- `PATCH /api/v1/kitchen/tickets/:ticketId/prepare` — kitchen.orders.prepare.
- `PATCH /api/v1/kitchen/tickets/:ticketId/ready` — kitchen.orders.ready.

A kitchen ticket is created when an order is confirmed. Kitchen actions update both the ticket and the linked order status in one database transaction. The Flutter KDS supports branch filtering (when branch access is available), pull-to-refresh, order/customer details, kitchen notes, item quantities and permission-aware prepare/ready actions. Order and kitchen data are loaded independently according to the signed-in user's permissions.

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

## WhatsApp Cloud API webhook
- Configure `WHATSAPP_VERIFY_TOKEN`, `WHATSAPP_APP_SECRET`, `WHATSAPP_RESTAURANT_ID`, and `WHATSAPP_BRANCH_ID` in the backend environment. Never commit real secrets.
- Set the Meta webhook callback URL to `https://YOUR_API_HOST/api/v1/webhooks/whatsapp/webhook` and subscribe to the `messages` field.
- `GET` verifies the Meta webhook challenge; `POST` verifies `X-Hub-Signature-256` against the exact raw request body, deduplicates provider message IDs, and stores inbound text messages as WhatsApp AI conversations/messages.
- `POST /api/v1/ai/conversations/:conversationId/whatsapp/send` — authenticated staff with `ai.view`; sends a text reply through WhatsApp Cloud API and stores its provider message ID.
- Configure `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACCESS_TOKEN`, and optional `WHATSAPP_GRAPH_VERSION` in `.env`. Use a long-lived/system-user token with the required WhatsApp messaging permissions; never commit it.
- The same signed webhook ingests inbound text, automatically replies to greetings/menu/deal questions using the active database menu and branch prices, and processes provider delivery/read/failure status callbacks. This is a deterministic rule-based assistant, not an LLM; complex order placement still uses the structured draft and customer-confirmation workflow. Outbound messages are stored with queued/sent/delivered/read/failed states.
- Outbound send is only available for existing WhatsApp conversations with a valid customer number. Meta's messaging window/template rules still apply; this implementation sends text messages only and does not yet handle approved template messages, media, interactive buttons, retries or an LLM.
- Configure a public HTTPS API and real Meta app credentials before testing with WhatsApp. A successful API response means Meta accepted the send request, not that the customer received or read it.

## AI agent endpoints
The WhatsApp order assistant supports examples such as `2 large pizza`, `do zinger burger`, `cart`, `delivery`, `takeaway`, `dine in`, `clear cart`, and `CONFIRM`. Product names, active variants and branch prices are loaded from the database. The cart is stored in the AI conversation context. A customer must select an order type and provide the required delivery address/table before sending an explicit `CONFIRM` / `YES CONFIRM` phrase. A plain `yes`, `haan` or `ji` never places an order. The `clear cart` command is handled before generic cart-summary matching. The server revalidates products and prices when creating the order; no client-provided prices are trusted. Run `npm test` in `backend/` for the order parser unit tests.
- `POST /api/v1/ai/conversations` — ai.view; opens a manual/WhatsApp/phone/web conversation.
- `GET /api/v1/ai/conversations` — ai.view; lists restaurant-scoped conversations.
- `GET /api/v1/ai/conversations/:conversationId` — ai.conversations.view; loads conversation and history.
- `POST /api/v1/ai/conversations/:conversationId/messages` — ai.view; appends a customer, assistant, staff or system message.
- `POST /api/v1/ai/conversations/:conversationId/order-draft` — ai.view; validates a structured order draft and creates a pending approval request.
- `GET /api/v1/ai/approvals` and `POST /api/v1/ai/approvals/:requestId/review` — ai.orders.approve; Admin and authorized Supervisor approval workflow.
- `POST /api/v1/ai/conversations/:conversationId/whatsapp/send` — ai.view; sends an outbound WhatsApp text reply and records provider delivery status.

The current AI milestone provides deterministic menu/deal lookup, conversational cart building, backend risk checks, order conversion and staff approvals. A draft is auto-approved only when the customer explicitly confirms it, branch and order type are valid, required delivery/table details are present, quantities are valid, and no discount/custom price is requested. Backend order creation revalidates active products and calculates prices from server-side menu/branch prices. Drafts with any risk reason remain pending for an authorized Admin/Supervisor. Approved drafts create normal orders with source `ai`; payment remains unpaid and is never auto-marked paid. WhatsApp inbound/outbound messaging is integrated at the provider API layer but requires real Meta credentials and a public HTTPS webhook. The menu/order assistant currently uses deterministic rules and database lookups; it can build a conversation cart, handle quantities and product sizes, set delivery/takeaway/dine-in details, show a subtotal, and submit only after explicit customer confirmation. An external LLM provider is not connected.

## Flutter AI Agent setup
The AI workspace is available to users with `ai.view` or `ai.orders.approve`. It lists conversations and, for authorized approvers, pending order requests with risk reasons. Approve & create order creates an AI-source order using server-side menu prices; the order remains unpaid. Customer confirmation is required for deterministic auto-approval. The UI can send outbound WhatsApp text messages for WhatsApp conversations when Meta credentials are configured. AI responses are currently deterministic; no external LLM is connected.

## Flutter inventory setup
Run `cd flutter && flutter pub get && flutter test`. Set `API_BASE_URL` with `--dart-define` for a physical device or deployed API. The inventory dashboard reads the active branch list from the backend; it does not assume branch ID 1.

## Remaining milestones
Customer records, verified payment workflow, delivery workflow, thermal printing bridge, reporting, full role-specific dashboard KPIs and live push notifications (FCM/APNs).

## Staff management
- All staff endpoints require a valid access token and `settings.manage` permission.
- `GET /api/v1/staff?search=ali&active=true` — list restaurant-scoped staff; password hashes are never returned.
- `POST /api/v1/staff` — create a staff account with name, email or phone, a temporary password (minimum 12 characters), and roleIds.
- `GET /api/v1/staff/roles` — list assignable role catalog.
- `GET /api/v1/staff/permissions` — list permission catalog for administrative review.
- `PATCH /api/v1/staff/:userId` — update profile, active state, password or roleIds.
- Role assignment is restricted to supervisor, waiter, kitchen, cashier and delivery; owner/admin/system roles cannot be granted through this endpoint. Permission override writes are intentionally not exposed until a dedicated privilege-escalation-safe policy is implemented.
- Passwords are hashed with bcrypt cost 12. Deactivated users are rejected by authentication/session refresh. Last login is maintained by the authentication service.
- Branch-specific staff membership and activity audit events are not yet implemented; current user records are restaurant-scoped.


## Flutter staff management
- Added a Stacked staff directory with search, refresh, role display and an Add Staff form.
- Staff API calls read the access token from Flutter Secure Storage; no token is hardcoded.
- The StaffView and StaffService are registered in `flutter/lib/app/app.dart`; the service locator registration is updated.
- From `flutter/`, run `flutter pub get`, then `dart run build_runner build --delete-conflicting-outputs` to regenerate Stacked routes/locator after annotation changes, then `dart format lib`, `flutter analyze` and `flutter test`.
- The current UI provides listing and creation. Editing/deactivation controls, branch membership, audit history and individual permission overrides remain follow-up work. Verify API response envelope compatibility against the deployed backend before production use.


## Expense management
- All expense endpoints require an authenticated user with the matching expense permission.
- `GET /api/v1/expenses` supports `branchId`, `status`, `from`, `to` and `limit` filters.
- `POST /api/v1/expenses` creates a pending expense using `branchId`, `category`, `description`, `amount`, `paymentMethod`, `expenseDate` and optional `reference`.
- `POST /api/v1/expenses/:expenseId/approve` and `POST /api/v1/expenses/:expenseId/reject` review pending expenses. Rejection requires a reason.
- `GET /api/v1/expenses/reports/summary` returns approved totals grouped by payment method.
- Admin and Supervisor receive expense permissions in the system role seeder. Run database migrations and reseed only in a controlled development environment; the role seeder resets role/permission data in its down migration.
- Only approved expenses are included in the expense summary. Expense records are not automatically posted as cash-shift movements, preventing double-counting; cash reconciliation integration remains a separate accounting task.


## Supplier ledger and purchase payments
- Existing inventory purchase drafts can be received into branch stock; this milestone adds supplier payment records and supplier account balances.
- `GET /api/v1/inventory/suppliers/:supplierId/ledger` returns received purchases, recorded payments, total purchases, total paid and outstanding balance.
- `POST /api/v1/inventory/purchases/:purchaseId/payments` records a supplier payment with amount, method (`cash`, `bank_transfer`, `easypaisa`, `jazzcash` or `card`), and optional reference/notes.
- Payments are limited to the outstanding balance of that received purchase and are saved transactionally. This does not automatically create a cash-shift entry or expense; cash reconciliation/accounting posting needs a separate explicit workflow.
- Run the new `20261121000700-create-purchase-payments` migration before using supplier payment endpoints.
- Flutter Stock Operations now opens a supplier ledger from the supplier list and supports recording a payment against an outstanding received purchase.


## Financial reporting
- `GET /api/v1/reports/financial?from=YYYY-MM-DD&to=YYYY-MM-DD&branchId=1` — requires `reports.view`; dates are interpreted in Asia/Karachi.
- Returns verified payment collections, approved expenses, received purchase totals, supplier payments and outstanding balances, plus cash-only movement summary.
- Supplier payment totals are scoped through purchase IDs belonging to the selected restaurant/branch. Received purchase outstanding is calculated from payments already recorded against those received purchases.
- Financial reporting deliberately does not label revenue minus purchases as profit: purchases increase inventory and are not necessarily cost of goods sold. Gross/net profit remains unavailable until stock-consumption/recipe costing and other accounting adjustments are reconciled.
- Cash-flow summary is limited to recorded cash collections, approved cash expenses and cash supplier payments. Non-cash methods are excluded. Supplier payments and expenses are separate categories and are not automatically posted into cash-shift entries.
- Flutter Financial Dashboard is available at the generated `Routes.financialReportView` route; it supports date range and optional branch ID filters.


## Recipe-based COGS and profitability
- Migration `20261121000800-add-order-item-cogs` adds `cogs_total` and `cogs_status` to order items. Apply it before deploying this costing change.
- When a completed order triggers branch inventory auto-deduction, the backend snapshots recipe ingredient cost per order line using the weighted average of that branch's recorded purchase stock movements.
- Any ingredient with missing or partially unpriced purchase receipts marks the affected order line `missing_cost`; incomplete costs are never silently treated as zero.
- `GET /api/v1/reports/financial` now reports completed-order sales revenue, estimated recipe COGS, gross profit and net profit (approved expenses deducted) only when every completed order line in the selected period has a complete cost snapshot. It also returns product-level quantity, revenue, COGS and gross margin data; products with missing costs are flagged individually.
- Profit uses completed-order revenue, not verified payment collections. Supplier payments and received purchase totals are excluded from profit to avoid double-counting inventory acquisition and supplier settlement.
- For reliable costs, receive ingredient purchases with correct unit costs, configure recipes and enable inventory auto-deduction for the relevant branch before completing orders. Historical orders are not retroactively costed by this migration.
- This is an operational estimate based on weighted-average purchase costs; it does not yet account for labor, utilities allocation, tax accounting, spoilage adjustments or opening stock valuation.
