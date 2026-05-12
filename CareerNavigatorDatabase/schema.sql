-- Career Navigator MVP schema (PostgreSQL)
-- Notes:
-- - Keep schema normalized where it matters (skills/evidence/roadmap).
-- - Prefer idempotent DDL (IF NOT EXISTS) to allow local re-apply.
-- - This file is applied by the DB container's init scripts.

BEGIN;

-- Extensions (optional; keep minimal)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =========================
-- Core: users & auth
-- =========================
CREATE TABLE IF NOT EXISTS app_user (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_app_user_created_at ON app_user(created_at);

-- =========================
-- Documents & persona
-- =========================
CREATE TABLE IF NOT EXISTS persona_document (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  doc_type TEXT NOT NULL,                 -- e.g., resume, certificate, portfolio
  file_name TEXT,
  source_url TEXT,
  content_text TEXT,                      -- extracted text (MVP)
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_persona_document_user_id_created_at
  ON persona_document(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS persona_profile (
  user_id UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  headline TEXT,
  summary TEXT,
  location TEXT,
  years_experience NUMERIC(4,1),
  desired_roles TEXT[],
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================
-- Skills taxonomy & evidence
-- =========================
CREATE TABLE IF NOT EXISTS skill (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_name TEXT NOT NULL UNIQUE, -- normalized skill label
  category TEXT,                       -- e.g., "Programming", "Cloud", "Soft Skills"
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_skill_category ON skill(category);

CREATE TABLE IF NOT EXISTS user_skill (
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  skill_id UUID NOT NULL REFERENCES skill(id) ON DELETE RESTRICT,
  source TEXT NOT NULL DEFAULT 'persona', -- persona | assessment | imported | manual
  self_rating SMALLINT,                  -- 0-5
  computed_level SMALLINT,               -- 0-5
  confidence NUMERIC(3,2),               -- 0.00-1.00
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, skill_id),
  CONSTRAINT chk_user_skill_rating CHECK (self_rating IS NULL OR (self_rating BETWEEN 0 AND 5)),
  CONSTRAINT chk_user_skill_level CHECK (computed_level IS NULL OR (computed_level BETWEEN 0 AND 5)),
  CONSTRAINT chk_user_skill_confidence CHECK (confidence IS NULL OR (confidence BETWEEN 0 AND 1))
);

CREATE INDEX IF NOT EXISTS idx_user_skill_user_id ON user_skill(user_id);
CREATE INDEX IF NOT EXISTS idx_user_skill_skill_id ON user_skill(skill_id);

CREATE TABLE IF NOT EXISTS skill_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  skill_id UUID NOT NULL REFERENCES skill(id) ON DELETE RESTRICT,
  document_id UUID REFERENCES persona_document(id) ON DELETE SET NULL,
  evidence_type TEXT NOT NULL,          -- project | job | cert | course | link | note
  title TEXT,
  description TEXT,
  url TEXT,
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_skill_evidence_user_skill ON skill_evidence(user_id, skill_id);
CREATE INDEX IF NOT EXISTS idx_skill_evidence_document_id ON skill_evidence(document_id);

-- =========================
-- Assessments / questionnaire
-- =========================
CREATE TABLE IF NOT EXISTS assessment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  assessment_type TEXT NOT NULL DEFAULT 'questionnaire', -- questionnaire | other
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'in_progress' -- in_progress | completed
);

CREATE INDEX IF NOT EXISTS idx_assessment_user_id_started_at ON assessment(user_id, started_at DESC);

CREATE TABLE IF NOT EXISTS questionnaire_question (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,         -- stable identifier
  prompt TEXT NOT NULL,
  category TEXT,
  skill_hint TEXT,                   -- optional: references a skill canonical name (soft link)
  sort_order INT NOT NULL DEFAULT 0,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_questionnaire_question_active_order
  ON questionnaire_question(active, sort_order);

CREATE TABLE IF NOT EXISTS questionnaire_response (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_id UUID NOT NULL REFERENCES assessment(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES questionnaire_question(id) ON DELETE RESTRICT,
  response_value JSONB NOT NULL,          -- flexible (likert, multiple choice, text)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (assessment_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_questionnaire_response_assessment_id
  ON questionnaire_response(assessment_id);

-- =========================
-- Career paths
-- =========================
CREATE TABLE IF NOT EXISTS career_path (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,                  -- e.g., "Frontend Engineer"
  level TEXT,                           -- e.g., "Junior", "Mid", "Senior"
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS career_path_skill_target (
  career_path_id UUID NOT NULL REFERENCES career_path(id) ON DELETE CASCADE,
  skill_id UUID NOT NULL REFERENCES skill(id) ON DELETE RESTRICT,
  target_level SMALLINT NOT NULL,
  weight NUMERIC(4,3) NOT NULL DEFAULT 1.0,
  PRIMARY KEY (career_path_id, skill_id),
  CONSTRAINT chk_target_level CHECK (target_level BETWEEN 0 AND 5)
);

CREATE INDEX IF NOT EXISTS idx_career_path_skill_target_skill_id
  ON career_path_skill_target(skill_id);

CREATE TABLE IF NOT EXISTS user_career_path (
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  career_path_id UUID NOT NULL REFERENCES career_path(id) ON DELETE RESTRICT,
  fit_score NUMERIC(5,2),
  explanation JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_selected BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, career_path_id)
);

CREATE INDEX IF NOT EXISTS idx_user_career_path_selected
  ON user_career_path(user_id, is_selected);

-- =========================
-- Roadmap, milestones, tasks
-- =========================
CREATE TABLE IF NOT EXISTS roadmap (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  career_path_id UUID REFERENCES career_path(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active', -- active | archived
  start_date DATE,
  target_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_roadmap_user_id_created_at ON roadmap(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS roadmap_milestone (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  roadmap_id UUID NOT NULL REFERENCES roadmap(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  due_date DATE,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_roadmap_milestone_roadmap_id_order
  ON roadmap_milestone(roadmap_id, sort_order);

CREATE TABLE IF NOT EXISTS roadmap_task (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  milestone_id UUID NOT NULL REFERENCES roadmap_milestone(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'not_started', -- not_started | in_progress | completed
  marketplace_item_id UUID, -- soft link; FK added later after marketplace table exists
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  CONSTRAINT chk_roadmap_task_status CHECK (status IN ('not_started','in_progress','completed'))
);

CREATE INDEX IF NOT EXISTS idx_roadmap_task_milestone_id_order
  ON roadmap_task(milestone_id, sort_order);

-- =========================
-- Dashboard phase state
-- =========================
CREATE TABLE IF NOT EXISTS dashboard_phase_state (
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  phase TEXT NOT NULL, -- build_profile | skill_assessment | career_paths | roadmap | marketplace
  state TEXT NOT NULL, -- not_started | in_progress | completed | locked
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, phase),
  CONSTRAINT chk_phase
    CHECK (phase IN ('build_profile','skill_assessment','career_paths','roadmap','marketplace')),
  CONSTRAINT chk_state
    CHECK (state IN ('not_started','in_progress','completed','locked'))
);

CREATE INDEX IF NOT EXISTS idx_dashboard_phase_state_user_id ON dashboard_phase_state(user_id);

-- =========================
-- Marketplace
-- =========================
CREATE TABLE IF NOT EXISTS marketplace_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_type TEXT NOT NULL,          -- course | certification | book | project | coaching
  title TEXT NOT NULL,
  provider TEXT,
  url TEXT,
  description TEXT,
  price_cents INT,
  currency TEXT,
  tags TEXT[],
  skills JSONB NOT NULL DEFAULT '[]'::jsonb, -- list of canonical skill names (MVP)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_marketplace_item_type ON marketplace_item(item_type);
CREATE INDEX IF NOT EXISTS idx_marketplace_item_created_at ON marketplace_item(created_at DESC);

-- Now add FK for roadmap_task.marketplace_item_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'fk_roadmap_task_marketplace_item'
  ) THEN
    ALTER TABLE roadmap_task
      ADD CONSTRAINT fk_roadmap_task_marketplace_item
      FOREIGN KEY (marketplace_item_id)
      REFERENCES marketplace_item(id)
      ON DELETE SET NULL;
  END IF;
END$$;

-- =========================
-- Aggregate views for Dashboard
-- =========================

-- Dashboard task completion stats per user
CREATE OR REPLACE VIEW v_user_task_stats AS
SELECT
  r.user_id,
  COUNT(t.id) AS total_tasks,
  COUNT(t.id) FILTER (WHERE t.status = 'completed') AS completed_tasks,
  COUNT(t.id) FILTER (WHERE t.status = 'in_progress') AS in_progress_tasks,
  COUNT(t.id) FILTER (WHERE t.status = 'not_started') AS not_started_tasks
FROM roadmap r
JOIN roadmap_milestone m ON m.roadmap_id = r.id
JOIN roadmap_task t ON t.milestone_id = m.id
WHERE r.status = 'active'
GROUP BY r.user_id;

-- Evidence count per user + number of skills with any evidence
CREATE OR REPLACE VIEW v_user_evidence_stats AS
SELECT
  e.user_id,
  COUNT(e.id) AS total_evidence,
  COUNT(DISTINCT e.skill_id) AS skills_with_evidence
FROM skill_evidence e
GROUP BY e.user_id;

-- Skills summary per user (how many have computed level, how many missing evidence)
CREATE OR REPLACE VIEW v_user_skill_stats AS
SELECT
  us.user_id,
  COUNT(*) AS total_skills,
  COUNT(*) FILTER (WHERE us.computed_level IS NOT NULL) AS skills_scored,
  COUNT(*) FILTER (
    WHERE NOT EXISTS (
      SELECT 1 FROM skill_evidence e
      WHERE e.user_id = us.user_id AND e.skill_id = us.skill_id
    )
  ) AS skills_missing_evidence
FROM user_skill us
GROUP BY us.user_id;

COMMIT;
