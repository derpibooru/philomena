defmodule PowLockout.Phoenix.ControllerCallbacks do
  @moduledoc """
  Controller callback logic for account lockout.

  ### User is locked out

  Triggers on `Pow.Phoenix.SessionController.create/2`.

  When a user is locked out, the credentials will be treated as if they were
  invalid and the user will be redirected back to `Pow.Phoenix.Routes.`.

  ### User successfully authenticates

  Triggers on `Pow.Phoenix.SessionController.create/2`.

  When a user successfully signs in, the failed attempts counter will be
  reset to zero.

  ### Users unsuccessfully authenticates

  Triggers on `Pow.Phoenix.SessionController.create/2`.

  When a user unsuccessfully signs in, the failed attempts counter will be
  incremented, and the user may be locked out.

  See `PowLockout.Ecto.Schema` for more.
  """
  use Pow.Extension.Phoenix.ControllerCallbacks.Base

  alias Plug.Conn
  alias Pow.Plug
  alias Phoenix.Controller
  alias PowLockout.Phoenix.{UnlockController, Mailer}
  alias PowLockout.Plug, as: PowLockoutPlug

  @doc false
  @impl true
  def before_respond(Pow.Phoenix.SessionController, :create, {result, conn}, _config) do
    PowLockoutPlug.user_for_attempts(conn)
    |> maybe_fail_attempt(conn, result)
  end

  defp maybe_fail_attempt(nil, conn, result),
    do: {result, conn}

  defp maybe_fail_attempt(%{locked_at: nil} = user, conn, :ok) do
    case PowLockoutPlug.succeed_attempt(conn, user) do
      {:error, _changeset, conn} ->
        {:halt, conn}

      {:ok, _user, conn} ->
        {:ok, conn}
    end
  end

  defp maybe_fail_attempt(_locked_user, conn, :ok) do
    {:error, invalid_credentials(conn)}
  end

  defp maybe_fail_attempt(user, conn, _error) do
    PowLockoutPlug.fail_attempt(conn, user)
    |> case do
      {:error, _changeset, conn} ->
        {:halt, conn}

      {:ok, %{locked_at: nil}, conn} ->
        {:error, invalid_credentials(conn)}

      {:ok, user, conn} ->
        send_unlock_email(user, conn)

        {:error, invalid_credentials(conn)}
    end
  end

  defp invalid_credentials(conn) do
    {:ok, conn} =
      Plug.clear_authenticated_user(conn)

    conn
    |> Conn.assign(:changeset, Plug.change_user(conn, conn.params["user"]))
    |> Controller.put_flash(:error, messages(conn).invalid_credentials(conn))
    |> Controller.render("new.html")
  end

  @doc """
  Sends an unlock e-mail to the user.
  """
  @spec send_unlock_email(map(), Conn.t()) :: any()
  def send_unlock_email(user, conn) do
    url   = unlock_url(conn, user.unlock_token)
    email = Mailer.email_unlock(conn, user, url)

    Pow.Phoenix.Mailer.deliver(conn, email)
  end

  defp unlock_url(conn, token) do
    routes(conn).url_for(conn, UnlockController, :show, [token])
  end
end
