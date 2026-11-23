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

Order types: `dine_in`, `takeaway`, `delivery`. Status flow: placed → confirmed → preparing → ready → (out_for_delivery) → completed. Cancellation is only allowed before preparation. Server calculates item prices from active variants and branch prices. Client-supplied totals are ignored. Configured restaurant tax is calculated server-side; fixed order discounts are accepted only for authorized staff within the configured percentage cap. Delivery charges remain zero until configured separately. Order creation cannot mark a payment as paid.

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


## Restaurant settings, tax and discounts
- `GET /api/v1/settings` — `settings.manage`; returns restaurant tax, discount cap and receipt header/footer configuration.
- `PUT /api/v1/settings` — `settings.manage`; body supports `taxEnabled`, `taxRate` (percentage), `taxInclusive`, `discountEnabled`, `maxDiscountPercent`, `receiptHeader`, and `receiptFooter`.
- Order creation reads saved restaurant settings on the server. Tax is calculated server-side; inclusive tax is extracted from the discounted price, exclusive tax is added to it. When enabled, the configured service charge is calculated on the discounted subtotal and added to the grand total; the amount is snapshotted on each order and shown on printed/mobile customer bills. A requested fixed discount amount is accepted only from staff with `settings.manage` or `deals.manage`, while discounts are enabled and within the configured cap.
- Migration `20261123000500-add-service-charge-order-amount` adds the service-charge snapshot to orders. Apply migrations before enabling service charge.
- Default tax and service charge are disabled and default maximum discount is 20%. Confirm the applicable tax rules with your accountant before enabling tax. Receipt header/footer fields are saved in settings; printer rendering customization is the next integration step.

## Windows USB / Bluetooth printer bridge
- Project: `windows-printer-bridge/` (.NET 8 for Windows).
- Copy `appsettings.example.json` to `appsettings.json`, set the API URL, dedicated bridge staff access token, branch ID and printer ID.
- USB: install the printer in Windows and set `WindowsPrinterName` to the exact Windows queue name.
- Bluetooth: pair an ESC/POS printer that exposes a Serial Port Profile COM port, then set `BluetoothComPort` (e.g. COM5). BLE-only devices are not supported by this bridge version.
- Run `dotnet run` from the bridge directory on the Windows PC connected to the printer. The worker claims jobs from `POST /api/v1/printing/jobs/claim` and reports `printed` or `failed` to `PATCH /api/v1/printing/jobs/:jobId/status`. The bridge currently uses a configured access token; because normal JWT access tokens expire, renew/update that token when required during development. Automated refresh-token rotation for the bridge is not part of this first version.
- Keep the bridge PC awake and reachable to the API. Never commit `appsettings.json` or a bridge access token. Use a dedicated account with only the required `printing.bridge` permission.


## POS dining tables, order types and payment collection
- Restaurant Settings stores branch-aware dining table definitions and configurable order types. At least one Takeaway type must remain available.
- Dine-in orders must select an active table configured for the selected branch. The API rejects a table already attached to an active dine-in order; completing or cancelling the order releases it.
- POS loads the configured order types and dining tables from `GET /api/v1/settings`; read access is allowed to users with `orders.create`, while updates remain restricted to `settings.manage`. Menu category chips retain the All filter and category-specific filtering.
- Checkout immediately after order creation supports full or partial payment, or Skip payment. A later collection action is available on the Orders tab and shows verified, pending and remaining amounts.
- The cashier must tap Confirm received only after the customer has actually paid. POS sends `markReceived=true`; the backend verifies that payment for users with `payments.record`. Cash-on-delivery is saved without a payment record at checkout and is collected later from the Orders tab. Unconfirmed payment records remain pending for the Payment Verification workflow.
- The system-role seeder grants `payments.record` to Waiter so the POS checkout can record received payments. Apply the updated role grant to existing databases with `npx sequelize-cli db:seed --seed 20261120000100-seed-system-roles.js` from `backend/`.
- Orders include their payment records so the mobile Orders screen can calculate verified, pending and outstanding amounts.

