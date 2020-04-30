defmodule Philomena.Images.TagValidator do
  alias Philomena.Servers.Config
  import Ecto.Changeset

  @safe_rating MapSet.new(["safe"])
  @sexual_ratings MapSet.new(["suggestive", "questionable", "explicit"])
  @horror_ratings MapSet.new(["semi-grimdark", "grimdark"])
  @gross_rating MapSet.new(["grotesque"])
  @empty MapSet.new()

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

  defp ratings(%MapSet{} = tag_set) do
    safe = MapSet.intersection(tag_set, @safe_rating)
    sexual = MapSet.intersection(tag_set, @sexual_ratings)
    horror = MapSet.intersection(tag_set, @horror_ratings)
    gross = MapSet.intersection(tag_set, @gross_rating)

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
        changeset
        |> add_error(:tag_input, "must contain at least #{num} tags")

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

  defp validate_has_rating(changeset, %{safe: s, sexual: x, horror: h, gross: g})
       when s == @empty and x == @empty and h == @empty and g == @empty do
    changeset
    |> add_error(:tag_input, "must contain at least one rating tag")
  end

  defp validate_has_rating(changeset, _ratings), do: changeset

  defp validate_safe(changeset, %{safe: s, sexual: x, horror: h, gross: g})
       when s != @empty and (x != @empty or h != @empty or g != @empty) do
    changeset
    |> add_error(:tag_input, "may not contain any other rating if safe")
  end

  defp validate_safe(changeset, _ratings), do: changeset

  defp validate_sexual_exclusion(changeset, %{sexual: x}) do
    cond do
      MapSet.size(x) > 1 ->
        changeset
        |> add_error(:tag_input, "may contain at most one sexual rating")

      true ->
        changeset
    end
  end

  defp validate_horror_exclusion(changeset, %{horror: h}) do
    cond do
      MapSet.size(h) > 1 ->
        changeset
        |> add_error(:tag_input, "may contain at most one grim rating")

      true ->
        changeset
    end
  end

  defp extract_names(tags) do
    tags
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end
end
