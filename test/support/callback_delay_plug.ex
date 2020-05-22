defmodule PhilomenaWeb.CallbackDelayPlug do
  def init(opts), do: opts

  def call(conn, key_name) do
    Plug.Conn.register_before_send(conn, fn conn ->
      IO.puts "waiting for key #{key_name}"
      wait_for_key(key_name)

      conn
    end)
  end

  defp wait_for_key(key_name) do
    case Application.get_env(:philomena, key_name) do
      nil ->
        wait_for_key(key_name)

      _ ->
        true
    end
  end
end
