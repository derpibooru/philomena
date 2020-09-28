defmodule PhilomenaWeb.ReferrerPlug do
  @moduledoc """
  This plug assigns the HTTP Referer, if it exists. Note the misspelling
  in the standard.

  ## Example

      plug PhilomenaWeb.ReferrerPlug
  """

  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn
    |> Conn.assign(:referrer, referer(conn))
    |> Conn.assign(:ajax?, ajax?(conn))
  end

  defp referer(conn) do
    case Conn.get_req_header(conn, "referer") do
      [] -> "/"
      [referrer] -> referrer
    end
  end

  defp ajax?(conn) do
    case Conn.get_req_header(conn, "x-requested-with") do
      [value] -> String.downcase(value) == "xmlhttprequest"
      _ -> false
    end
  end
end
