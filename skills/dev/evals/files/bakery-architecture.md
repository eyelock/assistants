# Crumb: architecture today

Crumb takes online orders for three bakeries in one city.

- Team: three developers, one of them part-time. One product, one deploy pipeline.
- Code: one Node/TypeScript app (Express) with four modules: `orders`, `menu`, `notifications` (email and SMS
  when an order is ready), `users` (accounts, login). Modules call each other as plain functions.
- Data: one Postgres database; each module has its own tables.
- Load: about 400 orders a day, peaking at 60 an hour on Saturday mornings. p95 latency 120 ms.
- Deploys: twice a week, all modules together; a deploy takes 6 minutes.
- Pain points: the `notifications` module's SMS provider is slow (2-4 s per send) and its calls happen inside the
  order request, so a slow provider makes checkout slow. A bug in `menu` once took checkout down.
