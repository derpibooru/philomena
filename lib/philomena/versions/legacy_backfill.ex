defmodule Philomena.Versions.LegacyBackfill do
  @moduledoc """
  One-time conversion of the legacy paper_trail `versions_legacy` table into
  the normalized `post_versions` and `comment_versions` tables.

  Legacy rows store the state of the item *before* the edit they record; the
  normalized tables store after-edit snapshots. Each legacy row therefore
  takes the next-newer row's pre-edit state (the newest row takes the live
  item's current state), and the pre-first-edit state becomes a synthetic
  initial row stamped with the item's author and creation time. Initial rows
  are inserted before edit rows so that ids break same-second `created_at`
  ties in chain order. Rows whose item no longer exists, and item types other
  than Post and Comment, are left behind in `versions_legacy`.

  In production this must run after the schema migration and before the new
  application code begins serving edits, via
  `Philomena.Release.backfill_versions/0`.

  This remains supported while deployed installations may still have the
  `versions_legacy` table and `Philomena.Release.backfill_versions/0` remains a
  release entry point. Remove it only in a dedicated schema-cleanup change after
  that compatibility window is explicitly closed and deployed backfills have
  been verified.
  """

  alias Philomena.Repo

  @targets [
    {"post_versions", "posts", "post_id", "Post"},
    {"comment_versions", "comments", "comment_id", "Comment"}
  ]

  @doc """
  Runs the backfill, one statement per transaction.

  Raises if any target table already contains rows; truncate
  `post_versions` and `comment_versions` to re-run.
  """
  # sobelow_skip ["SQL.Query"]
  def run! do
    ensure_empty!()

    for sql <- statements() do
      Repo.query!(sql, [], timeout: :infinity)
    end

    :ok
  end

  @doc """
  The conversion statements, in execution order. Also used by the schema
  migration to run the conversion inline outside production.
  """
  def statements do
    Enum.flat_map(@targets, fn target ->
      [initial_rows(target), shifted_edit_rows(target)]
    end)
  end

  # The oldest legacy row of an item captured the pre-first-edit state, which
  # has no home under after-edit semantics; synthesize an initial row for it.
  # A Rails-era 'create' event row (object IS NULL) already becomes the
  # initial row via the shift in shifted_edit_rows/1, so it is skipped here.
  defp initial_rows({table, parent, fk, item_type}) do
    """
    INSERT INTO #{table} (#{fk}, user_id, body, edit_reason, created_at)
    SELECT s.item_id, p.user_id, COALESCE(s.object::jsonb->>'body', ''), NULL, p.created_at
    FROM (
      SELECT DISTINCT ON (item_id) item_id, object
      FROM versions_legacy
      WHERE item_type = '#{item_type}'
      ORDER BY item_id, created_at, id
    ) s
    JOIN #{parent} p ON p.id = s.item_id
    WHERE s.object IS NOT NULL
    """
  end

  # Each legacy row records the state before its edit, so the state after its
  # edit is the next-newer row's pre-state; the newest row of an item takes
  # the live item's current state. LEAD(v.id) distinguishes "no next row"
  # from "next row has a null body". The trailing ORDER BY makes serial ids
  # follow chain order within each item.
  defp shifted_edit_rows({table, parent, fk, item_type}) do
    """
    INSERT INTO #{table} (#{fk}, user_id, body, edit_reason, created_at)
    SELECT v.item_id,
           u.id,
           CASE WHEN LEAD(v.id) OVER w IS NULL THEN COALESCE(p.body, '')
                ELSE COALESCE(LEAD(v.object::jsonb->>'body') OVER w, '') END,
           CASE WHEN LEAD(v.id) OVER w IS NULL THEN p.edit_reason
                ELSE LEAD(v.object::jsonb->>'edit_reason') OVER w END,
           v.created_at
    FROM versions_legacy v
    JOIN #{parent} p ON p.id = v.item_id
    LEFT JOIN users u
      ON u.id = (CASE WHEN v.whodunnit ~ '^[0-9]+$' THEN v.whodunnit::bigint END)
    WHERE v.item_type = '#{item_type}'
    WINDOW w AS (PARTITION BY v.item_id ORDER BY v.created_at, v.id)
    ORDER BY v.item_id, v.created_at, v.id
    """
  end

  # sobelow_skip ["SQL.Query"]
  defp ensure_empty! do
    for {table, _parent, _fk, _item_type} <- @targets do
      %{rows: [[count]]} = Repo.query!("SELECT COUNT(*) FROM #{table}")

      if count > 0 do
        raise "#{table} already contains #{count} rows; truncate it to re-run the backfill"
      end
    end
  end
end
