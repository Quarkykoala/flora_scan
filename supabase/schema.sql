-- FloraScan Phase 1 Database Schema
-- Supabase (PostgreSQL) with RLS policies

-- ============================================
-- Extensions
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  locale_code TEXT NOT NULL DEFAULT 'en',
  research_consent BOOLEAN NOT NULL DEFAULT true,
  climate_zone TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own" ON public.users
  FOR SELECT USING (id = auth.uid());

CREATE POLICY "users_insert_own" ON public.users
  FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- ============================================
-- 2. PLANTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.plants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  nickname TEXT NOT NULL,
  species_scientific TEXT NULL,
  species_common TEXT NULL,
  species_confidence NUMERIC NULL,
  environment_profile JSONB NOT NULL DEFAULT '{}',
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_plants_user_id ON public.plants(user_id);
CREATE INDEX idx_plants_user_active ON public.plants(user_id) WHERE is_archived = false;

ALTER TABLE public.plants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "plants_select_own" ON public.plants
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "plants_insert_own" ON public.plants
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "plants_update_own" ON public.plants
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "plants_delete_own" ON public.plants
  FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- 3. SCANS TABLE (Golden Record)
-- ============================================
CREATE TABLE IF NOT EXISTS public.scans (
  -- Identity & Sync
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plant_id UUID NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  client_scan_id TEXT UNIQUE NOT NULL,
  captured_at_utc TIMESTAMPTZ NOT NULL,
  uploaded_at_utc TIMESTAMPTZ NULL,

  -- Image
  image_path TEXT NOT NULL,
  image_sha256 TEXT NULL,
  image_width INT NULL,
  image_height INT NULL,

  -- Device Metadata
  device_platform TEXT NULL,
  app_version TEXT NULL,
  device_tz TEXT NULL,

  -- Geospatial (privacy-aware)
  lat_precise DOUBLE PRECISION NULL,
  lon_precise DOUBLE PRECISION NULL,
  lat_rounded DOUBLE PRECISION NULL,
  lon_rounded DOUBLE PRECISION NULL,
  geohash_6 TEXT NULL,
  altitude_meters DOUBLE PRECISION NULL,
  location_accuracy_meters DOUBLE PRECISION NULL,
  reverse_geo JSONB NULL,

  -- Hardware Telemetry
  lux_reading DOUBLE PRECISION NULL,
  lux_source TEXT NULL,
  device_pitch_deg DOUBLE PRECISION NULL,
  device_roll_deg DOUBLE PRECISION NULL,
  flash_fired BOOLEAN NULL,

  -- Atmospheric Telemetry
  temp_c DOUBLE PRECISION NULL,
  humidity_pct DOUBLE PRECISION NULL,
  vpd_kpa DOUBLE PRECISION NULL,
  solar_radiation_wm2 DOUBLE PRECISION NULL,
  et0_mm DOUBLE PRECISION NULL,
  soil_temp_0cm_c DOUBLE PRECISION NULL,

  -- Air Quality Telemetry
  aqi INT NULL,
  pm2_5 DOUBLE PRECISION NULL,
  pm10 DOUBLE PRECISION NULL,
  no2 DOUBLE PRECISION NULL,
  o3 DOUBLE PRECISION NULL,

  -- Quality + Processing
  image_quality_score DOUBLE PRECISION NULL,
  telemetry_completeness_score DOUBLE PRECISION NULL,
  processing_status TEXT NOT NULL DEFAULT 'queued',
  processing_error TEXT NULL,

  -- AI Diagnosis
  ai_model_name TEXT NULL,
  ai_model_version TEXT NULL,
  prompt_version TEXT NULL,
  diagnosis_confidence DOUBLE PRECISION NULL,
  health_score INT NULL,
  diagnosis_code TEXT NULL,
  diagnosis_localized TEXT NULL,
  treatment_localized TEXT NULL,
  visual_symptoms TEXT[] NULL,
  ai_diagnosis_raw JSONB NULL,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_scans_user_id ON public.scans(user_id);
CREATE INDEX idx_scans_plant_id ON public.scans(plant_id);
CREATE INDEX idx_scans_user_plant ON public.scans(user_id, plant_id);
CREATE INDEX idx_scans_status ON public.scans(processing_status);
CREATE INDEX idx_scans_captured_at ON public.scans(captured_at_utc DESC);
CREATE INDEX idx_scans_geohash ON public.scans(geohash_6);
CREATE INDEX idx_scans_client_id ON public.scans(client_scan_id);
CREATE INDEX idx_scans_diagnosis_code ON public.scans(diagnosis_code) WHERE diagnosis_code IS NOT NULL;

ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "scans_select_own" ON public.scans
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "scans_insert_own" ON public.scans
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "scans_update_own" ON public.scans
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Service role can update scans (for Edge Functions)
CREATE POLICY "scans_service_update" ON public.scans
  FOR UPDATE USING (true)
  WITH CHECK (true);

-- ============================================
-- 4. SCAN_JOBS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.scan_jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_id UUID NOT NULL REFERENCES public.scans(id) ON DELETE CASCADE,
  job_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  attempts INT NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ NULL,
  finished_at TIMESTAMPTZ NULL,
  error_message TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_scan_jobs_scan_id ON public.scan_jobs(scan_id);
CREATE INDEX idx_scan_jobs_status ON public.scan_jobs(status) WHERE status IN ('queued', 'running', 'retrying');
CREATE INDEX idx_scan_jobs_type_status ON public.scan_jobs(job_type, status);

ALTER TABLE public.scan_jobs ENABLE ROW LEVEL SECURITY;

-- scan_jobs are read via scan ownership
CREATE POLICY "scan_jobs_select_via_scan" ON public.scan_jobs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.scans
      WHERE scans.id = scan_jobs.scan_id
      AND scans.user_id = auth.uid()
    )
  );

