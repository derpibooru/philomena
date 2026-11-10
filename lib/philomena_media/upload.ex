defmodule PhilomenaMedia.Upload do
  @moduledoc """
  An uploaded file.

  Contains two fields:
  * `:path` - the path to the uploaded file on the filesystem
  * `:filename` - the chosen filename for the file
  """

  @enforce_keys [:path, :filename]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          path: String.t(),
          filename: String.t()
        }

  @doc """
  Converts a `m:Plug.Upload` to a `m:PhilomenaMedia.Upload`.
  """
  @spec from_plug(Plug.Upload.t() | nil) :: t() | nil
  def from_plug(nil), do: nil

  def from_plug(%Plug.Upload{path: path, filename: filename}) do
    %__MODULE__{path: path, filename: filename}
  end

  @doc """
  Extracts the `m:Plug.Upload` parameter named `name` from `params`
  and wraps it in `m:PhilomenaMedia.Upload`. Returns `nil` if
  the parameter did not exist or was the wrong type.
  """
  @spec cast(params :: term(), name :: String.t()) :: t() | nil
  def cast(params, name) do
    case params do
      %{^name => %Plug.Upload{} = upload} ->
        from_plug(upload)

      _ ->
        nil
    end
  end
end
