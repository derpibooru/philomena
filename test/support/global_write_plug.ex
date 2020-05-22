defmodule PhilomenaWeb.GlobalWritePlug do
  def init(opts), do: opts

  def call(conn, key_name) do
    put_key(key_name)

    conn
  end

  defp put_key(key_name) do
    Application.put_env(:philomena, key_name, true)
  end
end
