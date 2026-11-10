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
          |> validate_query(:complex, with: &Query.compile(&1, user: user))
        end
      end

  """

  import Ecto.Changeset
  alias PhilomenaQuery.Parse.String

  @doc """
  Validates a query string using the provided attribute and compiler.

  Returns the changeset as-is, or with an `"is invalid"` error added to the validated field.

  ## Examples

      # Simple validation
      filter
      |> cast(attrs, [:complex])
      |> validate_query(:complex, with: &Query.compile(&1, user: user))

      # Persisting the compiled query
      query_form
      |> cast(attrs, [:query])
      |> validate_query(:query, with: &Query.compile/1, into: :compiled_query)

  """
  @spec validate_query(Ecto.Changeset.t(), atom(), Keyword.t()) :: Ecto.Changeset.t()
  def validate_query(changeset, attr, opts) do
    callback = Keyword.fetch!(opts, :with)
    default = Keyword.get(opts, :default, "")
    into = Keyword.get(opts, :into)

    if changed?(changeset, attr) or not is_nil(into) do
      validate_assuming_changed(changeset, attr, callback, default, into)
    else
      changeset
    end
  end

  defp validate_assuming_changed(changeset, attr, callback, default, into) do
    with value when is_binary(value) <- fetch_field!(changeset, attr) || default,
         value <- String.normalize(value),
         {:ok, compiled} <- callback.(value) do
      maybe_persist_compilation(changeset, compiled, into)
    else
      {:error, msg} ->
        add_error(changeset, attr, "is invalid: #{msg}")

      _ ->
        add_error(changeset, attr, "is invalid")
    end
  end

  defp maybe_persist_compilation(changeset, _result, nil), do: changeset

  defp maybe_persist_compilation(changeset, result, field),
    do: put_change(changeset, field, result)
end
