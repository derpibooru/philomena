defmodule Philomena.SiteNoticesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.SiteNotices` context.
  """

  alias Philomena.SiteNotices

  @doc """
  Creates a site notice, authored by a fresh admin. `start_date`/`finish_date`
  are RelativeDate fields - a plain `%DateTime{}` casts fine.
  """
  def site_notice_fixture(attrs \\ %{}) do
    {:ok, notice} =
      SiteNotices.create_site_notice(
        Philomena.AttributionFixtures.actor(Philomena.UsersFixtures.admin_user_fixture()),
        Enum.into(attrs, %{
          "title" => "Scheduled maintenance",
          "text" => "The site will be down.",
          "start_date" => DateTime.utc_now(:second),
          "finish_date" => DateTime.add(DateTime.utc_now(:second), 365, :day)
        })
      )

    notice
  end
end
