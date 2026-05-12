-- Career Navigator MVP seed data
-- Keep seed minimal and idempotent.

BEGIN;

-- Seed skills
INSERT INTO skill (canonical_name, category)
VALUES
  ('JavaScript', 'Programming'),
  ('TypeScript', 'Programming'),
  ('React', 'Frameworks'),
  ('Node.js', 'Backend'),
  ('PostgreSQL', 'Databases'),
  ('AWS', 'Cloud'),
  ('Communication', 'Soft Skills'),
  ('System Design', 'Engineering')
ON CONFLICT (canonical_name) DO NOTHING;

-- Seed questionnaire questions (static MVP)
INSERT INTO questionnaire_question (code, prompt, category, skill_hint, sort_order, active)
VALUES
  ('Q1', 'How comfortable are you building a single-page application (SPA)?', 'Frontend', 'React', 10, TRUE),
  ('Q2', 'How comfortable are you designing REST APIs?', 'Backend', 'Node.js', 20, TRUE),
  ('Q3', 'How confident are you writing SQL queries with joins and aggregations?', 'Database', 'PostgreSQL', 30, TRUE),
  ('Q4', 'How comfortable are you deploying or operating a service in the cloud?', 'Cloud', 'AWS', 40, TRUE),
  ('Q5', 'How comfortable are you communicating technical trade-offs to non-technical stakeholders?', 'Soft Skills', 'Communication', 50, TRUE)
ON CONFLICT (code) DO NOTHING;

-- Seed career paths
INSERT INTO career_path (title, level, description)
VALUES
  ('Frontend Engineer', 'Mid', 'Build user-facing web applications with modern frameworks and strong UX.'),
  ('Backend Engineer', 'Mid', 'Design and operate reliable APIs, data models, and integrations.'),
  ('Full-Stack Engineer', 'Mid', 'Ship features across frontend, backend, and data layers.')
ON CONFLICT DO NOTHING;

-- Map targets to skills (idempotent via upsert using a SELECT)
WITH cp AS (
  SELECT id, title FROM career_path WHERE title IN ('Frontend Engineer','Backend Engineer','Full-Stack Engineer')
),
sk AS (
  SELECT id, canonical_name FROM skill
)
INSERT INTO career_path_skill_target (career_path_id, skill_id, target_level, weight)
SELECT
  cp.id,
  sk.id,
  CASE
    WHEN cp.title = 'Frontend Engineer' AND sk.canonical_name IN ('React','TypeScript','JavaScript') THEN 4
    WHEN cp.title = 'Backend Engineer' AND sk.canonical_name IN ('Node.js','PostgreSQL') THEN 4
    WHEN cp.title = 'Full-Stack Engineer' AND sk.canonical_name IN ('React','Node.js','PostgreSQL','TypeScript','JavaScript') THEN 4
    ELSE NULL
  END AS target_level,
  CASE
    WHEN sk.canonical_name IN ('Communication','System Design') THEN 0.8
    ELSE 1.0
  END AS weight
FROM cp
JOIN sk ON TRUE
WHERE
  (
    (cp.title = 'Frontend Engineer' AND sk.canonical_name IN ('React','TypeScript','JavaScript','Communication','System Design')) OR
    (cp.title = 'Backend Engineer' AND sk.canonical_name IN ('Node.js','PostgreSQL','Communication','System Design')) OR
    (cp.title = 'Full-Stack Engineer' AND sk.canonical_name IN ('React','Node.js','PostgreSQL','TypeScript','JavaScript','Communication','System Design'))
  )
ON CONFLICT (career_path_id, skill_id) DO UPDATE
SET target_level = EXCLUDED.target_level,
    weight = EXCLUDED.weight;

-- Seed marketplace items
INSERT INTO marketplace_item (item_type, title, provider, url, description, price_cents, currency, tags, skills)
VALUES
  ('course', 'React Fundamentals', 'Example Academy', 'https://example.com/react', 'A practical intro to React components, state, and routing.', 0, 'USD', ARRAY['react','frontend'], '["React","JavaScript"]'::jsonb),
  ('course', 'SQL for Analytics', 'Example Academy', 'https://example.com/sql', 'Learn joins, grouping, and common reporting queries.', 0, 'USD', ARRAY['sql','data'], '["PostgreSQL"]'::jsonb),
  ('certification', 'AWS Cloud Practitioner (Prep)', 'Example Academy', 'https://example.com/aws', 'Foundational cloud concepts and AWS basics.', 0, 'USD', ARRAY['aws','cloud'], '["AWS"]'::jsonb),
  ('book', 'System Design Basics', 'Example Press', 'https://example.com/system-design', 'Core concepts of designing scalable services.', 0, 'USD', ARRAY['architecture'], '["System Design"]'::jsonb)
ON CONFLICT DO NOTHING;

COMMIT;
