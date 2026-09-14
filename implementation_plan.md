# RentTrack - വികസന വിഭാവനം (Implementation Plan)

Gym, Tuition Center, Academy, PG, Hostel, Rental Property എന്നിവയ്ക്കായുള്ള സമ്പൂർണ്ണ ഫ്ലട്ടർ (Mobile), നെക്സ്റ്റ്.ജെഎസ് (Admin Web), നോഡ്.ജെഎസ് (Backend API) മാനേജ്‌മെന്റ് ആപ്ലിക്കേഷന്റെ നിർമ്മാണ പദ്ധതി.

---

## 1. ആർക്കിടെക്ചർ & ടെക്നോളജി സ്റ്റാക്ക് (System Architecture & Tech Stack)

| ലെയർ (Layer) | ടെക്നോളജി (Technology) | വിവരണം (Description) |
|---|---|---|
| **Mobile App** | **Flutter (Dart)** | iOS, Android മൊബൈൽ ആപ്പ്. റിയൽ-ടൈം അപ്‌ഡേറ്റുകൾ, വാട്‌സ്ആപ്പ് ഡീപ്പ് ലിങ്കിംഗ്/ഇന്റഗ്രേഷൻ. |
| **Admin Web Panel** | **Next.js 14+ (React, Tailwind CSS)** | അഡ്മിൻമാർക്ക് റിപ്പോർട്ടുകൾ, സബ്‌സ്‌ക്രിപ്‌ഷൻ, കസ്റ്റം ഫീൽഡുകൾ എന്നിവ കൈകാര്യം ചെയ്യാനുള്ള ഡാഷ്‌ബോർഡ്. |
| **Backend API** | **Node.js (Express.js / NestJS)** | RESTful API, ഓതന്റിക്കേഷൻ, ബിസിനസ്സ് ലോജിക്, പേയ്‌മെന്റ് ഗേറ്റ്‌വേ ഇന്റഗ്രേഷൻ. |
| **Database** | **PostgreSQL (with Prisma ORM)** | മെമ്പർമാർ, പ്ലാനുകൾ, പേയ്‌മെന്റുകൾ, എക്സ്‌പെൻസുകൾ, ക്രെഡിറ്റുകൾ എന്നിവ കൃത്യമായി സൂക്ഷിക്കാൻ. |
| **Authentication** | **JWT & Firebase / Supabase Auth** | സെക്യൂർ ലോഗിൻ & റോൾ ബേസ്ഡ് ആക്‌സസ് (Admin, Staff, Owner). |
| **Storage & Notifications** | **AWS S3 / Cloudinary & Firebase FCM** | ഫയലുകൾ, ഐഡി കാർഡുകൾ സൂക്ഷിക്കാനും പുഷ് നോട്ടിഫിക്കേഷനുകൾക്കാനും. |

---

## 2. ഡാറ്റാബേസ് സ്കീമ ഡിസൈൻ (Database Schema Design)

### പ്രധാന ടേബിളുകൾ (Core Tables):
1. **Organizations / Businesses**: `id`, `name`, `type` (Gym, PG, Academy, Rental), `owner_id`, `created_at`.
2. **Users / Staff**: `id`, `org_id`, `name`, `email`, `phone`, `role` (Admin/Staff).
3. **Plans**: `id`, `org_id`, `name`, `price`, `duration_type` (30_days, custom_monthly), `custom_day`, `description`.
4. **Groups / Batches**: `id`, `plan_id`, `name`, `schedule`, `capacity`.
5. **Members / Tenants**:
   - `id`, `org_id`, `plan_id`, `group_id`, `full_name`, `phone`, `dob`, `joining_date`, `duration`, `notes`, `status` (Active, Inactive).
   - `custom_fields_data` (JSONB) - Aadhaar, Address, Emergency Contact, etc.
6. **Payment_Schedules**:
   - `id`, `member_id`, `month_year` (e.g., 2026-07), `due_date`, `amount`, `status` (PAID, UNPAID, FROZEN), `frozen_at`.
7. **Transactions / Payments**:
   - `id`, `member_id`, `schedule_id`, `amount_paid`, `payment_method` (Cash, UPI, Bank), `payment_date`, `receipt_url`.
8. **Expenses**: `id`, `org_id`, `title`, `amount`, `category_id`, `expense_date`, `notes`.
9. **Expense_Categories**: `id`, `org_id`, `name`, `is_custom`.
10. **Subscriptions & Credits**: `id`, `org_id`, `plan_type` (Normal/Credit), `subscription_expiry`, `purchased_credits`, `used_credits`.

