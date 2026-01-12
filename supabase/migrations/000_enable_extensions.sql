-- 000_enable_extensions.sql
-- Purpose: Enable required PostgreSQL extensions for the VCT schema

-- Enable pgcrypto for gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Enable citext for case-insensitive text columns
CREATE EXTENSION IF NOT EXISTS citext;

-- Verify extensions are installed
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    RAISE EXCEPTION 'pgcrypto extension not installed';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'citext') THEN
    RAISE EXCEPTION 'citext extension not installed';
  END IF;
  
  RAISE NOTICE 'All required extensions are installed';
END $$;