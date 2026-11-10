-- Renames accounts whose name differs from another account's name only by
-- letter case, so that the unique index on lower(users.name) can be created.
--
-- An account is empty when it is an ordinary user with no publicly visible
-- activity: no uploads, comments, forum posts or topics, galleries, public
-- filters, votes, faves, hides, private messages, tag or source changes,
-- artist links, commissions, poll votes, DNP requests, or badges, and no
-- avatar, description, or personal title. Private state such as settings,
-- watched tags, subscriptions, and login records is ignored.
--
-- One account in each group of colliding names keeps the name and the others
-- are renamed. The account that keeps it is the first one by:
--
--   1. not deactivated over deactivated;
--   2. not empty over empty;
--   3. staff account;
--   4. has an artist link that was not rejected;
--   5. has uploads;
--   6. has comments or forum posts;
--   7. most recent activity;
--   8. oldest account.
--
-- Most recent activity is the latest of the account's own public actions and
-- the last time it was seen, taken from its IP and fingerprint records.
-- Badges and received private messages are not the account's own actions.
--
-- A group is left untouched and listed for manual handling when that order
-- cannot pick one account: more than one staff account, or no staff account
-- and more than one with artist links, or neither of those and more than one
-- with uploads. Deactivated accounts are not counted here unless every
-- account in the group is deactivated.
--
-- A renamed account becomes "<name>_<4 random digits>". Its previous name is
-- recorded in user_name_changes and last_renamed_at is left alone, so the
-- owner can pick another name right away.
--
-- Usage:
--   psql -d <database> -f rename_case_variant_users.sql              (dry run)
--   psql -d <database> -v apply=1 -f rename_case_variant_users.sql   (commit)
--
-- The dry run does all the work and rolls it back. Renamed accounts can own
-- content, so rebuild the search indexes after a committed run.

\set ON_ERROR_STOP on

BEGIN;

