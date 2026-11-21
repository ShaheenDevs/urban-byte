# Urban Byte Flutter app

Single Flutter application following the approved Stacked architecture reference.

## Setup
```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1
```

For a physical Android device, set `API_BASE_URL` to the backend host reachable over your LAN. For production, provide the HTTPS API URL through `--dart-define`.

## Implemented
- Stacked `BaseViewModel` login flow.
- Email/phone + password login against `POST /auth/login`.
- Access and refresh tokens stored using `flutter_secure_storage`.
- Initial role-based landing workspace with permission-aware module entry points.
- Live dashboard metrics from `GET /dashboard/summary`: today's orders, open orders, completed orders, pending payments and paid revenue.

The dashboard summary is branch-aware and applies backend order visibility permissions. Delivery-specific assigned-run metrics, report date filters and financial profit/expense analytics are not included yet.

Refresh-on-401, logout UI, generated Stacked routes, complete role dashboards and business workflows are upcoming milestones.