---

## 3. വികസന ഘട്ടങ്ങൾ (Step-by-Step Development Roadmap)

### 📌 Phase 1: പ്രൊജക്ട് സെറ്റപ്പും ഡാറ്റാബേസ് ആർക്കിടെക്ചറും (Setup & Infrastructure)
- **Step 1.1**: Node.js backend പ്രൊജക്റ്റ് സെറ്റപ്പ് ചെയ്യുക (Express.js/NestJS, TypeScript, Prisma ORM).
- **Step 1.2**: PostgreSQL ഡാറ്റാബേസ് സ്കീമയും മൈഗ്രേഷനുകളും തയ്യാറാക്കുക.
- **Step 1.3**: Next.js Admin Portal ബേസിക് ടെംപ്ലേറ്റ്, ലേഔട്ട്, Tailwind CSS ആഡ് ചെയ്യുക.
- **Step 1.4**: Flutter പ്രൊജക്റ്റ് സെറ്റപ്പ് ചെയ്യുക (Riverpod / Provider State Management, Clean Architecture).

### 📌 Phase 2: ബാക്കെൻഡ് API ഫീച്ചറുകൾ (Node.js API Development)
- **Step 2.1**: Auth API - Signup, Login, Password Reset, JWT Middleware.
- **Step 2.2**: Member & Custom Fields API - CRUD, dynamic JSON validation.
- **Step 2.3**: Plans & Groups Hierarchy API - Plan creation, Subgroup/Batch mapping.
- **Step 2.4**: Payment Engine Logic:
  - 3, 6, 12 മാസ ഫ്രീക്വൻസിയും Collection Day-യും ആധാരമാക്കി പേയ്‌മെന്റ് ഷെഡ്യൂൾ ജനറേറ്റ് ചെയ്യുക.
  - Frozen Month Logic: Unpaid ലെക്സീവൻസുകളിൽ നിന്ന് ഫ്രോസൺ മാസങ്ങൾ ഒഴിവാക്കുക.
  - Collection Rate Formula: `(Collected ÷ Expected) * 100` കണക്കാക്കുക.
- **Step 2.5**: Expense Engine API - റ്റാക്സേഷനും കാറ്റഗറി മാനേജ്‌മെന്റും.
- **Step 2.6**: WhatsApp Credit System API - ക്രെഡിറ്റ് കുറയ്ക്കൽ, ടോപ്പ്-അപ്പ്, എക്സ്പയറി ലോജിക്.

### 📌 Phase 3: ഫ്ലട്ടർ മൊബൈൽ ആപ്പ് (Flutter Mobile App Development)
- **Step 3.1: Bottom Navigation & Home Dashboard 🏠**
  - Summary Cards: Total Members, Paid Count, Unpaid Count, Total Collected.
  - Member Quick List & Actions.
- **Step 3.2: Member Management 👤**
  - Add Member Form with Plan Auto-duration assignment & Datepicker.
  - Dynamic Custom Fields Input (Text, Number, Date, Dropdown, Checkbox, Multi-line).
  - WhatsApp Welcome Message Intent Triggers.
- **Step 3.3: Member Detail Page & Payment Status Confirmation Flow 💳**
  - Personal Details, Call & WhatsApp icons.
  - Paid History (🟢), Unpaid History (🔴), Frozen History (❄️).
  - **Payment Confirmation Flow**:
    - Paid എന്നാക്കുമ്പോൾ Popup: "Send Invoice", "Send Personal Message", "Skip".
    - Change Paid to Unpaid വരുമ്പോൾ Warning confirmation modal.
    - **Freeze Feature**: Unpaid മാസം Freeze അമർത്തിയാൽ Pending തുകയിൽ നിന്നും റെവന്യൂ കാൽക്കുലേഷനിൽ നിന്നും പൂർണ്ണമായി ഒഴിവാക്കുക.
- **Step 3.4: Plans & Groups Module 📋**
  - Hierarchy: Plan → Group → Members → Payments.
  - Plan / Group തിരിച്ചുള്ള Collected, Pending, Paid, Unpaid, Frozen അംഗങ്ങളുടെ എണ്ണവും തുകയും.
- **Step 3.5: Expense Management 💸**
  - Add Expense, Standard & Custom Category selection, Monthly Search & Filter.
- **Step 3.6: Reports & Analytics 📊**
  - Filter: Monthly/Yearly, Income Type (Membership vs Rent).
  - Charts (Pie Chart: Income vs Expense, Income by Plan; Bar Chart: Daily/Monthly comparison).
