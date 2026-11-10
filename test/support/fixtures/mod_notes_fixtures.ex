defmodule Philomena.ModNotesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.ModNotes` context.
  """

  import Philomena.AttributionFixtures

  alias Philomena.ModNotes

  @doc """
  Creates a mod note authored by `author` (a `User.t()`) against a fresh
  `confirmed_user_fixture/0`.

  Notes are created through the context so `moderator_id` is set to the passed
  `author`; the edit/update/delete abilities are scoped to that id (a
  moderator may only touch their own notes, admins may touch any).
  """
  def mod_note_fixture(author, attrs \\ %{}) do
    target = Philomena.UsersFixtures.confirmed_user_fixture()

    mod_note_fixture_for(author, Enum.into(attrs, %{"user_id" => target.id}))
  end

  @doc """
  Creates a mod note authored by `author` (a `User.t()`) with the given `attrs`.

  Notes are created through the context so `moderator_id` is set to the passed
  `author`; the edit/update/delete abilities are scoped to that id (a
  moderator may only touch their own notes, admins may touch any).
  """
  def mod_note_fixture_for(author, attrs \\ %{}) do
    {:ok, note} =
      ModNotes.create_mod_note(
        actor(author),
        Enum.into(attrs, %{"body" => "Keeping an eye on this one"})
      )

    note
  end
end
