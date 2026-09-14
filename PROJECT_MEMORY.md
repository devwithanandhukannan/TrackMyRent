# RentTrack - Project TODO & Memory Pool Document 🧠📝

> **Purpose**: This document serves as the single source of truth, living engineering memory pool, architectural reference, and progress tracker for **RentTrack**.
> **Rule**: Reference this file before coding any new feature. Update this file whenever code is modified, features are added, or milestones are completed.

---

## 🏛️ System Architecture & Engineering Standards

### Stack Architecture
- **Mobile Application**: Flutter (Dart) — Mobile-First (Android & iOS). State Management: Clean Architecture with Riverpod/Provider.
- **Admin Web Dashboard**: Next.js 14+ (React, TypeScript, Tailwind CSS, Recharts).
- **Backend API**: Node.js (TypeScript, Express.js/NestJS, Prisma ORM, RESTful API).
- **Database**: PostgreSQL (Relational Data Model with JSONB for dynamic custom fields).
- **Authentication**: JWT & Firebase Auth (Role-Based Access Control: `SUPER_ADMIN`, `ORG_ADMIN`, `STAFF`).
- **Integrations**: WhatsApp Deep Linking & Cloud API, Firebase Cloud Messaging (FCM).

---

## 🔗 Entity Relationships & Data Model (ERD Reference)

```
[Organization] ──1:N──> [Users / Staff]
     │
     ├──1:N──> [Plans] ──1:N──> [Groups / Batches]
     │            │                    │
     │            └──────1:N───────────┴──1:N──> [Members / Tenants]
     │                                                    │
     ├──1:N──> [Expenses]                                 ├──1:N──> [Payment_Schedules]
     │                                                    │              │
     ├──1:N──> [Custom_Field_Definitions]                │              └──1:N──> [Transactions]
     │                                                    │
     └──1:1──> [Subscriptions & WhatsApp Credits]       └─ N:1 (via JSONB) ──> [Custom_Field_Values]
```

### Key Business Logic Formulas & Rules

1. **Duration & Collection Schedule Logic**:
   - **Frequency**: Interval between payments (e.g., Monthly, 3 Months, 6 Months, 12 Months).
   - **Collection Day**: Exact due date within cycle (`FIRST_DAY_OF_MONTH`, `LAST_DAY_OF_MONTH`, or `CUSTOM_DAY_OF_MONTH` e.g., 5th, 10th).
   - *Rule*: "First day of the month" controls the specific due date, NOT monthly frequency.

2. **Pending Amount Formula**:
   $$\text{Total Pending Amount} = \sum (\text{Unpaid Schedule Amounts}) - \sum (\text{Frozen Schedule Amounts})$$
   - *Rule*: Frozen months (`FROZEN`) are visible in history but strictly excluded from all pending totals, collection reports, and Dashboard metrics.

3. **Collection Rate Percentage**:
   $$\text{Collection Rate (\%)} = \left( \frac{\text{Total Collected Amount}}{\text{Total Expected Amount}} \right) \times 100$$

4. **WhatsApp Credit System**:
   - `Normal Plan` (e.g., Basic ₹299): 0 included credits. Extra credits bought separately.
   - `Credit Plan` (e.g., Plus ₹599): Fixed included credits (e.g. 100).
   - **Credit Expiry Rule**: Purchased credits **NEVER** expire. Subscription expiration does not clear available credits.

---

## 📋 Master TODO Checklist

### Phase 1: Workspace Setup & Database Schema Initialization
- [x] **Task 1.1**: Initialize Project Memory Pool (`PROJECT_MEMORY.md`).
- [x] **Task 1.2**: Initialize Node.js Backend with TypeScript, Express, and Prisma ORM.
- [x] **Task 1.3**: Configure PostgreSQL Database & Prisma Schema (`Users`, `Members`, `Plans`, `Groups`, `PaymentSchedules`, `Expenses`, `Credits`) via Docker Compose with local persistent storage (`./docker-data/postgres`).
- [x] **Task 1.4**: Initialize Next.js Web Admin App (`admin-web`) with Tailwind CSS & App Router.
- [x] **Task 1.5**: Initialize Flutter Mobile App structure (`mobile_app`) with clean folder architecture.

### Phase 2: Node.js Backend API Development
- [x] **Task 2.1**: Auth Module (Register, Login, JWT authentication, RBAC middleware).
- [x] **Task 2.2**: Organization & Admin Custom Fields API (CRUD dynamic field definitions).
- [x] **Task 2.3**: Plans & Groups API (Plan creation, Sub-group linking, hierarchy logic).
- [x] **Task 2.4**: Member Management API (CRUD members, dynamic custom fields serialization, duration auto-setter).
- [x] **Task 2.5**: Payment Engine API:
  - [x] Automatic Payment Schedule Generator (3/6/12 Month logic + Collection Day).
  - [x] Mark Paid / Mark Unpaid endpoint with confirmation logging.
  - [x] Freeze / Unfreeze Month logic & pending sum calculator.
