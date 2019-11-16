defmodule PhilomenaWeb.Plugs.Referrer do
  @moduledoc """
  This plug assigns the HTTP Referer, if it exists. Note the misspelling
  in the standard.

  ## Example

      plug PhilomenaWeb.Plugs.Referrer
  """

  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    case Conn.get_req_header(conn, "referer") do
      [] ->
        conn
        |> Conn.assign(:referrer, "/")

      [referrer] ->
        conn
        |> Conn.assign(:referrer, referrer)
    end
  end
end