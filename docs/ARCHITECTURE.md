# Urban Byte architecture baseline

## Decisions
- Fresh backend; NovaNaut is architecture reference only.
- Flutter follows Stacked conventions from the supplied reference repository.
- One Flutter app with Admin, Supervisor, Waiter, Kitchen and Delivery role-based workspaces.
- Users may have multiple roles; explicit user permission denials override role grants.
- AI low-risk orders may auto-approve only under deterministic server-side rules. Exceptions require `ai.orders.approve`, granted to Admin and authorized Supervisor users.
- Backend authorization is authoritative; frontend visibility is not a security boundary.
- MySQL + Sequelize v6 + migrations; no `sync({ alter: true })`.
- Multi-branch-ready schema; initially one Urban Byte branch.
- Timestamps stored UTC; display in Asia/Karachi. Monetary values use DECIMAL.
- Payment SMS is an untrusted notification, not proof of payment.
- Printer jobs use a queue/local print bridge; cloud server cannot directly access a local USB printer.

## API conventions
- Prefix: `/api/v1`
- Response envelope: `{ success, message, data }`
- JWT access tokens are short-lived; opaque refresh tokens are rotated and stored as hashes.
- Permissions use stable keys such as `orders.create`, `inventory.adjust`, `ai.orders.approve`.

## Implemented baseline
- Express server, environment validation, MySQL connection and health route.
- Initial restaurant/branch/user/RBAC schema and seeded role grants.
- Login, current-user, refresh-token rotation and logout endpoints.
- First administrator bootstrap script.
- Initial Flutter Stacked app and role navigation placeholders.

## Pending business modules
Orders, menu, customers, kitchen tickets, inventory recipes/stock movements, payment verification, AI order tools/approvals, delivery dispatch, printing bridge, reporting and complete role dashboards.
