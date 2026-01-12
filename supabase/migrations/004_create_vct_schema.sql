-- 004_create_vct_schema.sql
-- Purpose: Create VCT (Valorant Champions Tour) schema with teams, events, matches, 
-- points, stars, votes, and related tables. Supports user pick'em predictions with
-- RLS policies for user-generated content.
--
-- Dependencies:
-- - Requires citext extension (pgcrypto included by default in Supabase)
-- - Requires public.users table (created in 001_create_users_rls.sql)
-- - Uses public.set_updated_at() function (created in 001)
--
-- Security Model:
-- - VCT reference data (teams, events, matches): No RLS, public read access via views
-- - User leaderboard data (points, breakdown_pts, stars): No RLS, public read via views, backend writes
-- - User predictions (votes): RLS enabled - public read, users write their own only
-- - All writes restricted to service_role (backend) except votes (users can manage their own)
--
-- Data Architecture:
-- - Events: Manually created parent events (VCT 2025 Kickoff, VCT 2025 Masters Toronto)
-- - Sub_events: Scraped from VLR (Kickoff Americas, Kickoff EMEA, Masters Toronto Main Event)
-- - Points aggregate across breakdown_pts (one per region)
-- - Votes are public (like VLR.gg) but users can only edit their own
-- - Slugs for SEO-friendly URLs (generated in backend, stored here)
-- - No soft-delete columns (data is never deleted, permanent backlog)

-- ============================
-- 0) Per-table immutable helper functions (SECURITY DEFINER)
-- ============================

CREATE OR REPLACE FUNCTION public.prevent_teams_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.external_source IS DISTINCT FROM NEW.external_source THEN
    RAISE EXCEPTION 'external_source cannot be changed';
  END IF;
  IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
    RAISE EXCEPTION 'external_id cannot be changed';
  END IF;
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_teams_updates() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.prevent_events_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_events_updates() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.prevent_sub_events_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.parent_event_id IS DISTINCT FROM NEW.parent_event_id THEN
    RAISE EXCEPTION 'parent_event_id cannot be changed';
  END IF;
  IF OLD.external_source IS DISTINCT FROM NEW.external_source THEN
    RAISE EXCEPTION 'external_source cannot be changed';
  END IF;
  IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
    RAISE EXCEPTION 'external_id cannot be changed';
  END IF;
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_sub_events_updates() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.prevent_matches_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.event_id IS DISTINCT FROM NEW.event_id THEN
    RAISE EXCEPTION 'event_id cannot be changed';
  END IF;
  IF OLD.external_source IS DISTINCT FROM NEW.external_source THEN
    RAISE EXCEPTION 'external_source cannot be changed';
  END IF;
  IF OLD.external_id IS DISTINCT FROM NEW.external_id THEN
    RAISE EXCEPTION 'external_id cannot be changed';
  END IF;
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_matches_updates() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.prevent_points_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    RAISE EXCEPTION 'user_id cannot be changed';
  END IF;
  IF OLD.event_id IS DISTINCT FROM NEW.event_id THEN
    RAISE EXCEPTION 'event_id cannot be changed';
  END IF;
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_points_updates() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.prevent_breakdown_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.parent_points_id IS DISTINCT FROM NEW.parent_points_id THEN
    RAISE EXCEPTION 'parent_points_id cannot be changed';
  END IF;
  IF OLD.region IS DISTINCT FROM NEW.region THEN
    RAISE EXCEPTION 'region cannot be changed';
  END IF;
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_breakdown_updates() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.prevent_star_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    RAISE EXCEPTION 'user_id cannot be changed';
  END IF;
  IF OLD.event_id IS DISTINCT FROM NEW.event_id THEN
    RAISE EXCEPTION 'event_id cannot be changed';
  END IF;
  IF OLD.category IS DISTINCT FROM NEW.category THEN
    RAISE EXCEPTION 'category cannot be changed';
  END IF;
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_star_updates() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.prevent_votes_updates()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    RAISE EXCEPTION 'user_id cannot be changed';
  END IF;
  IF OLD.match_id IS DISTINCT FROM NEW.match_id THEN
    RAISE EXCEPTION 'match_id cannot be changed';
  END IF;
  IF OLD.created_at IS DISTINCT FROM NEW.created_at THEN
    RAISE EXCEPTION 'created_at cannot be changed';
  END IF;
  RETURN NEW;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.prevent_votes_updates() FROM PUBLIC;