## Mobile Bluetooth thermal printing
- Flutter uses `print_bluetooth_thermal` and `permission_handler` for phone-side Bluetooth thermal printing. Pair the printer in Android Bluetooth settings first, then select it in Printer Management using the paired-device picker; its MAC address is stored as the printer device identifier.
- The printer Test action connects and prints directly from the phone. POS receipts are also sent directly from the phone to the configured active Bluetooth receipt printer.
- Android requires Nearby devices / Bluetooth runtime permission. Classic Bluetooth SPP is supported by the package on Android. iOS support is BLE/MFi dependent; standard Classic SPP printers are not supported by iOS.
- This mobile implementation does not provide direct Android USB printing. USB remains a separate transport and is not routed through the mobile Bluetooth implementation.
- Run `flutter pub get` after pulling changes. Physical printer compatibility still needs verification against the exact printer model and Android device.

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
- The Flutter Staff Management screen supports listing/search, creation, editing name/contact, role reassignment, optional password reset, and activation/deactivation. Deactivation immediately blocks future authenticated access and refresh. Branch membership, audit history and individual permission override UI remain follow-up work. Verify API response envelope compatibility against the deployed backend before production use.


## Expense management
- All expense endpoints require an authenticated user with the matching expense permission.
- `GET /api/v1/expenses` supports `branchId`, `status`, `from`, `to` and `limit` filters.
- `POST /api/v1/expenses` creates a pending expense using `branchId`, `category`, `description`, `amount`, `paymentMethod`, `expenseDate` and optional `reference`.
- `POST /api/v1/expenses/:expenseId/approve` and `POST /api/v1/expenses/:expenseId/reject` review pending expenses. Rejection requires a reason.
- `GET /api/v1/expenses/reports/summary` returns approved totals grouped by payment method.
- Admin and Supervisor receive expense permissions in the system role seeder. Run database migrations and reseed only in a controlled development environment; the role seeder resets role/permission data in its down migration.
- Only approved expenses are included in the expense summary. Expense records are not automatically posted as cash-shift movements, preventing double-counting; cash reconciliation integration remains a separate accounting task.


## Staff branch assignments, permissions and audit history
- Migration `20261123000600-create-staff-branch-audit` creates `user_branches` and `audit_logs`; apply migrations before using the new Staff Management controls.
- Staff create/edit supports assigning zero or more active branches. The first selected branch is marked primary. Branches must belong to the same restaurant.
- Login/current-user permission context includes assigned branch IDs. Order create/list/detail/status updates and dashboard metrics are restricted to assigned branches for non-admin staff. Payment collection/verification/listing/summary and expense create/review/listing/summary also enforce branch assignment.
- Admin role retains restaurant-wide branch access. Non-admin staff with no assigned branches cannot access branch-scoped records.
- Individual permission overrides support Allow, Deny and Use role default. Allow cannot grant a permission the acting non-admin does not already possess. Changes are recorded in immutable audit history.
- Staff API: `GET /staff/branches`, `GET /staff/permissions`, `PUT /staff/:userId/permissions`, `DELETE /staff/:userId/permissions/:permissionId`, and `GET /staff/audit?userId=:id`.
- Flutter Staff Management includes branch checkboxes, per-staff permission controls and audit history.
- Cash shift opening, current-shift listing, entries, closing and reports enforce assigned branch scope.
- Inventory stock views, adjustments, reorder levels, low-stock lists, stock movements, purchase creation/receiving/payments/returns, transfers, supplier ledgers and stock valuation enforce assigned branch scope. Shared restaurant-level catalog items, suppliers and recipes remain restaurant-wide.
- Printer registration, edits, deletion, test jobs, printer lists, receipt/kitchen print queues, print-job history, bridge claiming, status updates and retries enforce assigned branch scope.
- Multi-branch rollout still needs a final review of any remaining branch-specific features and end-to-end tests with at least two branches and non-admin staff.

