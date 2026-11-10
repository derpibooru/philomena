defmodule Philomena.Release do
  @app :philomena

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    start_app()
    Code.require_file("priv/repo/seeds.exs")
  end

  def migrate_search do
    start_app()
    Philomena.SearchMigrator.migrate_all()
  end

  def search_status do
    start_app()
    status = Philomena.SearchMigrator.status()

    for row <- status do
      IO.puts(
        "#{row.alias}: live=#{row.live_physical || "(none)"} " <>
          "v#{row.live_version || "?"} desired=v#{row.desired_version} " <>
          "action=#{inspect(row.action)} orphans=#{inspect(row.orphans)}"
      )
    end

    status
  end

  def create_buckets do
    start_app()
    PhilomenaMedia.Objects.create_buckets()
  end

  def update_channels do
    start_app()
    Philomena.Channels.update_tracked_channels!()
  end

  def verify_artist_links do
    start_app()
    Philomena.ArtistLinks.run_automatic_verification!()
  end

  def update_stats do
    start_app()
    PhilomenaWeb.StatsUpdater.update_stats!()
  end

  def clean_moderation_logs do
    start_app()
    Philomena.ModerationLogs.cleanup!()
  end

  def generate_autocomplete do
    start_app()
    Philomena.Autocomplete.generate_autocomplete!()
  end

  def clean_tags do
    start_app()
    Philomena.Tags.cleanup!()
  end

  def replace_aliases_in_implied_tags do
    start_app()
    Philomena.Tags.replace_aliases_in_implied_tags!()
  end

  def convert_reports do
    start_app()
    Philomena.Reports.LegacyConverter.convert_reports!()
  end

  def backfill_versions do
    start_app()
    Philomena.Versions.LegacyBackfill.run!()
  end

  def backfill_user_settings do
    start_app()
    Philomena.Users.SettingsBackfill.run!()
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  defp start_app do
    Application.ensure_all_started(@app)
  end
end
