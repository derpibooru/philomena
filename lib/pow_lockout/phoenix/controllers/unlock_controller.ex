defmodule PowLockout.Phoenix.UnlockController do
  @moduledoc false
  use Pow.Extension.Phoenix.Controller.Base

  alias Plug.Conn
  alias PowLockout.Plug

  @spec process_show(Conn.t(), map()) :: {:ok | :error, map(), Conn.t()}
  def process_show(conn, %{"id" => token}), do: Plug.unlock_account(conn, token)

  @spec respond_show({:ok | :error, map(), Conn.t()}) :: Conn.t()
  def respond_show({:ok, _user, conn}) do
    conn
    |> put_flash(:info, extension_messages(conn).account_has_been_unlocked(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end

  def respond_show({:error, _changeset, conn}) do
    conn
    |> put_flash(:error, extension_messages(conn).account_unlock_failed(conn))
    |> redirect(to: routes(conn).session_path(conn, :new))
  end
end