-- Service role can manage jobs
CREATE POLICY "scan_jobs_service_all" ON public.scan_jobs
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 5. DIAGNOSIS_FEEDBACK TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.diagnosis_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_id UUID NOT NULL REFERENCES public.scans(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  feedback_type TEXT NOT NULL,
  feedback_note TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_feedback_scan_id ON public.diagnosis_feedback(scan_id);
CREATE INDEX idx_feedback_user_id ON public.diagnosis_feedback(user_id);

ALTER TABLE public.diagnosis_feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "feedback_select_own" ON public.diagnosis_feedback
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "feedback_insert_own" ON public.diagnosis_feedback
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================
-- 6. CARE_EVENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.care_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  plant_id UUID NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_value JSONB NULL,
  occurred_at_utc TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_care_events_plant_id ON public.care_events(plant_id);
CREATE INDEX idx_care_events_user_id ON public.care_events(user_id);
CREATE INDEX idx_care_events_plant_type ON public.care_events(plant_id, event_type);

ALTER TABLE public.care_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "care_events_select_own" ON public.care_events
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "care_events_insert_own" ON public.care_events
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================
-- 7. STORAGE BUCKET
-- ============================================
-- Create private bucket for plant scan images
INSERT INTO storage.buckets (id, name, public)
VALUES ('plant-scans', 'plant-scans', false)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS: users can upload to their own folder
CREATE POLICY "storage_insert_own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'plant-scans'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Storage RLS: users can read their own files
CREATE POLICY "storage_select_own" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'plant-scans'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Storage RLS: users can delete their own files
CREATE POLICY "storage_delete_own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'plant-scans'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================
-- 8. UPDATED_AT TRIGGER
-- ============================================
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER plants_updated_at
  BEFORE UPDATE ON public.plants
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER scans_updated_at
  BEFORE UPDATE ON public.scans
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 9. CHECK CONSTRAINTS
-- ============================================
ALTER TABLE public.scans
  ADD CONSTRAINT chk_processing_status
  CHECK (processing_status IN ('queued', 'enriching', 'diagnosing', 'completed', 'failed'));

ALTER TABLE public.scan_jobs
  ADD CONSTRAINT chk_job_type
  CHECK (job_type IN ('enrich_weather', 'enrich_air', 'diagnose_ai'));

ALTER TABLE public.scan_jobs
  ADD CONSTRAINT chk_job_status
  CHECK (status IN ('queued', 'running', 'succeeded', 'failed', 'retrying'));

ALTER TABLE public.diagnosis_feedback
  ADD CONSTRAINT chk_feedback_type
  CHECK (feedback_type IN ('helpful', 'not_helpful', 'wrong_diagnosis', 'improved_after_treatment'));

ALTER TABLE public.care_events
  ADD CONSTRAINT chk_event_type
  CHECK (event_type IN ('watered', 'fertilized', 'repotted', 'pruned'));

ALTER TABLE public.scans
  ADD CONSTRAINT chk_health_score
  CHECK (health_score IS NULL OR (health_score >= 0 AND health_score <= 100));

ALTER TABLE public.scans
  ADD CONSTRAINT chk_diagnosis_confidence
  CHECK (diagnosis_confidence IS NULL OR (diagnosis_confidence >= 0 AND diagnosis_confidence <= 1));
