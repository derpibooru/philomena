#!/bin/sh
# Shared by the steps of this release. Sourced, not executed.

rename_script=/srv/philomena/priv/repo/scripts/rename_case_variant_users.sql

sql() {
  psql -X -q -v ON_ERROR_STOP=1 -tA "$@"
}

# The unique index on commissions.user_id cannot be created while a user has
# more than one commission.
check_duplicate_commissions() {
  duplicate_commissions=$(sql -F '|' -c "SELECT user_id, string_agg(id::text, ',' ORDER BY id)
    FROM commissions GROUP BY user_id HAVING count(*) > 1 ORDER BY user_id")

  if [ -n "$duplicate_commissions" ]; then
    echo "Each user may have only one commission from this release on."
    echo "These users have more than one:"
    echo "user id|commission ids"
    echo "$duplicate_commissions"
    echo "Delete all but one commission of each user, then try again."
    exit 1
  fi
}

# The unique index on lower(users.name) is what cannot be created while
# usernames that differ only by letter case exist.
name_index_exists() {
  [ "$(sql -c "SELECT to_regclass('public.index_users_on_lower_name') IS NOT NULL")" = t ]
}

colliding_name_groups() {
  sql -c "SELECT count(*) FROM (SELECT 1 FROM users GROUP BY lower(name) HAVING count(*) > 1) g"
}

# Runs the rename script without committing, and prints a summary of what it
# would do. Sets $unresolved to the number of groups it cannot decide.
rename_dry_run() {
  report=$(psql -X -q -v ON_ERROR_STOP=1 -At -F '|' -f "$rename_script")
  summary=$(printf '%s\n' "$report" | awk '/^== Summary ==$/ { getline; print; exit }')

  groups=$(echo "$summary" | cut -d'|' -f1)
  empty=$(echo "$summary" | cut -d'|' -f3)
  active=$(echo "$summary" | cut -d'|' -f4)
  unresolved=$(echo "$summary" | cut -d'|' -f5)

  echo "Usernames must be unique regardless of letter case from this release on."
  echo "$groups groups of accounts have names that differ only by letter case."
  echo "One account in each group keeps its name. The others would be renamed to"
  echo "\"<name>_<4 digits>\": $empty accounts without any activity, and $active with activity."

  if [ "$unresolved" != 0 ]; then
    echo
    echo "$unresolved groups cannot be decided automatically:"
    echo "name group|reason|id|name|registered|deactivated|last active|activity"
    printf '%s\n' "$report" | awk '
      /^== Groups left untouched/ { printing = 1; next }
      /^== / { printing = 0 }
      printing && NF
    '
  fi
}

explain_full_report() {
  echo
  echo "For the full list of renames, run this against the database:"
  echo "  psql -f $rename_script"
  echo "It changes nothing unless it is given -v apply=1."
}
