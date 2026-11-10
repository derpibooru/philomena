defmodule Philomena.ModNotes.Target do
  @moduledoc """
  Staff note target helper type, parser, and utilities.
  """
  alias Philomena.IntegerId
  alias Philomena.Loader
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Reports.Report
  alias Philomena.Users.User

  @target_definitions [
    user: {User, :user_id},
    report: {Report, :report_id},
    dnp_entry: {DnpEntry, :dnp_entry_id}
  ]

  @enforce_keys [:type, :value, :schema, :column]
  defstruct [:type, :value, :schema, :column]

  @typedoc "A supported note target type and database ID."
  @type t :: %__MODULE__{
          type: :user | :report | :dnp_entry,
          value: IntegerId.integer_id(),
          schema: User | Report | DnpEntry,
          column: :user_id | :report_id | :dnp_entry_id
        }

  defp get_param(params, key) do
    Map.get(params, to_string(key)) || Map.get(params, key)
  end

  defp target_params(params) do
    @target_definitions
    |> Enum.map(fn {type, {_schema, column}} -> {type, get_param(params, column)} end)
    |> Enum.reject(fn {_type, value} -> value in [nil, ""] end)
  end

  defp parse_targets(params) do
    parsed =
      params
      |> target_params()
      |> Enum.map(fn {type, value} -> from_type_and_id(type, value) end)
      |> Enum.map(fn
        {:ok, target} -> target
        {:error, _} -> :error
      end)

    if :error in parsed do
      {:error, :not_found}
    else
      {:ok, parsed}
    end
  end

  @doc """
  Generates a target from the combination of type and ID.

  Returns `{:error, :not_found}` if the input does not specify a target.
  """
  @spec from_type_and_id(atom(), IntegerId.integer_id()) :: {:ok, t()} | {:error, :not_found}
  def from_type_and_id(type, id) do
    with {:ok, {schema, column}} <- Keyword.fetch(@target_definitions, type),
         {:ok, id} <- Loader.parse_id(id) do
      {:ok, %__MODULE__{type: type, value: id, schema: schema, column: column}}
    else
      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Retrieves a single target from params.

  Returns `{:error, :not_found}` if no targets or multiple targets are found.
  """
  @spec from_params(map()) :: {:ok, t()} | {:error, :not_found}
  def from_params(params) do
    case parse_targets(params) do
      {:ok, [%__MODULE__{} = target]} ->
        {:ok, target}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Returns a user-facing label for the given target.
  """
  @spec label(t()) :: String.t()
  def label(%__MODULE__{} = target) do
    target.type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> then(&"#{&1} #{target.value}")
  end

  @doc """
  Converts a target to a keyword of changes suitable for passing as the second
  argument to `Ecto.Changeset.change/2`.
  """
  @spec to_changes(t()) :: Keyword.t()
  def to_changes(%__MODULE__{} = target) do
    [{target.column, target.value}]
  end
end
