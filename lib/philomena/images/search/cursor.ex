defmodule Philomena.Images.Search.Cursor do
  @moduledoc false

  import Ecto.Changeset

  @cursor_types %{
    updated_at: :epoch,
    first_seen_at: :epoch,
    faves: :integer,
    downvotes: :integer,
    upvotes: :integer,
    width: :integer,
    height: :integer,
    score: :integer,
    hides: :integer,
    comment_count: :integer,
    tag_count: :integer,
    pixels: :integer,
    size: :integer,
    aspect_ratio: :float,
    wilson_score: :float,
    duration: :float,
    _score: :float
  }

  def cast_cursor(changeset, sort_field, cursor_field) do
    with {:ok, cursor} <- fetch_change(changeset, cursor_field) do
      sf = get_field(changeset, sort_field)

      case parse_cursor(sf, cursor) do
        {:ok, cursor} ->
          put_change(changeset, cursor_field, cursor)

        :error ->
          add_error(changeset, cursor_field, "is invalid for the given sort field")
      end
    else
      _ ->
        changeset
    end
  end

  defp parse_cursor(:id, [id_value]) do
    with {:ok, id_value} <- parse_integer(id_value) do
      {:ok, [id_value]}
    end
  end

  defp parse_cursor({:field, field_name}, [field_value, id_value]) do
    with {:ok, field_type} <- Map.fetch(@cursor_types, field_name),
         {:ok, field_value} <- parse_sort_field_value(field_type, field_value),
         {:ok, id_value} <- parse_integer(id_value) do
      {:ok, [field_value, id_value]}
    end
  end

  defp parse_cursor({:random, _seed}, [offset_value, id_value]) do
    with {:ok, offset_value} <- parse_float(offset_value),
         {:ok, id_value} <- parse_integer(id_value) do
      {:ok, [offset_value, id_value]}
    end
  end

  defp parse_cursor({:gallery, _gallery_id}, [position_value, id_value]) do
    with {:ok, position_value} <- parse_integer(position_value),
         {:ok, id_value} <- parse_integer(id_value) do
      {:ok, [position_value, id_value]}
    end
  end

  defp parse_cursor(_type, _values),
    do: :error

  defp parse_sort_field_value(field_type, field_value) do
    case field_type do
      :epoch -> parse_epoch(field_value)
      :integer -> parse_integer(field_value)
      :float -> parse_float(field_value)
    end
  end

  defp parse_epoch(value),
    do: parse_integer(value)

  defp parse_integer(value) when is_binary(value) do
    with {value, ""} <- Integer.parse(value) do
      {:ok, value}
    else
      _ -> :error
    end
  end

  defp parse_integer(_value),
    do: :error

  defp parse_float(value) when is_binary(value) do
    with {value, ""} <- Float.parse(value) do
      {:ok, value}
    else
      _ -> :error
    end
  end

  defp parse_float(_value),
    do: :error
end
