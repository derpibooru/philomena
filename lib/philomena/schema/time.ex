defmodule Philomena.Schema.Time do
  alias PhilomenaQuery.RelativeDate
  import Ecto.Changeset

  def assign_time(changeset, field, target_field) do
    changeset
    |> get_field(field)
    |> RelativeDate.parse()
    |> case do
      {:ok, time} ->
        put_change(changeset, target_field, time)

      _err ->
        add_error(changeset, field, "is not a valid relative or absolute date and time")
    end
  end

  def propagate_time(changeset, field, target_field) do
    time = get_field(changeset, field)

    put_change(changeset, target_field, to_string(time))
  end
end
