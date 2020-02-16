defmodule PhilomenaWeb.PowInvalidatedSessionPlug do
  @moduledoc """
  This plug ensures that invalidated sessions can still be used for a short
  amount of time.

  This MAY introduce a slight timing attack vector, but in practice would be
  unlikely as all tokens expires after 60 seconds.

  ## Example

      plug MyAppWeb.PowInvalidatedSessionPlug, :pow_session
      plug MyAppWeb.PowInvalidatedSessionPlug, :pow_persistent_session
      plug Pow.Plug.Session, otp_app: :my_app
      plug PowPersistentSession.Plug.Cookie
      plug MyAppWeb.PowInvalidatedSessionPlug, :load

  """
  alias Plug.Conn
  alias Pow.{Config, Plug, Store.Backend.EtsCache}

  @store_ttl :timer.minutes(1)
  @otp_app :philomena
  @session_key "#{@otp_app}_auth"
  @persistent_cookie_key "#{@otp_app}_persistent_session"

  def init(:load), do: :load
  def init(:pow_session) do
    [
      fetch_token: &__MODULE__.load_session_value/1,
      namespace: :session
    ]
  end
  def init(:pow_persistent_session) do
    [
      fetch_token: &__MODULE__.load_cookie_value/1,
      namespace: :persistent_session
    ]
  end
  def init({type, opts}) do
    type
    |> init()
    |> Keyword.merge(opts)
  end

  def call(conn, :load) do
    Enum.reduce(conn.private[:invalidated_session_opts], conn, fn opts, conn ->
      maybe_load_from_cache(conn, Plug.current_user(conn), opts)
    end)
  end
  def call(conn, opts) do
    fetch_fn = Keyword.fetch!(opts, :fetch_token)
    token    = fetch_fn.(conn)

    conn
    |> put_opts_in_private(opts)
    |> Conn.register_before_send(fn conn ->
      maybe_put_cache(conn, Plug.current_user(conn), token, opts)
    end)
  end

  defp maybe_load_from_cache(conn, nil, opts) do
    fetch_fn = Keyword.fetch!(opts, :fetch_token)

    case fetch_fn.(conn) do
      nil   -> conn
      token -> load_from_cache(conn, token, opts)
    end
  end
  defp maybe_load_from_cache(conn, _any, _opts), do: conn

  defp put_opts_in_private(conn, opts) do
    plug_opts = (conn.private[:invalidated_session_opts] || []) ++ [opts]

    Conn.put_private(conn, :invalidated_session_opts, plug_opts)
  end

  defp maybe_put_cache(conn, nil, _old_token, _opts), do: conn
  defp maybe_put_cache(conn, _user, nil, _opts), do: conn
  defp maybe_put_cache(conn, user, old_token, opts) do
    fetch_fn = Keyword.fetch!(opts, :fetch_token)

    case fetch_fn.(conn) do
      ^old_token -> conn
      _token     -> put_cache(conn, user, old_token, opts)
    end
  end

  defp put_cache(conn, user, token, opts) do
    {store, store_config} = invalidated_cache(conn, opts)

    store.put(store_config, token, user)

    conn
  end

  defp load_from_cache(conn, token, opts) do
    config                = Plug.fetch_config(conn)
    {store, store_config} = invalidated_cache(conn, opts)

    case store.get(store_config, token) do
      :not_found -> conn
      user       -> Plug.assign_current_user(conn, user, config)
    end
  end

  @doc false
  def load_session_value(conn) do
    conn
    |> Conn.fetch_session()
    |> Conn.get_session(@session_key)
  end

  @doc false
  def load_cookie_value(conn) do
    Conn.fetch_cookies(conn).cookies[@persistent_cookie_key]
  end

  defp invalidated_cache(conn, opts) do
    store_config = store_config(opts)
    config       = Plug.fetch_config(conn)
    store        = Config.get(config, :cache_store_backend, EtsCache)

    {store, store_config}
  end

  defp store_config(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    ttl       = Keyword.get(opts, :ttl, @store_ttl)

    [
      ttl: ttl,
      namespace: "invalidated_#{namespace}",
    ]
  end
end
