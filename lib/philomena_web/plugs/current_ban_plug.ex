defmodule PhilomenaWeb.CurrentBanPlug do
  @moduledoc """
  This plug loads the ban for the current user.

  ## Example

      plug PhilomenaWeb.CurrentBanPlug
  """
  alias Philomena.Bans
  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    conn = Conn.fetch_cookies(conn)

    fingerprint = conn.cookies["_ses"]
    user = conn.assigns.current_user
    ip = conn.remote_ip

    ban = Bans.exists_for?(user, ip, fingerprint)

    cond do
      discourage?(ban) ->
        Conn.register_before_send(conn, fn conn ->
          :timer.sleep(normal_time())

          pass(error?(), conn)
        end)
        |> Conn.assign(:current_ban, nil)

      true ->
        Conn.assign(conn, :current_ban, ban)
    end
  end

  defp discourage?(%{note: note}) when is_binary(note), do: String.contains?(note, "discourage")
  defp discourage?(_ban), do: false

  defp normal_time, do: :rand.normal(5_000, 25_000_000) |> trunc() |> max(0)
  defp error?, do: :rand.uniform() < 0.05

  defp pass(false, conn), do: conn
  defp pass(_true, _conn), do: nil
end