## Staff administration controls
- Flutter Staff Management supports search, add, edit, role reassignment, optional password reset, and activate/deactivate actions.
- Creating staff requires an explicit Create confirmation; cancelling the dialog does not submit the form.
- Updates use the restaurant-scoped `PATCH /api/v1/staff/:userId` endpoint. The API restricts assignable roles to operational staff roles and prevents users from deactivating their own account.
- Branch membership, audit history, and individual permission override UI are still planned.

## Payment integrity and COD delivery
- Payment collection locks the order row inside its database transaction before checking the remaining balance, preventing concurrent POS payments from exceeding the order total.
- Delivery completion for COD orders requires an explicit collection confirmation and `payments.cod.collect` permission. The backend records a verified COD payment and payment events in the same transaction as delivery completion.
- Non-COD deliveries must already have fully verified payment before they can be marked delivered.

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


## Restaurant analytics dashboard
- `GET /api/v1/reports/analytics?from=YYYY-MM-DD&to=YYYY-MM-DD&branchId=1` — requires `reports.view`, uses Asia/Karachi date boundaries and restaurant-scoped data.
- Returns daily completed-order sales, best-selling products by quantity, highest-revenue products, lowest-margin products where COGS is complete, recorded wastage quantity/cost, and branch comparisons.
- Product/branch margin figures are withheld when any included order line has incomplete COGS. Wastage cost is an estimate only when the stock movement has a recorded unit cost.
- Flutter Financial Dashboard now loads financial and analytics data together, with daily sales/product bar summaries, wastage and branch comparison. Changing the date/branch filters and generating the report refreshes both datasets.
- PDF/Excel export is not part of this milestone.


## Downloadable reports
All export routes require authentication and `reports.view`; they reuse the same restaurant/branch/date-scoped report services as the dashboard.
- `GET /api/v1/reports/financial/export.csv?from=YYYY-MM-DD&to=YYYY-MM-DD&branchId=1` — Excel-compatible UTF-8 CSV with financial totals, cash flow, profitability and product margins.
- `GET /api/v1/reports/financial/export.pdf?from=YYYY-MM-DD&to=YYYY-MM-DD&branchId=1` — print-ready A4 PDF financial summary and product profitability.
- `GET /api/v1/reports/analytics/export.csv?from=YYYY-MM-DD&to=YYYY-MM-DD&branchId=1` — daily sales, product performance, lowest margins, wastage and branch comparison.
- `GET /api/v1/reports/analytics/export.pdf?from=YYYY-MM-DD&to=YYYY-MM-DD&branchId=1` — printable analytics summary.
- CSV output uses UTF-8 BOM for Excel compatibility, quotes cell values and neutralizes spreadsheet formula prefixes in text fields. PDF output uses built-in Helvetica and substitutes unsupported non-ASCII glyphs; it is a basic printable summary, not a branded template.
- These are CSV files (openable in Excel), not native XLSX workbooks. Dedicated supplier ledger exports and Flutter in-app save/share controls are not included yet.
- Run `npm test` in `backend/` to execute report export utility tests.