CREATE FUNCTION pg_temp.user_slug(name text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT replace(replace(replace(replace(replace(replace(replace(name,
    '-', '-dash-'),
    '/', '-fwslash-'),
    '\', '-bwslash-'),
    ':', '-colon-'),
    '.', '-dot-'),
    '+', '-plus-'),
    ' ', '+')
$$;

CREATE TEMP TABLE case_variant_users ON COMMIT DROP AS
SELECT id, name, lower(name) AS lname
FROM users
WHERE lower(name) IN (SELECT lower(name) FROM users GROUP BY 1 HAVING count(*) > 1);

ALTER TABLE case_variant_users ADD PRIMARY KEY (id);
ANALYZE case_variant_users;

-- One row per reason an account is not empty. last_at is the time of the
-- latest such action, and is null for a reason that is not an action taken
-- by the account itself.
CREATE TEMP TABLE user_activity (
  user_id bigint NOT NULL,
  source text NOT NULL,
  last_at timestamp
) ON COMMIT DROP;

-- Publicly visible activity. Tables and columns that this schema version
-- does not have are skipped.
DO $$
DECLARE
  ref record;
BEGIN
  FOR ref IN
    SELECT v.tbl, v.col, v.filter, v.own_action
    FROM (VALUES
      ('images', 'user_id', NULL, true),
      ('comments', 'user_id', NULL, true),
      ('posts', 'user_id', NULL, true),
      ('topics', 'user_id', NULL, true),
      ('galleries', 'user_id', NULL, true),
      ('galleries', 'creator_id', NULL, true),
      ('filters', 'user_id', 'public', true),
      ('image_votes', 'user_id', NULL, true),
      ('image_faves', 'user_id', NULL, true),
      ('image_hides', 'user_id', NULL, true),
      ('conversations', 'from_id', NULL, true),
      ('conversations', 'to_id', NULL, false),
      ('messages', 'from_id', NULL, true),
      ('tag_changes', 'user_id', NULL, true),
      ('tag_changes_legacy', 'user_id', NULL, true),
      ('source_changes', 'user_id', NULL, true),
      ('old_source_changes', 'user_id', NULL, true),
      ('artist_links', 'user_id', NULL, true),
      ('commissions', 'user_id', NULL, true),
      ('poll_votes', 'user_id', NULL, true),
      ('dnp_entries', 'requesting_user_id', NULL, true),
      ('badge_awards', 'user_id', NULL, false)
    ) AS v(tbl, col, filter, own_action)
    WHERE EXISTS (
      SELECT 1 FROM pg_attribute att
      WHERE att.attrelid = to_regclass(v.tbl) AND att.attname = v.col AND NOT att.attisdropped
    )
  LOOP
    EXECUTE format(
      'INSERT INTO user_activity (user_id, source, last_at)
       SELECT t.%1$I, %2$L, %5$s FROM %3$I t
       WHERE t.%1$I IN (SELECT id FROM case_variant_users)%4$s
       GROUP BY t.%1$I',
      ref.col, ref.tbl || '.' || ref.col, ref.tbl, coalesce(' AND t.' || quote_ident(ref.filter), ''),
      CASE WHEN ref.own_action THEN 'max(t.created_at)' ELSE 'NULL::timestamp' END
    );
  END LOOP;
END
$$;

-- Public profile content, and staff accounts.
INSERT INTO user_activity (user_id, source)
SELECT u.id, checks.source
FROM users u
JOIN case_variant_users cv ON cv.id = u.id
CROSS JOIN LATERAL (VALUES
  ('users.role', u.role <> 'user' OR u.secondary_role IS NOT NULL),
  ('users.avatar', u.avatar IS NOT NULL),
  ('users.description', coalesce(u.description, '') <> ''),
  ('users.personal_title', coalesce(u.personal_title, '') <> '')
) AS checks(source, active)
WHERE checks.active;

CREATE TEMP TABLE name_claims ON COMMIT DROP AS
SELECT cv.id, cv.name, cv.lname,
       u.deleted_at IS NOT NULL AS deactivated,
       NOT EXISTS (SELECT 1 FROM user_activity a WHERE a.user_id = cv.id) AS empty,
       EXISTS (SELECT 1 FROM user_activity a WHERE a.user_id = cv.id AND a.source = 'users.role') AS staff,
       EXISTS (SELECT 1 FROM artist_links l WHERE l.user_id = cv.id AND l.aasm_state <> 'rejected') AS has_artist_links,
       EXISTS (SELECT 1 FROM user_activity a WHERE a.user_id = cv.id AND a.source = 'images.user_id') AS has_uploads,
       EXISTS (SELECT 1 FROM user_activity a WHERE a.user_id = cv.id
               AND a.source IN ('comments.user_id', 'posts.user_id')) AS has_comments_or_posts,
       greatest(
         (SELECT max(a.last_at) FROM user_activity a WHERE a.user_id = cv.id),
         (SELECT max(i.updated_at) FROM user_ips i WHERE i.user_id = cv.id),
         (SELECT max(f.updated_at) FROM user_fingerprints f WHERE f.user_id = cv.id)
       ) AS last_active_at
FROM case_variant_users cv
JOIN users u ON u.id = cv.id;

CREATE TEMP TABLE unresolved_groups ON COMMIT DROP AS
SELECT lname,
       CASE
         WHEN count(*) FILTER (WHERE staff) > 1 THEN 'more than one staff account'
         WHEN count(*) FILTER (WHERE has_artist_links) > 1 THEN 'more than one account with artist links'
         ELSE 'more than one account with uploads'
       END AS reason
FROM name_claims c
WHERE NOT c.deactivated
   OR NOT EXISTS (SELECT 1 FROM name_claims o WHERE o.lname = c.lname AND NOT o.deactivated)
GROUP BY lname
HAVING count(*) FILTER (WHERE staff) > 1
    OR (count(*) FILTER (WHERE staff) = 0 AND count(*) FILTER (WHERE has_artist_links) > 1)
    OR (count(*) FILTER (WHERE staff) = 0 AND count(*) FILTER (WHERE has_artist_links) = 0
        AND count(*) FILTER (WHERE has_uploads) > 1);

CREATE TEMP TABLE user_renames ON COMMIT DROP AS
WITH ranked AS (
  SELECT c.*,
         first_value(c.id) OVER (
           PARTITION BY c.lname
           ORDER BY c.deactivated, c.empty, c.staff DESC, c.has_artist_links DESC, c.has_uploads DESC,
                    c.has_comments_or_posts DESC, c.last_active_at DESC NULLS LAST, c.id
         ) AS keeper_id
  FROM name_claims c
  WHERE c.lname NOT IN (SELECT lname FROM unresolved_groups)
)
SELECT r.id, r.name AS old_name, NULL::text AS new_name, r.keeper_id,
       CASE
         WHEN r.empty THEN NULL
         WHEN r.deactivated AND NOT k.deactivated THEN 'deactivated account'
         WHEN k.staff AND NOT r.staff THEN 'staff account'
         WHEN k.has_artist_links AND NOT r.has_artist_links THEN 'artist links'
         WHEN k.has_uploads AND NOT r.has_uploads THEN 'uploads'
         WHEN k.has_comments_or_posts AND NOT r.has_comments_or_posts THEN 'comments or posts'
         WHEN k.last_active_at IS DISTINCT FROM r.last_active_at THEN 'more recent activity'
         ELSE 'older account'
       END AS keeper_decided_by
FROM ranked r
JOIN name_claims k ON k.id = r.keeper_id
WHERE r.id <> r.keeper_id;

CREATE TEMP TABLE taken_names ON COMMIT DROP AS
SELECT DISTINCT lower(name) AS lname FROM users;

ALTER TABLE taken_names ADD PRIMARY KEY (lname);

DO $$
DECLARE
  target record;
  candidate text;
  attempts integer;
  utc_now timestamp := timezone('utc', now());
BEGIN
  FOR target IN SELECT id, old_name FROM user_renames ORDER BY id LOOP
    attempts := 0;

    LOOP
      -- Names are limited to 50 characters.
      candidate := left(target.old_name, 45) || '_' || lpad(floor(random() * 10000)::integer::text, 4, '0');

      BEGIN
        INSERT INTO taken_names VALUES (lower(candidate));
        EXIT;
      EXCEPTION WHEN unique_violation THEN
        attempts := attempts + 1;

        IF attempts >= 100 THEN
          RAISE EXCEPTION 'no free name found for user % (%)', target.id, target.old_name;
        END IF;
      END;
    END LOOP;

    UPDATE users
    SET name = candidate, slug = pg_temp.user_slug(candidate), updated_at = utc_now
    WHERE id = target.id;

    INSERT INTO user_name_changes (user_id, name, created_at, updated_at)
    VALUES (target.id, target.old_name, utc_now, utc_now);

    UPDATE user_renames SET new_name = candidate WHERE id = target.id;
  END LOOP;
END
$$;

\echo
\echo '== Renamed empty accounts =='
SELECT id, old_name, new_name
FROM user_renames
WHERE keeper_decided_by IS NULL
ORDER BY lower(old_name), id;

\echo '== Renamed accounts that have activity =='
SELECT r.id, r.old_name, r.new_name, c.deactivated, c.last_active_at::date AS last_active,
       (SELECT string_agg(DISTINCT a.source, ', ' ORDER BY a.source)
        FROM user_activity a WHERE a.user_id = r.id) AS activity,
       r.keeper_id, k.name AS keeper_name, r.keeper_decided_by,
       k.last_active_at::date AS keeper_last_active,
       (SELECT string_agg(DISTINCT a.source, ', ' ORDER BY a.source)
        FROM user_activity a WHERE a.user_id = r.keeper_id) AS keeper_activity
FROM user_renames r
JOIN name_claims c ON c.id = r.id
JOIN name_claims k ON k.id = r.keeper_id
WHERE r.keeper_decided_by IS NOT NULL
ORDER BY lower(r.old_name), r.id;

\echo '== Groups left untouched: handle these manually =='
SELECT g.lname AS name_group, g.reason, c.id, c.name, u.created_at::date AS registered,
       c.deactivated, c.last_active_at::date AS last_active,
       (SELECT string_agg(DISTINCT a.source, ', ' ORDER BY a.source)
        FROM user_activity a WHERE a.user_id = c.id) AS activity
FROM unresolved_groups g
JOIN name_claims c ON c.lname = g.lname
JOIN users u ON u.id = c.id
ORDER BY g.lname, c.id;

\echo '== Summary =='
SELECT (SELECT count(DISTINCT lname) FROM case_variant_users) AS name_groups,
       (SELECT count(*) FROM case_variant_users) AS accounts_in_groups,
       (SELECT count(*) FROM user_renames WHERE keeper_decided_by IS NULL) AS empty_accounts_renamed,
       (SELECT count(*) FROM user_renames WHERE keeper_decided_by IS NOT NULL) AS active_accounts_renamed,
       (SELECT count(*) FROM (SELECT 1 FROM users GROUP BY lower(name) HAVING count(*) > 1) g) AS groups_left_untouched;

SELECT keeper_decided_by, count(*) AS active_accounts_renamed
FROM user_renames
WHERE keeper_decided_by IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;

\if :{?apply}
  COMMIT;
  \echo 'Committed.'
\else
  ROLLBACK;
  \echo 'Dry run: rolled back. Pass -v apply=1 to commit.'
\endif
