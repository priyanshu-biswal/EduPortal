# EduPortal — Multi-Tenant Transaction Integrity & Exam Clearance Platform 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Tech Stack](https://img.shields.io/badge/Stack-React%20%7C%20TypeScript%20%7C%20TailwindCSS%20%7C%20PostgreSQL-3178C6)](https://github.com/)
[![Build Status](https://img.shields.io/badge/Build-Passing-emerald)](https://github.com/)

**EduPortal** is a B2B multi-tenant SaaS platform that automates real-time transaction synchronization between university **Accounts Sections** and **Exam Eligibility Systems**. By eliminating manual fee receipt verifications, it prevents administrative backlogs, eliminates human entry errors, and provides real-time exam clearance status for students.

---

## 📌 Problem Statement

In educational institutions, fee payment records in the accounts database are often disconnected from online exam registration portals. During peak examination registration windows:
* **Manual Verification Delays:** Administrative staff must manually cross-verify physical receipts against candidate rosters before issuing hall tickets.
* **Data Inconsistencies:** Human error leads to eligible students being incorrectly flagged as ineligible.
* **Scalability Bottlenecks:** Severe system backlogs occur when thousands of students verify fee clearances simultaneously.

**EduPortal** solves this by establishing automated database triggers and API pipelines to guarantee real-time transaction integrity across institutional boundaries.

---

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | React, TypeScript, Vite | Type-safe, high-density reactive user interface |
| **Styling** | Tailwind CSS | Modern dark-themed utility-first styling |
| **Database** | PostgreSQL | Relational persistence with trigger-driven sync |
| **Integration Layer** | REST / GraphQL APIs | Multi-tenant service communication |
| **Message Queue** | Apache Kafka / RabbitMQ | Asynchronous queueing for high transaction surges |

---

## 👨‍💼 Multi-Tenant Stakeholder Architecture

EduPortal provides role-based access control (RBAC) separated into three distinct operational domains:

### 1. 🏢 Super Admin (SaaS Vendor)
* **Client Onboarding:** Provisions new partner college database schemas and manages subscription licenses.
* **Revenue Analytics:** Monitors Monthly Recurring Revenue (MRR), total licensed student seats, and active university subscriptions.
* **System Health:** Tracks global API health, database sync latency, and multi-tenant uptime.

### 2. 🎓 TPO / College Admin (Institutional Officer)
* **Exam Eligibility Roster:** Views auto-generated eligibility lists driven by live database synchronization.
* **Manual Block/Clearance Controls:** Overrides student eligibility when necessary (e.g., library dues or special permissions).
* **Batch Exports:** Generates candidate rosters and exports official PDF hall tickets in bulk.

### 3. 👨‍🎓 Student Portal
* **Live Status Tracking:** Displays real-time fee clearance and database verification logs.
* **Self-Service Verification:** Direct access to view fee clearance without physical receipt submission.
* **Hall Ticket Downloads:** Instant PDF hall ticket download enabled automatically upon fee clearance and TPO approval.

---

## 🔑 Quick Demo Credentials

The login gateway includes pre-configured demo presets for instant workspace access:

| Role | Email Login | Password | Workspace Access |
| :--- | :--- | :--- | :--- |
| **Super Admin (SaaS Vendor)** | `super@gmail.com` | `12345678` | Global SaaS Analytics & Licensing |
| **TPO (College Admin)** | `tpo@gmail.com` | `12345678` | Institutional Exam & Student Controls |
| **Student** | `student@gmail.com` | `12345678` | Live Status & Hall Ticket Download |

---

## 🔄 System Architecture Workflow

```mermaid
flowchart TD
    A[EduPortal Login Gateway] --> B{Authentication Router}
    B -->|super@gmail.com| C[Super Admin SaaS Platform]
    B -->|tpo@gmail.com| D[College Accounts DB]
    B -->|student@gmail.com| G[Student Portal]

    C -->|Tenant Provisioning| D
    D --> E{PostgreSQL Trigger / API Gateway}
    E --> F[College Exam Eligibility Database]

    F --> C
    F --> H[TPO / College Admin Portal]
    F --> G