COMMENT ON FUNCTION public.prevent_teams_updates() IS 'Prevent updates to immutable fields in teams table';
COMMENT ON FUNCTION public.prevent_events_updates() IS 'Prevent updates to immutable fields in events table';
COMMENT ON FUNCTION public.prevent_sub_events_updates() IS 'Prevent updates to immutable fields in sub_events table';
COMMENT ON FUNCTION public.prevent_matches_updates() IS 'Prevent updates to immutable fields in matches table';
COMMENT ON FUNCTION public.prevent_points_updates() IS 'Prevent updates to immutable fields in points table';
COMMENT ON FUNCTION public.prevent_breakdown_updates() IS 'Prevent updates to immutable fields in breakdown_pts table';
COMMENT ON FUNCTION public.prevent_star_updates() IS 'Prevent updates to immutable fields in stars table';
COMMENT ON FUNCTION public.prevent_votes_updates() IS 'Prevent updates to immutable fields in votes table';

-- ============================
-- 1) TEAMS
-- ============================
CREATE TABLE IF NOT EXISTS public.teams (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  short_name citext NOT NULL,
  slug citext NOT NULL,
  logo_storage_path text,
  external_id text,
  external_source text,
  metadata jsonb DEFAULT '{}'::jsonb,
  last_scraped_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT teams_short_name_unique UNIQUE (short_name),
  CONSTRAINT teams_slug_unique UNIQUE (slug),
  CONSTRAINT teams_external_unique UNIQUE (external_source, external_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_teams_name ON public.teams (name);
CREATE INDEX IF NOT EXISTS idx_teams_slug ON public.teams (slug);
CREATE INDEX IF NOT EXISTS idx_teams_metadata_gin ON public.teams USING gin (metadata);

-- Triggers
DROP TRIGGER IF EXISTS set_updated_at_on_teams ON public.teams;
CREATE TRIGGER set_updated_at_on_teams
  BEFORE UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ensure_immutable_on_teams ON public.teams;
CREATE TRIGGER ensure_immutable_on_teams
  BEFORE UPDATE ON public.teams
  FOR EACH ROW EXECUTE FUNCTION public.prevent_teams_updates();

-- Public view (hide internal fields)
CREATE OR REPLACE VIEW public.teams_public AS
SELECT 
  id, 
  name, 
  short_name, 
  slug,
  logo_storage_path
FROM public.teams;

GRANT SELECT ON public.teams_public TO PUBLIC;

COMMENT ON TABLE public.teams IS 'Valorant esports teams scraped from VLR';
COMMENT ON VIEW public.teams_public IS 'Public view of teams (hides metadata and scraping internals)';

-- ============================
-- 2) EVENTS (Manually created parent events - NOT scraped)
-- ============================
CREATE TABLE IF NOT EXISTS public.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  kind citext NOT NULL,
  location text,
  year smallint,
  ongoing boolean DEFAULT false,
  bracket_type text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_events_name ON public.events (name);
CREATE INDEX IF NOT EXISTS idx_events_kind ON public.events (kind);
CREATE INDEX IF NOT EXISTS idx_events_year ON public.events (year);
CREATE INDEX IF NOT EXISTS idx_events_ongoing ON public.events (ongoing);
CREATE INDEX IF NOT EXISTS idx_events_metadata_gin ON public.events USING gin (metadata);

-- Triggers
DROP TRIGGER IF EXISTS set_updated_at_on_events ON public.events;
CREATE TRIGGER set_updated_at_on_events
  BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ensure_immutable_on_events ON public.events;
CREATE TRIGGER ensure_immutable_on_events
  BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.prevent_events_updates();

-- Public view
CREATE OR REPLACE VIEW public.events_public AS
SELECT 
  id,
  name,
  kind, 
  location, 
  year, 
  ongoing, 
  bracket_type
FROM public.events;

GRANT SELECT ON public.events_public TO PUBLIC;

COMMENT ON TABLE public.events IS 'VCT parent events manually created for aggregation (e.g., VCT 2025 Kickoff, VCT 2025 Masters Toronto)';
COMMENT ON VIEW public.events_public IS 'Public view of parent events';

-- ============================
-- 3) SUB_EVENTS (Scraped from VLR - child events under parent)
-- ============================
CREATE TABLE IF NOT EXISTS public.sub_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  region citext NOT NULL,
  match_url text,
  pickem_url text,
  external_id text,
  external_source text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT sub_events_external_unique UNIQUE (external_source, external_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sub_events_parent ON public.sub_events (parent_event_id);
CREATE INDEX IF NOT EXISTS idx_sub_events_region ON public.sub_events (region);
CREATE INDEX IF NOT EXISTS idx_sub_events_metadata_gin ON public.sub_events USING gin (metadata);

-- Triggers
DROP TRIGGER IF EXISTS set_updated_at_on_sub_events ON public.sub_events;
CREATE TRIGGER set_updated_at_on_sub_events
  BEFORE UPDATE ON public.sub_events
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ensure_immutable_on_sub_events ON public.sub_events;
CREATE TRIGGER ensure_immutable_on_sub_events
  BEFORE UPDATE ON public.sub_events
  FOR EACH ROW EXECUTE FUNCTION public.prevent_sub_events_updates();

-- Public view
CREATE OR REPLACE VIEW public.sub_events_public AS
SELECT 
  id, 
  parent_event_id, 
  region,
  match_url, 
  pickem_url
FROM public.sub_events;

GRANT SELECT ON public.sub_events_public TO PUBLIC;

COMMENT ON TABLE public.sub_events IS 'VLR scraped events that roll up to parent events (e.g., Kickoff Americas, Kickoff EMEA under VCT 2025 Kickoff)';
COMMENT ON VIEW public.sub_events_public IS 'Public view of scraped sub-events';

-- ============================
-- 4) MATCHES
-- ============================
CREATE TABLE IF NOT EXISTS public.matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  sub_event_id uuid REFERENCES public.sub_events(id) ON DELETE SET NULL,
  team1_id uuid REFERENCES public.teams(id) ON DELETE SET NULL,
  team2_id uuid REFERENCES public.teams(id) ON DELETE SET NULL,
  winner_id uuid REFERENCES public.teams(id) ON DELETE SET NULL,
  region citext,
  phase citext,
  type text,
  match_date date,
  match_time time,
  playoff_bracket_id text,
  external_id text,
  external_source text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT matches_external_unique UNIQUE (external_source, external_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_matches_event ON public.matches (event_id);
CREATE INDEX IF NOT EXISTS idx_matches_sub_event ON public.matches (sub_event_id);
CREATE INDEX IF NOT EXISTS idx_matches_date ON public.matches (match_date);
CREATE INDEX IF NOT EXISTS idx_matches_region ON public.matches (region);
CREATE INDEX IF NOT EXISTS idx_matches_phase ON public.matches (phase);
CREATE INDEX IF NOT EXISTS idx_matches_playoff_bracket ON public.matches (playoff_bracket_id);
CREATE INDEX IF NOT EXISTS idx_matches_teams ON public.matches (team1_id, team2_id);
CREATE INDEX IF NOT EXISTS idx_matches_metadata_gin ON public.matches USING gin (metadata);

-- Triggers
DROP TRIGGER IF EXISTS set_updated_at_on_matches ON public.matches;
CREATE TRIGGER set_updated_at_on_matches
  BEFORE UPDATE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ensure_immutable_on_matches ON public.matches;
CREATE TRIGGER ensure_immutable_on_matches
  BEFORE UPDATE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION public.prevent_matches_updates();

-- Public view
CREATE OR REPLACE VIEW public.matches_public AS
SELECT 
  id, 
  event_id,
  sub_event_id,
  team1_id, 
  team2_id, 
  winner_id, 
  region, 
  phase, 
  type, 
  match_date, 
  match_time, 
  playoff_bracket_id
FROM public.matches;

GRANT SELECT ON public.matches_public TO PUBLIC;

COMMENT ON TABLE public.matches IS 'VCT tournament matches with teams, dates, and results';
COMMENT ON COLUMN public.matches.phase IS 'Match phase: groups, playoffs, finals, etc.';
COMMENT ON COLUMN public.matches.type IS 'Match type: bo1, bo3, bo5, etc.';

-- ============================
-- 5) POINTS
-- ============================
CREATE TABLE IF NOT EXISTS public.points (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  nr_points integer NOT NULL DEFAULT 0,
  external_id text,
  external_source text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT points_user_event_unique UNIQUE (user_id, event_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_points_user ON public.points (user_id);
CREATE INDEX IF NOT EXISTS idx_points_event ON public.points (event_id);
CREATE INDEX IF NOT EXISTS idx_points_nr_points ON public.points (nr_points DESC);
CREATE INDEX IF NOT EXISTS idx_points_metadata_gin ON public.points USING gin (metadata);

-- Triggers
DROP TRIGGER IF EXISTS set_updated_at_on_points ON public.points;
CREATE TRIGGER set_updated_at_on_points
  BEFORE UPDATE ON public.points
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ensure_immutable_on_points ON public.points;
CREATE TRIGGER ensure_immutable_on_points
  BEFORE UPDATE ON public.points
  FOR EACH ROW EXECUTE FUNCTION public.prevent_points_updates();

-- Public view for leaderboards (no ORDER BY - let client decide)
CREATE OR REPLACE VIEW public.points_public AS
SELECT 
  p.id,
  p.user_id,
  u.oauth_username,
  u.display_name,
  u.avatar_url,
  p.event_id,
  e.name as event_name,
  e.kind as event_kind,
  e.year as event_year,
  p.nr_points
FROM public.points p
JOIN public.users u ON p.user_id = u.user_id
JOIN public.events e ON p.event_id = e.id;

GRANT SELECT ON public.points_public TO PUBLIC;

COMMENT ON TABLE public.points IS 'User pick''em points per event (aggregated from breakdown_pts)';
COMMENT ON VIEW public.points_public IS 'Public leaderboard view with user and event info';

-- ============================
-- 6) BREAKDOWN_PTS
-- ============================
CREATE TABLE IF NOT EXISTS public.breakdown_pts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_points_id uuid NOT NULL REFERENCES public.points(id) ON DELETE CASCADE,
  region citext NOT NULL,
  nr_points integer NOT NULL DEFAULT 0,
  vlr_handle text,
  external_id text,
  external_source text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT breakdown_pts_unique_parent_region UNIQUE (parent_points_id, region)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_breakdown_parent ON public.breakdown_pts (parent_points_id);
CREATE INDEX IF NOT EXISTS idx_breakdown_region ON public.breakdown_pts (region);
CREATE INDEX IF NOT EXISTS idx_breakdown_metadata_gin ON public.breakdown_pts USING gin (metadata);

-- Triggers
DROP TRIGGER IF EXISTS set_updated_at_on_breakdown_pts ON public.breakdown_pts;
CREATE TRIGGER set_updated_at_on_breakdown_pts
  BEFORE UPDATE ON public.breakdown_pts
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ensure_immutable_on_breakdown_pts ON public.breakdown_pts;
CREATE TRIGGER ensure_immutable_on_breakdown_pts
  BEFORE UPDATE ON public.breakdown_pts
  FOR EACH ROW EXECUTE FUNCTION public.prevent_breakdown_updates();

-- Public view
CREATE OR REPLACE VIEW public.breakdown_pts_public AS
SELECT 
  b.id,
  b.parent_points_id,
  b.region,
  b.nr_points,
  p.user_id,
  u.oauth_username,
  u.display_name,
  p.event_id,
  e.name as event_name
FROM public.breakdown_pts b
JOIN public.points p ON b.parent_points_id = p.id
JOIN public.users u ON p.user_id = u.user_id
JOIN public.events e ON p.event_id = e.id;

GRANT SELECT ON public.breakdown_pts_public TO PUBLIC;

COMMENT ON TABLE public.breakdown_pts IS 'Regional breakdown of pick''em points (e.g., Americas: 40pts, EMEA: 50pts)';
COMMENT ON VIEW public.breakdown_pts_public IS 'Public view of point breakdowns with user and event context';

-- ============================
-- 7) STARS
-- ============================
CREATE TABLE IF NOT EXISTS public.stars (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  category citext NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_stars_user ON public.stars (user_id);
CREATE INDEX IF NOT EXISTS idx_stars_event ON public.stars (event_id);
CREATE INDEX IF NOT EXISTS idx_stars_category ON public.stars (category);

-- Immutable trigger
DROP TRIGGER IF EXISTS ensure_immutable_on_stars ON public.stars;
CREATE TRIGGER ensure_immutable_on_stars
  BEFORE UPDATE ON public.stars
  FOR EACH ROW EXECUTE FUNCTION public.prevent_star_updates();

-- Public view
CREATE OR REPLACE VIEW public.stars_public AS
SELECT 
  s.id,
  s.user_id,
  u.oauth_username,
  u.display_name,
  u.avatar_url,
  s.event_id,
  e.name as event_name,
  e.kind as event_kind,
  e.year as event_year,
  s.category,
  s.created_at
FROM public.stars s
JOIN public.users u ON s.user_id = u.user_id
JOIN public.events e ON s.event_id = e.id;

GRANT SELECT ON public.stars_public TO PUBLIC;

COMMENT ON TABLE public.stars IS 'User achievements for winning pick''em events';
COMMENT ON COLUMN public.stars.category IS 'Award type: kickoff_winner, masters_winner, champions_winner';
COMMENT ON VIEW public.stars_public IS 'Public view of user achievements with event and user details';

-- ============================
-- 8) VOTES
-- ============================
CREATE TABLE IF NOT EXISTS public.votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,
  match_id uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  vote_team_id uuid REFERENCES public.teams(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT votes_unique_user_match UNIQUE (user_id, match_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_votes_user ON public.votes (user_id);
CREATE INDEX IF NOT EXISTS idx_votes_match ON public.votes (match_id);
CREATE INDEX IF NOT EXISTS idx_votes_vote_team ON public.votes (vote_team_id);
CREATE INDEX IF NOT EXISTS idx_votes_metadata_gin ON public.votes USING gin (metadata);

-- Triggers
DROP TRIGGER IF EXISTS set_updated_at_on_votes ON public.votes;
CREATE TRIGGER set_updated_at_on_votes
  BEFORE UPDATE ON public.votes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS ensure_immutable_on_votes ON public.votes;
CREATE TRIGGER ensure_immutable_on_votes
  BEFORE UPDATE ON public.votes
  FOR EACH ROW EXECUTE FUNCTION public.prevent_votes_updates();

-- Enable RLS
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Everyone can read all votes, users can only write their own
CREATE POLICY votes_read_all
  ON public.votes
  FOR SELECT
  TO PUBLIC
  USING (true);

CREATE POLICY votes_insert_own
  ON public.votes
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY votes_update_own
  ON public.votes
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY votes_delete_own
  ON public.votes
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- Public view with user info
CREATE OR REPLACE VIEW public.votes_public AS
SELECT 
  v.id,
  v.user_id,
  u.oauth_username,
  u.display_name,
  u.avatar_url,
  v.match_id,
  v.vote_team_id,
  t.name as voted_team_name,
  t.short_name as voted_team_short_name,
  v.created_at,
  v.updated_at
FROM public.votes v
JOIN public.users u ON v.user_id = u.user_id
LEFT JOIN public.teams t ON v.vote_team_id = t.id;

GRANT SELECT ON public.votes_public TO PUBLIC;

-- Vote statistics view (aggregated by match/team)
CREATE OR REPLACE VIEW public.vote_stats_public AS
SELECT 
  v.match_id,
  v.vote_team_id,
  t.name as team_name,
  t.short_name as team_short_name,
  COUNT(*) as vote_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY v.match_id), 2) as vote_percentage
