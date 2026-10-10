# EduPortal — Supabase End-to-End Architecture & Integration Guide

EduPortal is an **Enterprise Multi-Tenant SaaS Platform** designed for institutional transaction integrity, automated exam clearance verification, hall ticket gating, and tenant license management across colleges.

This document details the **end-to-end architecture**, **PostgreSQL database schema (DDL)**, **Row Level Security (RLS) policies**, **API key roles**, and **Supabase client integration guide**.

---

## 1. System Architecture Overview

```mermaid
graph TD
    Client["React Frontend (EduPortal UI)"] --> Auth["Supabase Auth (JWT)"]
    Client --> PostgREST["Supabase PostgREST API"]
    Client --> Realtime["Supabase Realtime (WebSocket)"]
    
    subgraph "Supabase Cloud / Postgres Backend"
        Auth --> |auth.uid() & JWT claims| RLS["Row Level Security (RLS) Engine"]
        PostgREST --> RLS
        
        RLS --> Profiles["profiles (Users & Roles)"]
        RLS --> Tenants["colleges (Tenant Nodes & Licenses)"]
        RLS --> Students["students (Exam Clearance & Records)"]
        RLS --> Audit["audit_logs (Compliance & Overrides)"]
        RLS --> Payments["payment_transactions (Ledger)"]
    end

    subgraph "Access Control Logic"
        SuperAdmin["Super Admin (Vendor)"] --> |Full CRUD / Global View| Tenants
        TPO["TPO Admin (College Bound)"] --> |Tenant Isolated CRUD| Students
        Student["Student (Candidate)"] --> |Self-Profile Only (Read)| Students
    end
```

### Core Business Rules Enforced by the Architecture:
1. **Multi-Tenancy Isolation**: Each TPO and Student is bound to a specific `college_id`. A TPO from College A cannot view or alter records from College B.
2. **License Cascade Enforcement**: If a college's license status becomes `SUSPENDED`, both TPO management and student hall ticket generation/portal access are automatically blocked.
3. **Exam Clearance Verification**: Hall ticket issuance requires `fee_status = 'PAID'`, `library_clearance = true`, `attendance_percentage >= 75`, and an active college license status.

---

## 2. API Keys & Security Architecture

When integrating Supabase, you interact with three primary credentials:

| Key Name | Location / Access | Purpose & Permissions |
| :--- | :--- | :--- |
| **`anon` (Public API Key)** | Frontend (`.env` -> `VITE_SUPABASE_ANON_KEY`) | Safe for browser exposure. Used for user login/signup and standard client-side queries. **Every request is strictly guarded by Row Level Security (RLS)**. |
| **`service_role` (Secret API Key)** | Backend / Cloud Functions / Edge Workers ONLY | **Bypasses all RLS policies**. Used for administrative cron jobs, payment webhooks, or initial tenant provisioning scripts. **NEVER expose in the frontend bundle.** |
| **JWT Access Token** | Browser Memory / Auth Storage | Generated upon user login. Contains `sub` (`auth.uid()`), user email, and custom claims (`role`, `college_id`). Supabase uses this to evaluate `auth.uid()` in RLS policies. |

---

## 3. Supabase Database Schema (DDL)

Run this SQL script in your Supabase **SQL Editor** to create the complete schema:

```sql
-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. ENUMS
create type user_role as enum ('SUPER_ADMIN', 'TPO', 'STUDENT');
create type license_plan as enum ('Trial', 'Premium', 'Enterprise');
create type license_status as enum ('ACTIVE', 'EXPIRING_SOON', 'SUSPENDED');
create type fee_status as enum ('PAID', 'PARTIAL', 'OVERDUE');
create type eligibility_status as enum ('CLEARED', 'BLOCKED', 'UNDER_REVIEW');
create type student_dept as enum ('CSE', 'ECE', 'IT', 'MECH');
create type student_year as enum ('1st Year', '2nd Year', '3rd Year', '4th Year');

-- 2. COLLEGES (Institutional Tenant Table)
create table public.colleges (
    id uuid primary key default uuid_generate_v4(),
    name text not null,
    code text not null unique,
    domain_url text not null,
    license_plan license_plan not null default 'Enterprise',
    active_seats integer not null default 0,
    max_seats integer not null default 5000,
    sync_status license_status not null default 'ACTIVE',
    mrr numeric not null default 75000,
    database_host text not null default 'pg-primary.rds.internal',
    api_latency text not null default '34ms',
    last_sync_time timestamptz not null default now(),
    created_at timestamptz not null default now()
);

-- 3. USER PROFILES (Linked to Supabase auth.users)
create table public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null unique,
    name text not null,
    role user_role not null default 'STUDENT',
    college_id uuid references public.colleges(id) on delete set null,
    roll_number text,
    department student_dept,
    created_at timestamptz not null default now()
);

-- 4. STUDENTS (Academic & Clearance Records)
create table public.students (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references public.profiles(id) on delete set null,
    college_id uuid not null references public.colleges(id) on delete cascade,
    name text not null,
    roll_no text not null,
    email text not null,
    department student_dept not null,
    year student_year not null,
    fee_status fee_status not null default 'PAID',
    due_amount numeric not null default 0,
    eligibility eligibility_status not null default 'CLEARED',
    override_reason text,
    last_payment_txn_id text,
    last_sync_timestamp timestamptz not null default now(),
    library_clearance boolean not null default true,
    attendance_percentage numeric not null default 85.0 check (attendance_percentage between 0 and 100),
    hall_ticket_generated boolean not null default false,
    created_at timestamptz not null default now(),
    unique (college_id, roll_no)
);

-- 5. AUDIT LOGS (Compliance & Security Trail)
create table public.audit_logs (
    id uuid primary key default uuid_generate_v4(),
    college_id uuid references public.colleges(id) on delete cascade,
    actor_id uuid references public.profiles(id) on delete set null,
    action text not null,
    target_entity text not null,
    target_id uuid,
    metadata jsonb default '{}'::jsonb,
    created_at timestamptz not null default now()
);

-- Realtime publication enablement
alter publication supabase_realtime add table public.colleges;
alter publication supabase_realtime add table public.students;
```

