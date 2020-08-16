defmodule PhilomenaWeb.LimitPlug do
  @moduledoc """
  This plug automatically limits requests which are submitted faster
  than should be allowed for a given client.
  ## Example
      plug PhilomenaWeb.LimitPlug, [time: 30, error: "Too fast! Slow down."]
  """

  alias Plug.Conn
  alias Phoenix.Controller

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 1)
    time = Keyword.get(opts, :time, 5)
    error = Keyword.get(opts, :error)

    data = [
      current_user_id(conn.assigns.current_user),
      :inet_parse.ntoa(conn.remote_ip),
      conn.private.phoenix_action,
      conn.private.phoenix_controller
    ]

    key = "rl-#{Enum.join(data, "")}"

    [amt, _] =
      Redix.pipeline!(:redix, [
        ["INCR", key],
        ["EXPIRE", key, time]
      ])

    cond do
      amt <= limit ->
        conn

      true ->
        conn
        |> Controller.put_flash(:error, error)
        |> Controller.redirect(external: conn.assigns.referrer)
        |> Conn.halt()
    end
  end

  defp current_user_id(%{id: id}), do: id
  defp current_user_id(_), do: nil
end