FROM public.votes v
LEFT JOIN public.teams t ON v.vote_team_id = t.id
WHERE v.vote_team_id IS NOT NULL
GROUP BY v.match_id, v.vote_team_id, t.name, t.short_name;

GRANT SELECT ON public.vote_stats_public TO PUBLIC;

COMMENT ON TABLE public.votes IS 'User pick''em predictions for matches (public like VLR.gg, but users can only edit their own)';
COMMENT ON VIEW public.votes_public IS 'Public view of all user votes with user and team details';
COMMENT ON VIEW public.vote_stats_public IS 'Aggregated vote statistics per match showing vote counts and percentages';

-- ============================
-- 9) Final Notes
-- ============================
-- Data Model:
-- - Events: Manually created parent containers (VCT 2025 Kickoff, VCT 2025 Masters Toronto)
-- - Sub_events: Scraped from VLR and linked to parent events (Kickoff Americas, Kickoff EMEA, etc.)
-- - Matches: Scraped from VLR, linked to both parent event and sub_event
--
-- RLS Summary:
-- - VCT reference data (teams, events, matches, sub_events): No RLS, public read via views
-- - User leaderboard data (points, breakdown_pts, stars): No RLS, public read via views, backend writes
-- - User predictions (votes): RLS enabled - all can read, users write own only
--
-- Vote Locking:
-- - Match vote locking enforced in application layer (check match_date + match_time)
-- - More flexible for edge cases (undefined matches, rescheduling)
--
-- Slug Generation:
-- - Slugs generated in backend before INSERT
-- - Example: "Team Heretics" -> "team-heretics", "LEVIATÁN" -> "leviatan"
--
-- Points Aggregation:
-- - points.nr_points is aggregate of breakdown_pts.nr_points
-- - Regional events: 4 breakdowns (americas, emea, pacific, china)
-- - International events: 1 breakdown (region: 'international')
--
-- External IDs:
-- - Unique constraints on (external_source, external_id) prevent duplicate imports
-- - Typically external_source = 'vlr' for VLR.gg data
-- - Events do NOT have external IDs (manually created, not scraped)
--
-- No Soft Deletes:
-- - No deleted_at columns anywhere
-- - Data is permanent and never deleted
-- - Complete backlog of all historical VCT data
--
-- Public Views:
-- - All tables have public views that hide internal fields (metadata, external_id, last_scraped_at)
-- - Views are granted to PUBLIC (all data is public)
-- - Principle of least privilege: expose only what's needed for the application
--
-- Immutable Fields:
-- - Per-table trigger functions prevent updates to critical fields
-- - More explicit and maintainable than generic dynamic approach
-- - Each function is SECURITY DEFINER with revoked public execute