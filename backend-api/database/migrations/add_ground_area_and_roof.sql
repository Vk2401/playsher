-- Migration: locality, city and roof on grounds
-- Run: mysql -u root -p playsher < database/migrations/add_ground_area_and_roof.sql
--
-- `address` is one free-text blob, which cannot be searched by locality or
-- shown on a card. Players pick a venue by area first ("somewhere in
-- Adambakkam"), so the locality needs to be its own field.
--
-- has_roof answers the question that decides a monsoon booking, and it is not
-- an amenity — an amenity is something the venue provides, this is what the
-- venue *is*.

ALTER TABLE grounds
  ADD COLUMN IF NOT EXISTS area     VARCHAR(150) DEFAULT NULL AFTER address,
  ADD COLUMN IF NOT EXISTS city     VARCHAR(100) DEFAULT NULL AFTER area,
  ADD COLUMN IF NOT EXISTS has_roof TINYINT(1)   NOT NULL DEFAULT 0 AFTER city;

-- Searching by locality and city is the common path on the venues screen.
CREATE INDEX IF NOT EXISTS idx_grounds_area ON grounds (area);
CREATE INDEX IF NOT EXISTS idx_grounds_city ON grounds (city);
