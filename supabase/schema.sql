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
  research_consent BOOLEAN NOT NULL DEFAULT false,
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
CREATE INDEX idx_scan_jobs_scan_type ON public.scan_jobs(scan_id, job_type);

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
-- 7. INTERVENTION_RECOMMENDATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.intervention_recommendations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_id UUID NOT NULL REFERENCES public.scans(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plant_id UUID NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  recommendation_code TEXT NOT NULL,
  recommendation_localized TEXT NOT NULL,
  recommendation_details_localized TEXT NULL,
  priority TEXT NOT NULL DEFAULT 'medium',
  recommended_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  expected_followup_window_hours INT NOT NULL DEFAULT 72,
  followup_due_at_utc TIMESTAMPTZ NOT NULL,
  followup_status TEXT NOT NULL DEFAULT 'pending',
  source TEXT NOT NULL DEFAULT 'gemini',
  ai_model_name TEXT NULL,
  ai_model_version TEXT NULL,
  prompt_version TEXT NULL,
  experiment_id TEXT NULL,
  variant_id TEXT NULL,
  is_randomized BOOLEAN NOT NULL DEFAULT false,
  randomization_allowed BOOLEAN NOT NULL DEFAULT false,
  risk_level TEXT NOT NULL DEFAULT 'low',
  safety_notes TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interventions_scan_id
  ON public.intervention_recommendations(scan_id);
CREATE INDEX IF NOT EXISTS idx_interventions_user_due
  ON public.intervention_recommendations(user_id, followup_due_at_utc);
CREATE INDEX IF NOT EXISTS idx_interventions_status_due
  ON public.intervention_recommendations(followup_status, followup_due_at_utc);
CREATE INDEX IF NOT EXISTS idx_interventions_code
  ON public.intervention_recommendations(recommendation_code);

ALTER TABLE public.intervention_recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "interventions_select_own" ON public.intervention_recommendations
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "interventions_insert_own" ON public.intervention_recommendations
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "interventions_update_own" ON public.intervention_recommendations
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "interventions_service_all" ON public.intervention_recommendations
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 8. INTERVENTION_OUTCOMES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.intervention_outcomes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  intervention_id UUID NOT NULL REFERENCES public.intervention_recommendations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plant_id UUID NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  adherence_status TEXT NOT NULL,
  adherence_notes TEXT NULL,
  outcome_status TEXT NOT NULL,
  outcome_confidence DOUBLE PRECISION NULL,
  outcome_notes TEXT NULL,
  followup_scan_id UUID NULL REFERENCES public.scans(id) ON DELETE SET NULL,
  followup_image_quality_score DOUBLE PRECISION NULL,
  days_since_recommendation INT NULL,
  reported_by TEXT NOT NULL DEFAULT 'user',
  ai_outcome_assessment_raw JSONB NULL,
  recorded_at_utc TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_outcomes_intervention_id
  ON public.intervention_outcomes(intervention_id);
CREATE INDEX IF NOT EXISTS idx_outcomes_user_recorded
  ON public.intervention_outcomes(user_id, recorded_at_utc DESC);
CREATE INDEX IF NOT EXISTS idx_outcomes_plant_recorded
  ON public.intervention_outcomes(plant_id, recorded_at_utc DESC);

ALTER TABLE public.intervention_outcomes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "outcomes_select_own" ON public.intervention_outcomes
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "outcomes_insert_own" ON public.intervention_outcomes
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "outcomes_service_all" ON public.intervention_outcomes
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 9. FOLLOWUP_MISSIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.followup_missions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plant_id UUID NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  intervention_id UUID NOT NULL REFERENCES public.intervention_recommendations(id) ON DELETE CASCADE,
  mission_type TEXT NOT NULL DEFAULT 'log_outcome',
  due_at_utc TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  notification_scheduled BOOLEAN NOT NULL DEFAULT false,
  completed_at_utc TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_missions_user_due
  ON public.followup_missions(user_id, due_at_utc);
CREATE INDEX IF NOT EXISTS idx_missions_status_due
  ON public.followup_missions(status, due_at_utc);
CREATE INDEX IF NOT EXISTS idx_missions_intervention_id
  ON public.followup_missions(intervention_id);

ALTER TABLE public.followup_missions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "missions_select_own" ON public.followup_missions
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "missions_insert_own" ON public.followup_missions
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "missions_update_own" ON public.followup_missions
  FOR UPDATE USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "missions_service_all" ON public.followup_missions
  FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- 10. STORAGE BUCKET
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
-- 11. UPDATED_AT TRIGGER
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

CREATE TRIGGER interventions_updated_at
  BEFORE UPDATE ON public.intervention_recommendations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================
-- 12. CHECK CONSTRAINTS
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

ALTER TABLE public.intervention_recommendations
  ADD CONSTRAINT chk_intervention_priority
  CHECK (priority IN ('high', 'medium', 'low'));

ALTER TABLE public.intervention_recommendations
  ADD CONSTRAINT chk_intervention_followup_status
  CHECK (followup_status IN ('pending', 'completed', 'skipped', 'expired'));

ALTER TABLE public.intervention_recommendations
  ADD CONSTRAINT chk_intervention_source
  CHECK (source IN ('gemini', 'rules', 'hybrid'));

ALTER TABLE public.intervention_recommendations
  ADD CONSTRAINT chk_intervention_risk_level
  CHECK (risk_level IN ('low', 'medium', 'high'));

ALTER TABLE public.intervention_recommendations
  ADD CONSTRAINT chk_intervention_followup_window
  CHECK (expected_followup_window_hours > 0);

ALTER TABLE public.intervention_outcomes
  ADD CONSTRAINT chk_outcome_adherence
  CHECK (adherence_status IN ('fully', 'partially', 'not_done', 'unknown'));

ALTER TABLE public.intervention_outcomes
  ADD CONSTRAINT chk_outcome_status
  CHECK (outcome_status IN ('improved', 'unchanged', 'worse', 'uncertain'));

ALTER TABLE public.intervention_outcomes
  ADD CONSTRAINT chk_outcome_reported_by
  CHECK (reported_by IN ('user', 'ai_inferred', 'hybrid'));

ALTER TABLE public.intervention_outcomes
  ADD CONSTRAINT chk_outcome_confidence
  CHECK (outcome_confidence IS NULL OR (outcome_confidence >= 0 AND outcome_confidence <= 1));

ALTER TABLE public.followup_missions
  ADD CONSTRAINT chk_mission_type
  CHECK (mission_type IN ('check_photo', 'confirm_action', 'log_outcome'));

ALTER TABLE public.followup_missions
  ADD CONSTRAINT chk_mission_status
  CHECK (status IN ('pending', 'completed', 'snoozed', 'skipped', 'expired'));
