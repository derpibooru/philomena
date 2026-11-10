defmodule Philomena.StaticPagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  static page and initial-version rows for tests.
  """

  alias Philomena.Multi
  alias Philomena.StaticPages.StaticPage
  alias Philomena.StaticPages.Version

  def unique_static_page_slug, do: "test-page-#{System.unique_integer([:positive])}"

  @doc """
  Creates a static page (with its initial version, attributed to `user`).

  The direct persistence is deliberate fixture infrastructure. Production
  callers use the actor-scoped `Philomena.StaticPages.create_page/2` workflow.
  """
  def static_page_fixture(user, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        title: "Test Page ##{unique}",
        slug: unique_static_page_slug(),
        body: "Test page body"
      })

    {:ok, %{static_page: static_page}} =
      Multi.new()
      |> Multi.insert(:static_page, StaticPage.changeset(%StaticPage{}, attrs))
      |> Multi.insert(:version, fn %{static_page: static_page} ->
        %Version{static_page_id: static_page.id, user_id: user.id}
        |> Version.changeset(attrs)
      end)
      |> Multi.transact()

    static_page
  end
end
