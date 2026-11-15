# ReCell - One-Way Mobile Phone Buyback Platform

A complete one-way mobile phone selling platform built with **React 19 + Vite** frontend, **Django REST Framework (DRF)** backend, **PostgreSQL / SQLite** database, and **100% Base64 image storage** (no external file storage or media folder permissions required).

> **Core Business Rule:**
> Customers sell phones to your company only. They cannot buy phones through your website.

---

## 🌟 Key Features

1. **Rule-Based Dynamic Valuation Engine**:
   - Admin configures base prices for models & storage variants.
   - Condition questions: Screen cracks, OLED lines, touch responsiveness, battery health, camera/Face ID, and body scratches/dents.
   - Real-time calculation: `Estimated Value = Base Price - Condition Deductions`.
2. **Doorstep Collection & Field Agent Portal**:
   - Mobile-responsive checklist for pickup agents.
   - Hardware functional checks + mandatory iCloud / Google FRP removal verification.
   - In-field camera capture with instant in-browser **Base64 photo encoding**.
   - Physical IMEI dialer verification (`*#06#`).
3. **Revised Final Offer Customer Journey**:
   - If inspection discovers unexpected defects, customer receives an itemized revised offer.
   - Customer can **Accept** or **Reject (Phone safely returned)**.
4. **Smart Manual Payout Desk (Your Workflow)**:
   - Dynamic **Scan-to-Pay UPI QR Code** rendered on screen (pre-fills customer's UPI ID and exact rupee amount for Google Pay / PhonePe).
   - "Click to Copy" buttons for Bank A/C Number, IFSC, and Payee Name for IMPS/NEFT.
   - Admin transfers money from any payment app, uploads the confirmation screenshot (**auto-converted to Base64**), and enters the 12-digit UTR.
   - Enforces **unique UTR verification** (prevents double payouts).
   - Automatically marks the order as **PAID**.
5. **Printable Bill of Sale & Payment Voucher**:
   - Official voucher with receipt number, customer KYC, device IMEI, payment method, UTR, Base64 screenshot preview, and legal ownership transfer declaration.
6. **100% Base64 Architecture**:
   - All brand logos, device photos, inspection evidence, and payment receipts are stored directly in the database as Base64 strings.
   - A single `pg_dump` backup captures 100% of the platform's data and media assets.

---

## ⚡ Quick Start (Local Development)

### 1. Backend (Django REST Framework)

```powershell
# In project root:
cd backend

# Virtual environment is already prepared at backend/venv
.\venv\Scripts\activate

# Run database migrations (SQLite by default, PostgreSQL ready)
python manage.py migrate

# Seed catalog, valuation rules, and demo live orders
python seed_data.py

# Start Django API server on http://127.0.0.1:8000
python manage.py runserver 127.0.0.1:8000
```

### 2. Frontend (React + Vite + Tailwind CSS)

```powershell
# In a separate terminal:
cd frontend

# Run Vite dev server
npm run dev
```

Open `http://localhost:5173` in your browser.

---

## 👥 Demo Logins

The database includes pre-configured 1-click test credentials:

| Role | Email | Password | Access Capabilities |
|---|---|---|---|
| **Super Admin** | `admin@buyback.in` | `admin123` | Operations desk, Pricing manager, Payout authorization with UPI QR, Payout ledger |
| **Collection Agent** | `agent@buyback.in` | `agent123` | Assigned pickups list, Hardware checklist, Device photo upload, IMEI capture |
| **Customer** | `customer@example.com` | `customer123` | Sell phone wizard, Live tracking, Accept/Reject revised offers, Printable receipt |

---

## 📁 Project Architecture

```
mobile resell/
├── backend/
│   ├── config/               # Django settings, WSGI, URLs
│   ├── apps/
│   │   ├── accounts/         # Custom User model (Customer, Admin, Agent), JWT Auth
│   │   ├── catalog/          # Brands, Phone Models, Storage Variants (Base64 logos)
│   │   ├── valuation/        # Categories, Question matrix, Valuation engine
│   │   ├── sales/            # Sales lifecycle FSM, Customer acceptances
│   │   ├── inspections/      # Hardware tests, Base64 inspection photos
│   │   └── payments/         # Manual Payout Desk, Dynamic UPI QR, UTR, Base64 proof
│   ├── seed_data.py          # Populates catalog, pricing rules & live test orders
│   ├── test_api_flow.py      # Automated 9-step end-to-end integration test
│   └── manage.py
├── frontend/
│   ├── src/
│   │   ├── customer/         # SellWizard, TrackOrder, ReceiptModal
│   │   ├── admin/            # AdminDashboard, PayoutModal (UPI QR + Screenshot upload)
│   │   ├── collection/       # AgentInspectionView
│   │   ├── components/       # Navbar, Footer, AuthModal
│   │   ├── services/         # API client & auth interceptor
│   │   └── utils/            # In-browser canvas image-to-base64 compressor
│   └── package.json
└── README.md
```

---

## 🚀 Linux Server Production Deployment

### 1. PostgreSQL Database Setup
```sql
CREATE DATABASE mobilebuyback_db;
CREATE USER mobilebuyback_user WITH PASSWORD 'STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE mobilebuyback_db TO mobilebuyback_user;
```

### 2. Environment Variables (.env)
```env
DEBUG=False
SECRET_KEY=your_production_secret_key
DB_NAME=mobilebuyback_db
DB_USER=mobilebuyback_user
DB_PASSWORD=STRONG_PASSWORD
DB_HOST=localhost
DB_PORT=5432
```

### 3. Build Frontend & Serve via Nginx
```bash
cd frontend
npm run build
# Built files in frontend/dist/ served by Nginx
```
