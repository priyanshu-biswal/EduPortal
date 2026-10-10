# Supabase Database Queries & Table Setup Guide

This document contains the exact **SQL DDL and execution instructions** to set up all tables, enums, indexes, functions, triggers, and Row Level Security (RLS) policies for **EduPortal** on Supabase.

---

## Quick Setup (1-Click SQL Script)

You can either copy the code blocks below or directly open the ready-made SQL file in your workspace:
👉 **[`supabase_schema.sql`](file:///c:/Users/Priyanshu%20Biswal/OneDrive/Desktop/PYnex/supabase_schema.sql)**

### How to Run:
1. Open your Supabase Project Dashboard: [https://supabase.com/dashboard/project/glxyuppdgkbysurqqthr/sql](https://supabase.com/dashboard/project/glxyuppdgkbysurqqthr/sql)
2. Click **New Query**.
3. Paste the entire SQL script below and click **Run** (or press `Ctrl + Enter` / `Cmd + Enter`).

---

## Complete SQL Execution Script

```sql
-- ==============================================================================
-- EDUPORTAL — COMPLETE SUPABASE DATABASE SETUP SCRIPT
-- ==============================================================================
-- Project ID: glxyuppdgkbysurqqthr
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. CUSTOM ENUM TYPES
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('SUPER_ADMIN', 'TPO', 'STUDENT');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE license_plan AS ENUM ('Trial', 'Premium', 'Enterprise');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE license_status AS ENUM ('ACTIVE', 'EXPIRING_SOON', 'SUSPENDED');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE fee_status AS ENUM ('PAID', 'PARTIAL', 'OVERDUE');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE eligibility_status AS ENUM ('CLEARED', 'BLOCKED', 'UNDER_REVIEW');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE student_dept AS ENUM ('CSE', 'ECE', 'IT', 'MECH');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  CREATE TYPE student_year AS ENUM ('1st Year', '2nd Year', '3rd Year', '4th Year');
EXCEPTION WHEN duplicate_object THEN null; END $$;


-- 3. TABLES DEFINITIONS

-- 3.1 Colleges (Tenant Registry)
CREATE TABLE IF NOT EXISTS public.colleges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    domain_url TEXT NOT NULL,
    license_plan license_plan NOT NULL DEFAULT 'Enterprise',
    active_seats INTEGER NOT NULL DEFAULT 0,
    max_seats INTEGER NOT NULL DEFAULT 5000,
    sync_status license_status NOT NULL DEFAULT 'ACTIVE',
    mrr NUMERIC NOT NULL DEFAULT 75000,
    database_host TEXT NOT NULL DEFAULT 'pg-primary.rds.internal',
    api_latency TEXT NOT NULL DEFAULT '34ms',
    last_sync_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.2 User Profiles (Extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'STUDENT',
    college_id UUID REFERENCES public.colleges(id) ON DELETE SET NULL,
    roll_number TEXT,
    department student_dept,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.3 Students (Clearance & Academic Records)
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    roll_no TEXT NOT NULL,
    email TEXT NOT NULL,
    department student_dept NOT NULL DEFAULT 'CSE',
    year student_year NOT NULL DEFAULT '3rd Year',
    fee_status fee_status NOT NULL DEFAULT 'PAID',
    due_amount NUMERIC NOT NULL DEFAULT 0,
    eligibility eligibility_status NOT NULL DEFAULT 'CLEARED',
    override_reason TEXT,
    last_payment_txn_id TEXT,
    last_sync_timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    library_clearance BOOLEAN NOT NULL DEFAULT true,
    attendance_percentage NUMERIC NOT NULL DEFAULT 85.0 CHECK (attendance_percentage >= 0 AND attendance_percentage <= 100),
    hall_ticket_generated BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (college_id, roll_no)
);

-- 3.4 Audit Logs (Compliance & Override Trail)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    college_id UUID REFERENCES public.colleges(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    target_entity TEXT NOT NULL,
    target_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- 4. PERFORMANCE INDEXES
CREATE INDEX IF NOT EXISTS idx_colleges_code ON public.colleges(code);
CREATE INDEX IF NOT EXISTS idx_colleges_sync_status ON public.colleges(sync_status);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_college_id ON public.profiles(college_id);
CREATE INDEX IF NOT EXISTS idx_students_college_id ON public.students(college_id);
CREATE INDEX IF NOT EXISTS idx_students_roll_no ON public.students(roll_no);
CREATE INDEX IF NOT EXISTS idx_students_eligibility ON public.students(eligibility);
CREATE INDEX IF NOT EXISTS idx_audit_college_id ON public.audit_logs(college_id);


-- 5. HELPER FUNCTIONS FOR ROW LEVEL SECURITY (RLS)
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.get_user_college_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT college_id FROM public.profiles WHERE id = auth.uid();
$$;


-- 6. ROW LEVEL SECURITY (RLS) ENABLEMENT
ALTER TABLE public.colleges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;


-- 7. RLS POLICIES (DROP EXISTING THEN RE-CREATE)

-- 7.1 COLLEGES POLICIES
DROP POLICY IF EXISTS "Super Admin full access on colleges" ON public.colleges;
CREATE POLICY "Super Admin full access on colleges"
ON public.colleges
FOR ALL
TO authenticated
USING (public.get_user_role() = 'SUPER_ADMIN')
WITH CHECK (public.get_user_role() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS "Tenant users view own college" ON public.colleges;
CREATE POLICY "Tenant users view own college"
ON public.colleges
FOR SELECT
TO authenticated
USING (id = public.get_user_college_id());


-- 7.2 PROFILES POLICIES
DROP POLICY IF EXISTS "Users read own profile" ON public.profiles;
CREATE POLICY "Users read own profile"
ON public.profiles
FOR SELECT
TO authenticated
USING (id = auth.uid());

DROP POLICY IF EXISTS "Users update own profile" ON public.profiles;
CREATE POLICY "Users update own profile"
ON public.profiles
FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Super Admin manage all profiles" ON public.profiles;
CREATE POLICY "Super Admin manage all profiles"
ON public.profiles
FOR ALL
TO authenticated
USING (public.get_user_role() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS "TPO view profiles in their college" ON public.profiles;
CREATE POLICY "TPO view profiles in their college"
ON public.profiles
FOR SELECT
TO authenticated
USING (
  public.get_user_role() = 'TPO' AND
  college_id = public.get_user_college_id()
);


-- 7.3 STUDENTS POLICIES
DROP POLICY IF EXISTS "Super Admin full access on students" ON public.students;
CREATE POLICY "Super Admin full access on students"
ON public.students
FOR ALL
TO authenticated
USING (public.get_user_role() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS "TPO view own college students" ON public.students;
CREATE POLICY "TPO view own college students"
ON public.students
FOR SELECT
TO authenticated
USING (
  public.get_user_role() = 'TPO' AND 
  college_id = public.get_user_college_id()
);

DROP POLICY IF EXISTS "TPO insert own college students" ON public.students;
CREATE POLICY "TPO insert own college students"
ON public.students
FOR INSERT
TO authenticated
WITH CHECK (
  public.get_user_role() = 'TPO' AND 
  college_id = public.get_user_college_id()
);

DROP POLICY IF EXISTS "TPO update own college students" ON public.students;
CREATE POLICY "TPO update own college students"
ON public.students
FOR UPDATE
TO authenticated
USING (
  public.get_user_role() = 'TPO' AND 
  college_id = public.get_user_college_id()
)
WITH CHECK (
  public.get_user_role() = 'TPO' AND 
  college_id = public.get_user_college_id()
);

DROP POLICY IF EXISTS "TPO delete own college students" ON public.students;
CREATE POLICY "TPO delete own college students"
ON public.students
FOR DELETE
TO authenticated
USING (
  public.get_user_role() = 'TPO' AND 
  college_id = public.get_user_college_id()
);

DROP POLICY IF EXISTS "Student view own record" ON public.students;
CREATE POLICY "Student view own record"
ON public.students
FOR SELECT
TO authenticated
USING (
  public.get_user_role() = 'STUDENT' AND 
  (user_id = auth.uid() OR email = (SELECT email FROM auth.users WHERE id = auth.uid()))
);


-- 7.4 AUDIT LOGS POLICIES
DROP POLICY IF EXISTS "Super Admin read all audit logs" ON public.audit_logs;
CREATE POLICY "Super Admin read all audit logs"
ON public.audit_logs
FOR SELECT
TO authenticated
USING (public.get_user_role() = 'SUPER_ADMIN');

DROP POLICY IF EXISTS "TPO read own college audit logs" ON public.audit_logs;
CREATE POLICY "TPO read own college audit logs"
ON public.audit_logs
FOR SELECT
TO authenticated
USING (
  public.get_user_role() = 'TPO' AND
  college_id = public.get_user_college_id()
);

DROP POLICY IF EXISTS "Insert audit logs" ON public.audit_logs;
CREATE POLICY "Insert audit logs"
ON public.audit_logs
FOR INSERT
TO authenticated
WITH CHECK (true);


-- 8. AUTOMATIC USER PROFILE TRIGGER
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role, college_id, roll_number)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    COALESCE((new.raw_user_meta_data->>'role')::user_role, 'STUDENT'::user_role),
    NULLIF(new.raw_user_meta_data->>'college_id', '')::uuid,
    new.raw_user_meta_data->>'roll_number'
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(EXCLUDED.name, public.profiles.name),
    role = COALESCE(EXCLUDED.role, public.profiles.role),
    college_id = COALESCE(EXCLUDED.college_id, public.profiles.college_id),
    roll_number = COALESCE(EXCLUDED.roll_number, public.profiles.roll_number);
  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- 9. REALTIME BROADCASTING REPLICATION
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.colleges;
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.students;
EXCEPTION WHEN duplicate_object THEN null; END $$;
```
