# SyncSlash — Intelligent Subscription Optimizer

> **DBMS Mini Project — Group 9**
> Indian Institute of Information Technology, Allahabad

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white"/>
  <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white"/>
  <img src="https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white"/>
  <img src="https://img.shields.io/badge/C++-00599C?style=for-the-badge&logo=cplusplus&logoColor=white"/>
</p>

---

## 📱 Download APK

[**⬇️ Download SyncSlash.apk**](./SyncSlash.apk) — Install directly on any Android device (50.9 MB)

---

## 📖 Overview

**SyncSlash** is a full-stack subscription management and optimization platform that helps users:

- 🔍 **Detect & Track** recurring subscriptions from bank transactions
- 📊 **Analyze** spending patterns using stored procedures and views
- 🧠 **Knowledge Graph** visualization of subscription topology
- 🔴 **Ghost Detection** — find subscriptions you pay for but never use
- 🔁 **Redundancy Analysis** — detect overlapping services (e.g., 3 streaming apps)
- 💳 **Virtual Cards** — create/freeze/cancel subscription payment cards
- 🤝 **P2P Split** — share subscription costs with friends and groups
- ⚡ **C++ Settlement Engine** — Minimum Cash Flow algorithm via pybind11

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                     │
│              (Material Design 3 + Provider)               │
├─────────────────────────────────────────────────────────┤
│                         HTTPS                            │
├─────────────────────────────────────────────────────────┤
│                    FastAPI Backend                        │
│          ┌─────────┬──────────┬──────────┐               │
│          │   B1    │    B2    │    B3    │               │
│          │Ingestion│Analytics │Payments  │               │
│          └────┬────┴────┬─────┴────┬─────┘               │
│               │         │          │                     │
│          ┌────▼─────────▼──────────▼─────┐               │
│          │     PostgreSQL Database        │               │
│          │  (Stored Procedures + Views)   │               │
│          └───────────────────────────────┘               │
│                         │                                │
│          ┌──────────────▼──────────────┐                 │
│          │  C++ Settlement Engine       │                 │
│          │  (pybind11 — O3 optimized)   │                 │
│          └─────────────────────────────┘                 │
├─────────────────────────────────────────────────────────┤
│                  Google OAuth 2.0                        │
│              (JWT Stateless Auth — HS256)                 │
└─────────────────────────────────────────────────────────┘
```

---

## 🗂️ Repository Structure

| Branch | Contents |
|--------|----------|
| [`main`](.) | README, APK download, documentation |
| [`backend`](../../tree/backend) | FastAPI server, PostgreSQL schema, C++ engine, stored procedures |
| [`frontend`](../../tree/frontend) | Flutter mobile application source code |

---

## 🔧 Tech Stack

### Backend
| Technology | Purpose |
|-----------|---------|
| **FastAPI** | REST API framework (Python) |
| **PostgreSQL** | Primary database with stored procedures |
| **pybind11** | C++ ↔ Python bridge for settlement engine |
| **C++ (O3)** | Minimum Cash Flow algorithm for debt optimization |
| **JWT (HS256)** | Stateless authentication tokens |
| **Google OAuth 2.0** | Social login integration |

### Frontend
| Technology | Purpose |
|-----------|---------|
| **Flutter 3.x** | Cross-platform mobile framework |
| **Provider** | State management |
| **FlutterSecureStorage** | AES-256 encrypted credential storage |
| **google_sign_in** | Native Google authentication |
| **Material Design 3** | UI component library |

### Infrastructure
| Service | Purpose |
|---------|---------|
| **Render** | Backend hosting (auto-deploy from GitHub) |
| **Render PostgreSQL** | Managed database service |

---

## 🗄️ Database Design

### Core Tables
- `Users` — User accounts and authentication
- `Services` — Known subscription services (Netflix, Spotify, etc.)
- `Subscriptions` — User ↔ Service relationships with cost tracking
- `Transactions` — Bank transaction records
- `Virtual_Cards` — Payment card management
- `Shared_Bills` — P2P bill splitting
- `Subscription_Groups` — Group subscription sharing
- `Group_Members` — Group membership tracking

### Stored Procedures
- `GenerateFatigueScore(user_id)` — Calculates subscription fatigue (0–100)
- `GenerateMonthlyReport(user_id)` — Monthly spending analysis by category
- `DetectGhostSubscriptions(user_id)` — Finds unused paid services

### Views
- `MonthlySpendingSummary` — Aggregated spending per category
- `ActiveSubscriptionDetails` — Currently active subscriptions with service info

---

## ⚡ C++ Settlement Engine

The P2P settlement uses a **Minimum Cash Flow** algorithm compiled to a native Python module via pybind11:

```cpp
// Greedy approach: match largest debtor with largest creditor
// Time complexity: O(n log n)
// Compiled with -O3 optimization
vector<Transaction> settle_debts(const map<string, double>& net_balances);
```

**Example:** Netflix ₹649 split among 3 people:
```
Input:  Aditya: +432.67, Bob: -216.33, Charlie: -216.33
Output: Bob pays Aditya ₹216.33
        Charlie pays Aditya ₹216.33
        (2 transactions — minimum possible)
```

---

## 🔐 Authentication Flow

```
Google Sign-In → ID Token → Backend Verification → JWT Issued → Stored in SecureStorage
                                                                        ↓
                                                              Auto-login on app restart
                                                              Explicit logout clears storage
```

- **Stateless JWT** (HS256) — no server-side session storage
- **FlutterSecureStorage** — uses Android Keystore (hardware-backed AES-256)
- **3-tier fallback**: Google OAuth → Direct Auth → Dev Mode

---

## 🚀 Running Locally

### Backend
```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# Set DATABASE_URL in .env
python -m uvicorn backend.main:app --reload --port 8000
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

### Build APK
```bash
cd frontend
flutter build apk --release
```

---

## 👥 Team — Group 9

| Name | Role |
|------|------|
| Aditya Tomar | Full-Stack Development, System Architecture, C++ Engine |

---

## 📄 License

This project was built as part of the DBMS course at IIIT Allahabad.