## Flutter report export center
- The Financial Dashboard provides four export actions: financial PDF, financial CSV (Excel-compatible), analytics PDF and analytics CSV.
- Exports reuse the selected date range and optional branch filter and send the stored access token to the authenticated report endpoints.
- Generated files are written to the app's temporary directory and opened in the native share sheet so staff can save or share them with an installed destination. Files are temporary and may be removed by the operating system.
- Additions require `path_provider` and `share_plus`; run `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `dart format lib`, `flutter analyze` and `flutter test` from `flutter/`.
- CSV remains Excel-compatible CSV, not a native XLSX workbook. The native share sheet behavior must be verified on Android/iOS devices.


## Supplier ledger exports and native Excel workbooks
- `GET /api/v1/inventory/suppliers/:supplierId/ledger/export.pdf` and `.../export.csv` require authentication and `inventory.view`; they are restaurant-scoped and include supplier purchase/payment history plus outstanding balance.
- Flutter Stock Operations supplier ledger offers PDF and native XLSX export actions through the system share sheet.
- The supplier XLSX workbook contains a summary, received purchases and supplier payments. It is generated locally from the authenticated supplier ledger response; the PDF is generated by the backend.
- The Financial Dashboard export center continues to provide financial/analytics PDF and Excel-compatible CSV. Native XLSX for those broader reports remains a separate enhancement.
- Run `flutter pub get`, `dart format lib`, `flutter analyze`, `flutter test` and backend `npm test`; verify PDF/XLSX opening and share behavior on a physical device.


## Fresh database setup and Urban Byte starter data
The backend includes an idempotent Sequelize seeder at `backend/seeders/20261122000100-seed-urban-byte-demo.js`. It creates the Urban Byte restaurant and Shahkot branch, 7 system roles and 27 permissions, starter menu categories/products/regular variants with sample PKR prices, inventory ingredient records and demo suppliers. Existing records are reused; this seeder does not delete or reset business data.

### First-time local setup
1. Create a MySQL database named `urban_byte_db` (or set `DB_NAME` in your local `.env`).
2. Copy `backend/.env.example` to `backend/.env` and set your own MySQL credentials and strong JWT secrets.
3. Set `SEED_ADMIN_EMAIL`, `SEED_ADMIN_NAME`, and a unique `SEED_ADMIN_PASSWORD` (the example intentionally leaves this blank) of at least 12 characters in your local `.env`. Do not commit `.env` or share the password.
4. From `backend/`, run `npm install`, then `npm run db:migrate`, then `npm run db:seed`.
5. Run `npm run dev`. Sign in using the owner email/password configured in your local `.env`.

### Safety and scope
- The seed is intended for a fresh development database; it is safe to rerun for missing starter records, but it does not populate fake sales, payments or expenses that could distort financial reports.
- Demo menu prices and stock thresholds are placeholders. Confirm and update them for the actual Urban Byte menu before taking live orders.
- Ingredient master records are created without fabricated opening stock or purchase costs. Receive actual stock through purchase workflows to establish reliable inventory valuation and COGS.
- A demo owner account is created only when both `SEED_ADMIN_EMAIL` and `SEED_ADMIN_PASSWORD` are configured. No hard-coded production credentials are provided.
- Existing migration files remain the source of truth for schema creation. Run migrations before seeding.


## Database health and initial setup readiness
- `GET /api/v1/health` authenticates a live MySQL connection and reports service/database health.
- `GET /api/v1/health/setup` checks whether the database contains at least one restaurant, branch, active restaurant-linked user, role, permission, menu category, product, inventory item and supplier. It returns `status: ready` or `setup_required` plus counts and individual checks.
- The setup endpoint reports database presence only; it does not expose account credentials or claim that migrations, branch stock, recipes, payment providers or printer hardware are configured.
- A setup endpoint response with HTTP success means the query completed; inspect the `ready` boolean and `checks` map before opening the POS for live use.
- The example environment file now uses placeholders for JWT/WhatsApp secrets and leaves legacy admin bootstrap values blank. Generate unique secrets and configure a real owner password in the private local `.env`; never reuse example credentials.


## Flutter first-time setup screen
- App launch now opens the setup readiness screen, which calls `GET /api/v1/health/setup` and displays the live database checks/counts.
- Use Refresh / Check again after running migrations or the seed script.
- This screen is diagnostic only: it does not create restaurant records, change stock, or create users. After setup is confirmed, sign-in is available from the login flow; the current app entry point is intentionally focused on setup review.
- Configure `API_BASE_URL` for the development machine/device using `--dart-define=API_BASE_URL=http://YOUR_LAN_IP:4000/api/v1`. Android emulator commonly uses `10.0.2.2` to reach the host machine; a physical phone needs the computer's reachable LAN IP and both devices on the same network.


