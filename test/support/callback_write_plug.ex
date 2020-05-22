defmodule PhilomenaWeb.CallbackWritePlug do
  def init(opts), do: opts

  def call(conn, key_name) do
    Plug.Conn.register_before_send(conn, fn conn ->
      IO.puts "writing key #{key_name}"
      put_key(key_name)

      conn
    end)
  end

  defp put_key(key_name) do
    IO.puts "writing #{key_name}"
    Application.put_env(:philomena, key_name, true)
  end
end
