defmodule Philomena.Images.Search.SortField do
  @moduledoc false

  use Ecto.Type

  @sort_fields ~W(
    updated_at
    first_seen_at
    aspect_ratio
    faves
    downvotes
    upvotes
    width
    height
    score
    comment_count
    tag_count
    wilson_score
    pixels
    size
    duration
    hides
    _score
  )a

  @sort_fields Map.new(@sort_fields, &{Atom.to_string(&1), &1})

  def type do
    :string
  end

  def cast("id") do
    {:ok, :id}
  end

  def cast("random") do
    {:ok, {:random, :rand.uniform(4_294_967_296)}}
  end

  def cast(<<"random:", seed::binary>>) do
    case Integer.parse(seed) do
      {seed, ""} ->
        {:ok, {:random, seed}}

      _ ->
        {:error, message: "has an invalid random seed"}
    end
  end

  def cast(<<"gallery_id:", gallery_id::binary>>) do
    case Integer.parse(gallery_id) do
      {gallery_id, ""} ->
        {:ok, {:gallery, gallery_id}}

      _ ->
        {:error, message: "has an invalid gallery ID"}
    end
  end

  def cast(value) do
    case Map.fetch(@sort_fields, value) do
      {:ok, field_name} ->
        {:ok, {:field, field_name}}

      _ ->
        {:error, message: "is invalid"}
    end
  end

  def load(value) do
    cast(value)
  end

  def dump(value) do
    case value do
      :id -> {:ok, "id"}
      {:field, field_name} -> {:ok, Atom.to_string(field_name)}
      {:random, random_seed} -> {:ok, "random:#{random_seed}"}
      {:gallery, gallery_id} -> {:ok, "gallery_id:#{gallery_id}"}
    end
  end
end