- **Step 3.7: Settings & WhatsApp Credit Management ⚙️**
  - Editable Templates (Welcome, Rent Reminder, Renewal).
  - Subscription Plan Overview & Extra WhatsApp Credit Store (Purchased credits never expire).

### 📌 Phase 4: നെക്സ്റ്റ്.ജെഎസ് അഡ്മിൻ പാനൽ (Next.js Admin Web Dashboard)
- **Step 4.1**: Analytics Dashboard (Recharts / Chart.js ഉപയോഗിച്ച് മികച്ച വിഷ്വലൈസേഷൻ).
- **Step 4.2**: Bulk Operations (മെമ്പർമാർക്ക് വാട്‌സ്ആപ്പ് ബൾക്ക് റിമൈൻഡറുകൾ അയക്കൽ).
- **Step 4.3**: സബ്‌സ്‌ക്രിപ്‌ഷനും വാട്‌സ്ആപ്പ് ക്രെഡിറ്റ് റീച്ചാർജ്ജും കൈകാര്യം ചെയ്യൽ.
- **Step 4.4**: Custom Fields Engine UI (അഡ്മിന് പുതിയ ഫീൽഡുകൾ ഫോമിൽ ആഡ് ചെയ്യാം).

### 📌 Phase 5: ക്രെഡിറ്റ് സിസ്റ്റം & വാട്‌സ്ആപ്പ് ഇന്റഗ്രേഷൻ (WhatsApp Automation)
- **Step 5.1**: direct `whatsapp://send?phone=...` URL Schemes (മൊബൈൽ ഡീപ്പ് ലിങ്കിംഗ്).
- **Step 5.2**: Optional WhatsApp Cloud API Integration (Automated bulk reminders).
- **Step 5.3**: Credit Consumption Logic (1 Reminder = 1 Credit).
- **Step 5.4**: Subscription validity and Credit separation logic.

---

## 4. ബിസിനസ്സ് ലോജിക് സൂത്രവാക്യങ്ങൾ (Key Business Logic Formulas)

1. **Pending Amount Calculation (പെൻഡിംഗ് തുക കണക്കാക്കൽ):**
   $$\text{Total Pending Amount} = \sum (\text{Unpaid Months}) - \sum (\text{Frozen Months})$$
2. **Collection Rate (കളക്ഷൻ റേറ്റ് %):**
   $$\text{Collection Rate} = \left( \frac{\text{Total Collected Amount}}{\text{Total Expected Amount}} \right) \times 100$$
3. **Net Profit (അറ്റാദായം):**
   $$\text{Net Profit} = \text{Total Income} - \text{Total Expenses}$$

---

## 5. വെരിഫിക്കേഷൻ & ടെസ്റ്റിംഗ് പ്ലാൻ (Verification & Testing Plan)

### Automated Testing:
- Node.js API Unit Tests (Jest): Payment Schedule Calculation, Freeze Month Exclusions, Credit Balance Logic.
- Flutter Widget & Integration Tests: Add Member Validation, Dynamic Custom Fields, Payment Modal Dialogs.

### Manual Verification Flow:
1. **Member Addition & Duration Auto-fill Test**: പ്ലാൻ സെലക്ട് ചെയ്യുമ്പോൾ Duration സ്വയമേവ 30 Days അല്ലെങ്കിൽ Custom Date ആയി മാറുന്നു എന്ന് ഉറപ്പാക്കുക.
2. **Payment Status Confirmation Test**: Paid അമർത്തുമ്പോൾ Receipt/Message/Skip പോപ്പ് അപ്പ് വരുന്നതും, Unpaid ആക്കുമ്പോൾ വാണിംഗ് മോഡൽ കാണിക്കുന്നതും പരിശോധിക്കുക.
3. **Freeze Month Test**: Unpaid മാസം ഫ്രീസ് ചെയ്യുമ്പോൾ Dashboard, Reports, Unpaid list എന്നിവയിലെ പെൻഡിംഗ് തുകയിൽ നിന്നും ഫ്രോസൺ തുക കുറയുന്നത് പരിശോധിക്കുക.
4. **Subscription & Credit Separation Test**: സബ്‌സ്‌ക്രിപ്‌ഷൻ കാലാവധി കഴിഞ്ഞാലും വാങ്ങി വെച്ചിട്ടുള്ള ക്രെഡിറ്റുകൾ എക്‌സ്‌പയർ ആകാതെ ലഭ്യമാണെന്ന് ഉറപ്പ് വരുത്തുക.
