-- ==============================================================================
-- EDUPORTAL — CLEAN SUPABASE SETUP (NO NESTED BLOCKS / NO DOLLAR-QUOTE ISSUES)
-- ==============================================================================

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABLES

-- 2.1 Colleges
CREATE TABLE IF NOT EXISTS public.colleges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    domain_url TEXT NOT NULL,
    license_plan TEXT NOT NULL DEFAULT 'Enterprise',
    active_seats INTEGER NOT NULL DEFAULT 0,
    max_seats INTEGER NOT NULL DEFAULT 5000,
    sync_status TEXT NOT NULL DEFAULT 'ACTIVE',
    mrr NUMERIC NOT NULL DEFAULT 75000,
    database_host TEXT NOT NULL DEFAULT 'pg-primary.rds.internal',
    api_latency TEXT NOT NULL DEFAULT '34ms',
    last_sync_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.2 User Profiles
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'SUPER_ADMIN',
    college_id UUID REFERENCES public.colleges(id) ON DELETE SET NULL,
    roll_number TEXT,
    department TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.3 TPOs
CREATE TABLE IF NOT EXISTS public.tpos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    department TEXT DEFAULT 'Exam & Placement Cell',
    designation TEXT DEFAULT 'Head Placement Officer',
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.4 Students
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    college_id UUID NOT NULL REFERENCES public.colleges(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    roll_no TEXT NOT NULL,
    email TEXT NOT NULL,
    department TEXT NOT NULL DEFAULT 'CSE',
    year TEXT NOT NULL DEFAULT '3rd Year',
    fee_status TEXT NOT NULL DEFAULT 'PAID',
    due_amount NUMERIC NOT NULL DEFAULT 0,
    eligibility TEXT NOT NULL DEFAULT 'CLEARED',
    override_reason TEXT,
    last_payment_txn_id TEXT,
    last_sync_timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    library_clearance BOOLEAN NOT NULL DEFAULT true,
    attendance_percentage NUMERIC NOT NULL DEFAULT 85.0,
    hall_ticket_generated BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (college_id, roll_no)
);

-- 2.5 Audit Logs
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


-- 3. ROW LEVEL SECURITY (OPEN / NO-DEADLOCK POLICIES)

ALTER TABLE public.colleges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tpos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 3.1 Colleges Policies
DROP POLICY IF EXISTS "colleges_select" ON public.colleges;
CREATE POLICY "colleges_select" ON public.colleges FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "colleges_insert" ON public.colleges;
CREATE POLICY "colleges_insert" ON public.colleges FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS "colleges_update" ON public.colleges;
CREATE POLICY "colleges_update" ON public.colleges FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "colleges_delete" ON public.colleges;
CREATE POLICY "colleges_delete" ON public.colleges FOR DELETE TO authenticated, anon USING (true);


-- 3.2 Profiles Policies
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "profiles_delete" ON public.profiles;
CREATE POLICY "profiles_delete" ON public.profiles FOR DELETE TO authenticated, anon USING (true);


-- 3.3 TPOs Policies
DROP POLICY IF EXISTS "tpos_select" ON public.tpos;
CREATE POLICY "tpos_select" ON public.tpos FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "tpos_insert" ON public.tpos;
CREATE POLICY "tpos_insert" ON public.tpos FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS "tpos_update" ON public.tpos;
CREATE POLICY "tpos_update" ON public.tpos FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "tpos_delete" ON public.tpos;
CREATE POLICY "tpos_delete" ON public.tpos FOR DELETE TO authenticated, anon USING (true);


-- 3.4 Students Policies
DROP POLICY IF EXISTS "students_select" ON public.students;
CREATE POLICY "students_select" ON public.students FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "students_insert" ON public.students;
CREATE POLICY "students_insert" ON public.students FOR INSERT TO authenticated, anon WITH CHECK (true);

DROP POLICY IF EXISTS "students_update" ON public.students;
CREATE POLICY "students_update" ON public.students FOR UPDATE TO authenticated, anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "students_delete" ON public.students;
CREATE POLICY "students_delete" ON public.students FOR DELETE TO authenticated, anon USING (true);


-- 3.5 Audit Logs Policies
DROP POLICY IF EXISTS "audit_select" ON public.audit_logs;
CREATE POLICY "audit_select" ON public.audit_logs FOR SELECT TO authenticated, anon USING (true);

DROP POLICY IF EXISTS "audit_insert" ON public.audit_logs;
CREATE POLICY "audit_insert" ON public.audit_logs FOR INSERT TO authenticated, anon WITH CHECK (true);


-- 4. CLEAN USER PROFILE TRIGGER (NO NESTED EXCEPTION BLOCKS)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $func$
BEGIN
  INSERT INTO public.profiles (id, email, name, role, college_id, roll_number)
  VALUES (
    new.id,
    new.email,
    COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    COALESCE(new.raw_user_meta_data->>'role', 'SUPER_ADMIN'),
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
$func$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT OR UPDATE ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
