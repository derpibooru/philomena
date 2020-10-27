defmodule Philomena.Images.TagValidator do
  alias Philomena.Config
  import Ecto.Changeset

  def validate_tags(changeset) do
    tags = changeset |> get_field(:tags)

    validate_tag_input(changeset, tags)
  end

  defp validate_tag_input(changeset, tags) do
    tag_set = extract_names(tags)
    rating_set = ratings(tag_set)

    changeset
    |> validate_number_of_tags(tag_set, 3)
    |> validate_bad_words(tag_set)
    |> validate_has_rating(rating_set)
    |> validate_safe(rating_set)
    |> validate_sexual_exclusion(rating_set)
    |> validate_horror_exclusion(rating_set)
  end

  defp ratings(tag_set) do
    safe = MapSet.intersection(tag_set, safe_rating())
    sexual = MapSet.intersection(tag_set, sexual_ratings())
    horror = MapSet.intersection(tag_set, horror_ratings())
    gross = MapSet.intersection(tag_set, gross_rating())

    %{
      safe: safe,
      sexual: sexual,
      horror: horror,
      gross: gross
    }
  end

  defp validate_number_of_tags(changeset, tag_set, num) do
    cond do
      MapSet.size(tag_set) < num ->
        add_error(changeset, :tag_input, "must contain at least #{num} tags")

      true ->
        changeset
    end
  end

  def validate_bad_words(changeset, tag_set) do
    bad_words = MapSet.new(Config.get(:tag)["blacklist"])
    intersection = MapSet.intersection(tag_set, bad_words)

    cond do
      MapSet.size(intersection) > 0 ->
        Enum.reduce(
          intersection,
          changeset,
          &add_error(&2, :tag_input, "contains forbidden tag `#{&1}'")
        )

      true ->
        changeset
    end
  end

  defp validate_has_rating(changeset, %{safe: s, sexual: x, horror: h, gross: g}) do
    cond do
      MapSet.size(s) > 0 or MapSet.size(x) > 0 or MapSet.size(h) > 0 or MapSet.size(g) > 0 ->
        changeset

      true ->
        add_error(changeset, :tag_input, "must contain at least one rating tag")
    end
  end

  defp validate_safe(changeset, %{safe: s, sexual: x, horror: h, gross: g}) do
    cond do
      MapSet.size(s) > 0 and (MapSet.size(x) > 0 or MapSet.size(h) > 0 or MapSet.size(g) > 0) ->
        add_error(changeset, :tag_input, "may not contain any other rating if safe")

      true ->
        changeset
    end
  end

  defp validate_sexual_exclusion(changeset, %{sexual: x}) do
    cond do
      MapSet.size(x) > 1 ->
        add_error(changeset, :tag_input, "may contain at most one sexual rating")

      true ->
        changeset
    end
  end

  defp validate_horror_exclusion(changeset, %{horror: h}) do
    cond do
      MapSet.size(h) > 1 ->
        add_error(changeset, :tag_input, "may contain at most one grim rating")

      true ->
        changeset
    end
  end

  defp extract_names(tags) do
    tags
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp safe_rating, do: MapSet.new(["safe"])
  defp sexual_ratings, do: MapSet.new(["suggestive", "questionable", "explicit"])
  defp horror_ratings, do: MapSet.new(["semi-grimdark", "grimdark"])
  defp gross_rating, do: MapSet.new(["grotesque"])
end
