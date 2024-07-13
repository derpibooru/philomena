defmodule PhilomenaQuery.Ecto.QueryValidator do
  @moduledoc """
  Query string validation for Ecto.

  It enables the following usage pattern by taking a fn of the compiler:

      defmodule Filter do
        import PhilomenaQuery.Ecto.QueryValidator

        # ...

        def changeset(filter, attrs, user) do
          filter
          |> cast(attrs, [:complex])
          |> validate_required([:complex])
          |> validate_query([:complex], with: &Query.compile(&1, user: user))
        end
      end

  """

  import Ecto.Changeset
  alias PhilomenaQuery.Parse.String

  @doc """
  Validates a query string using the provided attribute(s) and compiler.

  Returns the changeset as-is, or with an `"is invalid"` error added to validated field.

  ## Examples

      # With single attribute
      filter
      |> cast(attrs, [:complex])
      |> validate_query(:complex, &Query.compile(&1, user: user))

      # With list of attributes
      filter
      |> cast(attrs, [:spoilered_complex, :hidden_complex])
      |> validate_query([:spoilered_complex, :hidden_complex], &Query.compile(&1, user: user))

  """
  def validate_query(changeset, attr_or_attr_list, callback)

  def validate_query(changeset, attr_list, callback) when is_list(attr_list) do
    Enum.reduce(attr_list, changeset, fn attr, changeset ->
      validate_query(changeset, attr, callback)
    end)
  end

  def validate_query(changeset, attr, callback) do
    if changed?(changeset, attr) do
      validate_assuming_changed(changeset, attr, callback)
    else
      changeset
    end
  end

  defp validate_assuming_changed(changeset, attr, callback) do
    with value when is_binary(value) <- fetch_change!(changeset, attr) || "",
         value <- String.normalize(value),
         {:ok, _} <- callback.(value) do
      changeset
    else
      _ ->
        add_error(changeset, attr, "is invalid")
    end
  end
end