- [x] **Task 2.6**: Expense Management API (CRUD expenses, standard & custom categories).
- [x] **Task 2.7**: Reports & Analytics API (Income/Expense aggregations, Collection Rate, Plan/Group revenue breakdown).
- [x] **Task 2.8**: WhatsApp & Credit Manager API (Deduct credits, check balance, credit purchasing).

### Phase 3: Flutter Mobile App Development
- [x] **Task 3.1**: App Shell & Navigation (Bottom Nav: Home, Plans, Expenses, Reports).
- [x] **Task 3.2**: Home Dashboard (Summary Cards: Total Members, Paid, Unpaid, Total Collected, Quick Actions).
- [x] **Task 3.3**: Member Management Screens:
  - [x] Add/Edit Member Form with Plan Auto-duration logic & dynamic Custom Fields renderer.
  - [x] Member List with status badges (🟢 Paid, 🔴 Unpaid, ❄️ Frozen).
  - [x] Unpaid & Frozen Member Sections.
- [x] **Task 3.4**: Member Detail Page & Payment Confirmation Flow:
  - [x] Personal & Membership Info Display + Call/WhatsApp quick actions.
  - [x] Paid History, Unpaid History, Frozen History sections.
  - [x] Payment Confirmation Modal (Send Invoice / Send Personal Message / Skip).
  - [x] Unpaid Reversion Warning Modal.
  - [x] Freeze / Unfreeze Month Action Handler.
- [x] **Task 3.5**: Plans & Groups Screens.
- [x] **Task 3.6**: Expense Management Screens.
- [x] **Task 3.7**: Reports & Analytics Screens.
- [x] **Task 3.8**: Settings & Credit Store.

### Phase 4: Next.js Admin Web Dashboard
- [x] **Task 4.1**: Auth Pages & Org Setup.
- [x] **Task 4.2**: Dashboard with Charts & Metrics (Recharts).
- [x] **Task 4.3**: Member & Tenant Grid with Filter & Bulk Actions.
- [x] **Task 4.4**: Custom Fields Engine Configurator UI.
- [x] **Task 4.5**: WhatsApp Bulk Messaging & Credit Store Integration.

### Phase 5: Verification, Testing & Deployment
- [x] **Task 5.1**: Backend Unit & Integration Build Verification.
- [x] **Task 5.2**: Flutter Integration Structure Verification.
- [x] **Task 5.3**: End-to-End System Schema & API Verification.

---

## 📜 Feature & Engineering Memory Pool Log (Changelog)

### [2026-09-14] - Purged Static Mock Data & Dynamic API Data Fetching
- **Mobile Dashboard Dynamic Integration (`HomeScreenView`)**: Refactored static hardcoded metric values (`156`, `120`, `30`, `₹84,000`) and mock member arrays (`Ahmed`, `Rahul`, `Arjun`) into an asynchronous live loader (`_loadDashboardData()`) bound to `ApiService`.
- **Live Summary Metrics & Filtered Lists**: Dashboard now renders real dynamic member totals, actual paid income, live unpaid member lists, and frozen members directly from PostgreSQL database. Added pull-to-refresh (`RefreshIndicator`).
- **Code Analysis**: Executed `flutter analyze` — **No issues found! (0 errors, 0 warnings)**.
- **Memory Pool Updated**: `PROJECT_MEMORY.md` updated.


### [2026-09-14] - Full Dynamic Production Feature Rollout from `TrackmyRent.pdf`
- **Dynamic Custom Expense Categories**: Built backend controller `expenseCategoryController.ts` and API routes `/api/expenses/categories` for creating & managing custom business categories dynamically.
- **WhatsApp Templates Engine**: Built backend `whatsappTemplateController.ts` and routes `/api/settings/whatsapp-templates` with dynamic tag replacements (`{name}`, `{amount}`, `{due_date}`, `{month}`).
- **Member Detail View & Single Member Payment History (`MemberDetailScreen`)**: Displays Personal Info, Membership Info, Call (`tel:`) and WhatsApp (`wa.me`) quick actions, Paid History, Unpaid History with **Freeze Month** toggle (excluding frozen dues from pending calculations), and Frozen History with Unfreeze action.
- **Settings Screen (`SettingsScreen`)**: Tabbed view for WhatsApp Templates editor, Custom Fields manager, and Subscription & WhatsApp Credit Store.
- **Backend Verification**: Executed `npm run build` in `backend` — **0 compilation errors!**
- **Flutter Verification**: Executed `flutter analyze` in `mobile_app` — **0 errors!**

