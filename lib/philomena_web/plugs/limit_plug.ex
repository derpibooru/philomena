defmodule PhilomenaWeb.LimitPlug do
  @moduledoc """
  This plug automatically limits requests which are submitted faster
  than should be allowed for a given client.

  ## Example

      plug PhilomenaWeb.LimitPlug, [time: 30, error: "Too fast! Slow down."]
  """

  alias Plug.Conn
  alias Phoenix.Controller
  alias Philomena.Users.User

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, opts) do
    limit = Keyword.get(opts, :limit, 1)
    time = Keyword.get(opts, :time, 5)
    error = Keyword.get(opts, :error)
    skip_staff = Keyword.get(opts, :skip_staff, true)

    data = [
      current_user_id(conn.assigns.current_user),
      :inet_parse.ntoa(conn.remote_ip),
      conn.private.phoenix_action,
      conn.private.phoenix_controller
    ]

    key = "rl-#{Enum.join(data, "")}"
    amt = Redix.command!(:redix, ["GET", key]) || 0

    conn = increment_after_post(conn, key, time)

    cond do
      amt <= limit ->
        conn

      is_staff(conn.assigns.current_user) and skip_staff ->
        conn

      conn.assigns.current_user.bypass_rate_limits ->
        conn

      conn.assigns.ajax? ->
        conn
        |> Controller.put_flash(:error, error)
        |> Conn.send_resp(:multiple_choices, "")
        |> Conn.halt()

      api?(conn) ->
        conn
        |> Conn.put_status(:too_many_requests)
        |> Controller.text("")
        |> Conn.halt()

      true ->
        conn
        |> Controller.put_flash(:error, error)
        |> Controller.redirect(external: conn.assigns.referrer)
        |> Conn.halt()
    end
  end

  defp is_staff(%User{role: "admin"}), do: true
  defp is_staff(%User{role: "moderator"}), do: true
  defp is_staff(%User{role: "assistant"}), do: true
  defp is_staff(_), do: false

  defp current_user_id(%{id: id}), do: id
  defp current_user_id(_), do: nil

  defp api?(conn) do
    case conn.path_info do
      ["api" | _] -> true
      _ -> false
    end
  end

  defp increment_after_post(conn, key, time) do
    Conn.register_before_send(conn, fn conn ->
      # Phoenix status returns 200 for form validation errors
      if conn.status != 200 do
        Redix.pipeline!(:redix, [
          ["INCR", key],
          ["EXPIRE", key, time]
        ])
      end

      conn
    end)
  end
end
