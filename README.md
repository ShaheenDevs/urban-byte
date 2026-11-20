# Urban Byte

Fresh monorepo for Urban Byte restaurant automation.

- `backend/`: Node.js, Express, Sequelize v6, MySQL REST API.
- `flutter/`: Single Flutter application using Stacked and role-based dashboards.
- `docs/`: architecture and setup notes.

## Current milestone
Foundation and authentication scaffold. Business modules (orders, AI, payments, inventory, kitchen, delivery and printing) are planned and will be implemented in milestones.

## Safety
Never commit `.env`, database credentials, JWT secrets, provider API keys, customer data, or production exports.
