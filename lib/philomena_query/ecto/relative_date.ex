defmodule PhilomenaQuery.Ecto.RelativeDate do
  @moduledoc """
  Ecto custom type for relative dates.

  As a field type, it enables the following usage pattern:

      defmodule Notice do
        use Ecto.Schema
        import Ecto.Changeset

        schema "notices" do
          field :start_date, PhilomenaQuery.Ecto.RelativeDate
          field :finish_date, PhilomenaQuery.Ecto.RelativeDate
        end

        @doc false
        def changeset(notice, attrs) do
          notice
          |> cast(attrs, [:start_date, :finish_date])
          |> validate_required([:start_date, :finish_date])
        end
      end

  """

  use Ecto.Type
  alias PhilomenaQuery.RelativeDate

  @doc false
  def type do
    :utc_datetime
  end

  @doc false
  def cast(input)

  def cast(input) when is_binary(input) do
    case RelativeDate.parse(input) do
      {:ok, result} ->
        {:ok, result}

      _ ->
        {:error, [message: "is not a valid relative or absolute date and time"]}
    end
  end

  def cast(%DateTime{} = input) do
    {:ok, input}
  end

  @doc false
  def load(datetime) do
    datetime =
      datetime
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.truncate(:second)

    {:ok, datetime}
  end

  @doc false
  def dump(datetime) do
    {:ok, datetime}
  end
end
