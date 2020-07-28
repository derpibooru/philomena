defmodule PhilomenaWeb.TorPlug do
  @moduledoc """
  This plug ensures that a Tor user is authenticated.

  ## Example

      plug PhilomenaWeb.TorPlug
  """
  alias PhilomenaWeb.Router.Helpers, as: Routes
  alias Phoenix.Controller
  alias Plug.Conn

  @doc false
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc false
  @spec call(Conn.t(), any()) :: Conn.t()
  def call(conn, _opts) do
    onion? = onion?(conn.host)
    user = conn.assigns.current_user
    ip = conn.remote_ip

    maybe_redirect(conn, user, ip, onion?)
  end

  def maybe_redirect(conn, nil, {127, 0, 0, 1}, true) do
    conn
    |> Controller.redirect(to: Routes.session_path(conn, :new))
    |> Conn.halt()
  end

  def maybe_redirect(conn, _user, _ip, _onion?), do: conn

  # This is allowed, because nginx won't forward the request
  # to the appserver if the hostname isn't in a specific list
  # of allowed hostnames.
  def onion?(host), do: String.ends_with?(host, ".onion")
end
