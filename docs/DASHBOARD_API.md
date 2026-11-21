# Dashboard summary API

Authenticated staff can load `GET /api/v1/dashboard/summary`.

Optional query parameter: `branchId` (must belong to the authenticated restaurant).

Requires `dashboard.view`. The backend applies order visibility based on the authenticated user's effective permissions:
- `orders.view_all`: all restaurant orders.
- `kitchen.orders.view`: confirmed, preparing and ready orders only.
- `orders.view_own`: orders created by the current user.
- No applicable order permission: no order rows are exposed.

Response data:
- `timezone`: `Asia/Karachi`.
- `period`: UTC timestamps defining the current Pakistan calendar day.
- `metrics.todayOrders`, `openOrders`, `completedToday`, `pendingPayments`, `paidRevenueToday`.
- `statusBreakdown` and up to six `recentOrders`.

Revenue includes only orders whose payment status is `paid`; unpaid or pending orders are not counted as revenue. Delivery-specific assignment metrics, expenses/profit, tax policies and date-range reports are separate future work.
