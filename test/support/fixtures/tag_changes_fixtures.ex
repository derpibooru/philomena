defmodule Philomena.TagChangesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Philomena.TagChanges` context.
  """

  import Ecto.Query
  import Philomena.AttributionFixtures

  alias Philomena.Images
  alias Philomena.Repo
  alias Philomena.TagChanges.TagChange

  def tag_change_attributes(user) do
    attribution = actor(user)

    %{
      user_id: user.id,
      ip: attribution.ip,
      fingerprint: attribution.fingerprint
    }
  end

  def create_tag_change!(image, tag, user, added) do
    image_tag_names =
      image
      |> Repo.preload(:tags, force: true)
      |> Map.fetch!(:tags)
      |> Enum.map(& &1.name)

    old_tag_input = Enum.join(image_tag_names, ", ")

    new_tag_input =
      if added do
        Enum.join([tag.name | image_tag_names], ", ")
      else
        image_tag_names
        |> List.delete(tag.name)
        |> Enum.join(", ")
      end

    arrangement_actor = actor(%{user | bypass_rate_limits: true})

    {:ok, _result} =
      Images.update_image_tags(
        arrangement_actor,
        image.id,
        %{"old_tag_input" => old_tag_input, "tag_input" => new_tag_input}
      )

    Repo.one!(
      from tag_change in TagChange,
        where: tag_change.image_id == ^image.id,
        order_by: [desc: :id],
        limit: 1
    )
  end
end