## Troubleshooting: seed validation error and invalid admin login
If `npm run db:seed` fails while inserting the legacy system roles/permissions, pull the latest `main` first. The system-role seeder now uses duplicate-safe inserts so a partially seeded database can be seeded again without dropping tables or deleting existing records.

After seeding, create or repair the local admin login using the credentials you explicitly set in `backend/.env`:
```env
ADMIN_NAME=Urban Byte Owner
ADMIN_EMAIL=your-login-email@example.com
ADMIN_PHONE=
ADMIN_PASSWORD=ChooseYourOwnUniquePassword123!
``
Use a unique password with at least 12 characters. Then run:
```bash
npm run db:seed
npm run admin:repair
npm run dev
``
The repair command deliberately resets the password for the exact configured email/phone, activates that account, links it to the Urban Byte restaurant and ensures the Admin role (and Owner role, if seeded). Do not run it with another person's account identifier. Never paste your real `.env` or password into chat or GitHub.

If the seed still fails, copy the complete error stack including the first Sequelize validation details; the short `ERROR: Validation error` line alone does not identify the exact constraint.


### Repair missing Urban Byte menu / inventory starter records
If the setup screen shows Restaurant, Branch, Owner, Roles and Permissions as Found, but Menu Categories, Menu Products, Inventory Ingredients and Suppliers as Missing, run the targeted idempotent demo-data seeder from `backend/`:
```bash
npm run db:seed:urban-byte
```
This runs only `20261122000100-seed-urban-byte-demo.js`; it does not rerun the legacy role seeder, reset the database, or delete business records. Restart the backend and tap **Check again** in Flutter. Expected starter counts are 6 menu categories, 10 products, 8 inventory items and 3 suppliers (existing records are reused).
If this command fails, share the complete terminal output from the first error line through the stack trace, with credentials redacted. Do not run `db:migrate:undo`, drop tables, or delete rows to fix this.


## Kitchen print groups, customer receipts and paper cutting
- Configure kitchen print groups in Restaurant Settings. Each group selects an active Kitchen/Both printer, one or more menu categories and/or individual products, plus explicit ignored products. Ignored products take precedence over category selection.
- When an order is placed, the backend resolves each group's selected products and generates a kitchen ticket containing only matching items. Bluetooth groups return a rendered slip for direct printing from the POS phone; network/bridge groups create queued print jobs.
- Customer bills are not printed when an order is merely placed or payment is skipped. POS prints the bill after a full verified payment. When an existing unpaid order is later fully settled in Orders, the app prints its customer bill then.
- Printer Test sends a dedicated dummy connection-test slip, never a real customer order.
- Mobile Bluetooth printing sends raw ESC/POS bytes after text: feed 3 lines and full cut (`GS V 0`). The printer must have a physical auto-cutter and support that cut command; printers without a cutter cannot cut paper.
- Dashboard metric tiles open filtered order history. History supports Today, Week, Month, Year and Custom date range with start/end times. Open orders can be viewed across all dates; pending payment history shows outstanding balances after verified payments.
- Dashboard and order-history date/time filters use Pakistan time (UTC+05:00).


## Order completion and login role previews
- Orders can only transition to `completed` from `ready` or `out_for_delivery`, following the order lifecycle.
- The API rejects completion unless the order's payment status is `paid` (fully verified payment). The Orders screen shows a Complete order action for eligible paid orders.
- Order balances are calculated from verified payments only. Pending/unverified payments are shown separately and reduce the amount currently available to collect, but do not count as received funds.
- Login displays one role-preview button per configured role. Selecting one opens that role's workspace using its permission catalogue; this is a UI preview, not authentication or a way to grant access. Protected API calls still require a real login and server-side permissions.
