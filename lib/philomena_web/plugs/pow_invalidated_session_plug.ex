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
  @session_signing_salt Atom.to_string(Pow.Plug.Session)
  @persistent_cookie_key "#{@otp_app}_persistent_session"
  @persistent_cookie_signing_salt Atom.to_string(PowPersistentSession.Plug.Cookie)

  def init(:load), do: :load

  def init(:pow_session) do
    [
      fetch_token: &__MODULE__.client_store_fetch_session/1,
      namespace: :session
    ]
  end

  def init(:pow_persistent_session) do
    [
      fetch_token: &__MODULE__.client_store_fetch_persistent_cookie/1,
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
    token = fetch_fn.(conn)

    conn
    |> put_opts_in_private(opts)
    |> Conn.register_before_send(fn conn ->
      maybe_put_cache(conn, Plug.current_user(conn), token, opts)
    end)
  end

  defp maybe_load_from_cache(conn, nil, opts) do
    fetch_fn = Keyword.fetch!(opts, :fetch_token)

    case fetch_fn.(conn) do
      nil -> conn
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

    metadata =
      conn.private
      |> Map.get(:pow_session_metadata, [])
      |> Keyword.take([:valid_totp_at])

    case fetch_fn.(conn) do
      ^old_token -> conn
      _token -> put_cache(conn, {user, metadata}, old_token, opts)
    end
  end

  defp put_cache(conn, user, token, opts) do
    {store, store_config} = invalidated_cache(conn, opts)

    store.put(store_config, token, user)

    conn
  end

  defp load_from_cache(conn, token, opts) do
    config = Plug.fetch_config(conn)
    {store, store_config} = invalidated_cache(conn, opts)

    case store.get(store_config, token) do
      :not_found ->
        conn

      {user, metadata} ->
        metadata = Keyword.merge(metadata, conn.private[:pow_session_metadata] || [])

        conn
        |> Conn.put_private(:pow_session_metadata, metadata)
        |> Plug.assign_current_user(user, config)
    end
  end

  @doc false
  def client_store_fetch_session(conn) do
    conn =
      conn
      |> Plug.put_config(otp_app: @otp_app)
      |> Conn.fetch_session()

    with session_id when is_binary(session_id) <- Conn.get_session(conn, @session_key),
         {:ok, session_id} <- Plug.verify_token(conn, @session_signing_salt, session_id) do
      session_id
    else
      _any -> nil
    end
  end

  @doc false
  def client_store_fetch_persistent_cookie(conn) do
    conn =
      conn
      |> Plug.put_config(otp_app: @otp_app)
      |> Conn.fetch_cookies()

    with token when is_binary(token) <- conn.cookies[@persistent_cookie_key],
         {:ok, token} <- Plug.verify_token(conn, @persistent_cookie_signing_salt, token) do
      token
    else
      _any -> nil
    end
  end

  defp invalidated_cache(conn, opts) do
    store_config = store_config(opts)
    config = Plug.fetch_config(conn)
    store = Config.get(config, :cache_store_backend, EtsCache)

    {store, store_config}
  end

  defp store_config(opts) do
    namespace = Keyword.fetch!(opts, :namespace)
    ttl = Keyword.get(opts, :ttl, @store_ttl)

    [
      ttl: ttl,
      namespace: "invalidated_#{namespace}"
    ]
  end
end
