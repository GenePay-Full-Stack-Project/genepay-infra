# Development Seeded Credentials

*Generated on: Sat Apr 25 06:33:06 +0530 2026*

Accounts inserted directly into active databases via `kubectl exec`.
Hashes were generated dynamically at seed time — not hardcoded.

---

## 1. Admin Dashboard Account (Payment Service — PostgreSQL)

| Field    | Value                                                                |
|----------|----------------------------------------------------------------------|
| Email    | `sysadmin@genepay.com`                                                   |
| Password | `admin123`                                                |
| Hash     | `$2b$10$CsvdWlU.8KyF2ikYMydmcuGiGRUCpFmf8gKZma33ew6ijBxQEUnCC`                                                   |
| URL      | http://app.genepay.local/                                            |

## 2. Banking System Accounts (MongoDB)

| # | Username                        | Password                        | Hash (first 30)                  |
|---|---------------------------------|---------------------------------|----------------------------------|
| 1 | `banktestuser`        | `bankuser123`        | `$2b$10$gn0Cy2p41GgUbk0y6sRdBuh`|
| 2 | `bankuser2`        | `bankuser456`        | `$2b$10$LwIRCFcVYBifeBB12Qxx5ua`|
| 3 | `bankuser3`        | `bankuser789`        | `$2b$10$oCi5xt.AwPdZNSojiKa3p.Q`|

URL: http://bank.genepay.local/login

Each account has a virtual card provisioned with a starting balance of 100,000.