---

## 4. Helper Functions for RLS

These PostgreSQL helper functions allow fast and safe role and tenant lookups in RLS policies without recursive queries:

```sql
-- Helper function to get current user's role
create or replace function public.get_user_role()
returns user_role
language sql
security definer
stable
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Helper function to get current user's tenant (college_id)
create or replace function public.get_user_college_id()
returns uuid
language sql
security definer
stable
as $$
  select college_id from public.profiles where id = auth.uid();
$$;
```

---

## 5. Row Level Security (RLS) Policies

Enable RLS on all public tables:

```sql
alter table public.colleges enable row level security;
alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.audit_logs enable row level security;
```

### 5.1 `colleges` Table Policies
```sql
-- Super Admin can do everything on colleges
create policy "Super Admin full access on colleges"
on public.colleges
for all
to authenticated
using (public.get_user_role() = 'SUPER_ADMIN')
with check (public.get_user_role() = 'SUPER_ADMIN');

-- TPO and Students can only view their own college tenant record
create policy "Tenant users view own college"
on public.colleges
for select
to authenticated
using (id = public.get_user_college_id());
```

### 5.2 `profiles` Table Policies
```sql
-- Users can read their own profile
create policy "Users read own profile"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- Users can update their own profile
create policy "Users update own profile"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Super Admin can manage all profiles
create policy "Super Admin manage all profiles"
on public.profiles
for all
to authenticated
using (public.get_user_role() = 'SUPER_ADMIN');
```

### 5.3 `students` Table Policies
```sql
-- Super Admin has global read/write
create policy "Super Admin full access on students"
on public.students
for all
to authenticated
using (public.get_user_role() = 'SUPER_ADMIN');

-- TPO can only select students belonging to their college
create policy "TPO view own college students"
on public.students
for select
to authenticated
using (
  public.get_user_role() = 'TPO' and 
  college_id = public.get_user_college_id()
);

-- TPO can insert students only into their own college
create policy "TPO insert own college students"
on public.students
for insert
to authenticated
with check (
  public.get_user_role() = 'TPO' and 
  college_id = public.get_user_college_id()
);

-- TPO can update students in their own college
create policy "TPO update own college students"
on public.students
for update
to authenticated
using (
  public.get_user_role() = 'TPO' and 
  college_id = public.get_user_college_id()
)
with check (
  public.get_user_role() = 'TPO' and 
  college_id = public.get_user_college_id()
);

-- TPO can delete students from their own college
create policy "TPO delete own college students"
on public.students
for delete
to authenticated
using (
  public.get_user_role() = 'TPO' and 
  college_id = public.get_user_college_id()
);

-- Student can only view their own record
create policy "Student view own record"
on public.students
for select
to authenticated
using (
  public.get_user_role() = 'STUDENT' and 
  (user_id = auth.uid() or email = (select email from auth.users where id = auth.uid()))
);
```

### 5.4 Auto-Create Profile on Signup Trigger
```sql
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, email, name, role, college_id, roll_number)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'STUDENT'::user_role),
    (new.raw_user_meta_data->>'college_id')::uuid,
    new.raw_user_meta_data->>'roll_number'
  );
  return new;
end;
$$;

-- Trigger on auth.users table
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

---

## 6. Frontend Supabase Client Integration

### Step 1: Install Supabase Client
```bash
npm install @supabase/supabase-js
```

### Step 2: Configure Environment Variables (`.env`)
```env
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 3: Create Supabase Client Helper (`src/lib/supabase.ts`)
```typescript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  console.warn('Supabase URL or Anon Key is missing in environment variables.');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
```

### Step 4: Realtime Subscription Example
To listen for real-time changes to college license status or student eligibility:

```typescript
import { useEffect } from 'react';
import { supabase } from './lib/supabase';

export function useRealtimeColleges(onUpdate: () => void) {
  useEffect(() => {
    const channel = supabase
      .channel('schema-db-changes')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'colleges' },
        () => {
          onUpdate();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [onUpdate]);
}
```

---

## 7. Migration Checklist for EduPortal

- [ ] **1. Create Project**: Create a new project in [Supabase Dashboard](https://supabase.com/dashboard).
- [ ] **2. Run DDL**: Copy and execute the SQL script in **Section 3** in the Supabase SQL Editor.
- [ ] **3. Apply RLS & Triggers**: Execute the SQL script in **Section 4 & 5**.
- [ ] **4. Add Credentials**: Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to your `.env` file.
- [ ] **5. Replace In-Memory State**: Connect `src/App.tsx` state handlers (`onAddCollege`, `onAddStudent`, `onToggleEligibility`, etc.) to `supabase.from('...').insert()` / `.update()` / `.delete()`.
