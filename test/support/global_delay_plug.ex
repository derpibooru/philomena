defmodule PhilomenaWeb.GlobalDelayPlug do
  def init(opts), do: opts

  def call(conn, key_name) do
    wait_for_key(key_name)

    conn
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
