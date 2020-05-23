defmodule PhilomenaWeb.PowInvalidatedSessionPlugTest do
  use PhilomenaWeb.ConnCase
  doctest PhilomenaWeb.PowInvalidatedSessionPlug

  alias PhilomenaWeb.PowInvalidatedSessionPlug
  alias Philomena.{Users.User, Repo}

  @otp_app :philomena
  @config [otp_app: @otp_app, user: User, repo: Repo]
  @session_key "#{@otp_app}_auth"
  @cookie_key "#{@otp_app}_persistent_session"
  @invalidated_ttl 250

  alias Plug.{Conn, Test}
  alias Plug.Session, as: PlugSession
  alias Pow.Plug.Session
  alias PowPersistentSession.Plug.Cookie

  setup do
    user =
      %User{authentication_token: "token", name: "John Doe", slug: "john-doe"}
      |> User.changeset(%{
        "email" => "test@example.com",
        "password" => "password",
        "password_confirmation" => "password"
      })
      |> Repo.insert!()

    {:ok, user: user}
  end

  test "call/2 session id is reusable for short amount of time", %{conn: init_conn, user: user} do
    config = Keyword.put(@config, :session_ttl_renewal, 0)
    init_conn = prepare_session_conn(init_conn, user, config)

    assert session_id =
             init_conn
             |> init_session_plug()
             |> Conn.fetch_session()
             |> Conn.get_session(@session_key)

    conn = run_plug(init_conn, config)

    assert Pow.Plug.current_user(conn).id == user.id
    assert Conn.get_session(conn, @session_key) != session_id
    assert metadata = conn.private[:pow_session_metadata]
    refute metadata[:valid_totp_at]

    :timer.sleep(100)
    conn = run_plug(init_conn, config)

    assert Pow.Plug.current_user(conn).id == user.id
    assert Conn.get_session(conn, @session_key) == session_id
    assert metadata = conn.private[:pow_session_metadata]
    refute metadata[:valid_totp_at]

    :timer.sleep(@invalidated_ttl - 100)
    conn = run_plug(init_conn)

    refute Pow.Plug.current_user(conn)
  end

  test "call/2 persistent session id is reusable", %{conn: init_conn, user: user} do
    init_conn = prepare_persistent_session_conn(init_conn, user)

    assert persistent_session_id = init_conn.req_cookies[@cookie_key]

    conn = run_plug(init_conn)

    assert Pow.Plug.current_user(conn).id == user.id
    assert conn.cookies[@cookie_key] != persistent_session_id
    assert metadata = conn.private[:pow_session_metadata]
    refute metadata[:valid_totp_at]

    :timer.sleep(100)
    conn = run_plug(init_conn)

    assert Pow.Plug.current_user(conn).id == user.id
    assert conn.cookies[@cookie_key] == persistent_session_id
    assert metadata = conn.private[:pow_session_metadata]
    refute metadata[:valid_totp_at]

    :timer.sleep(@invalidated_ttl - 100)
    conn = run_plug(init_conn)

    refute Pow.Plug.current_user(conn)
    assert conn.cookies[@cookie_key] == persistent_session_id
  end

  test "call/2 with TOTP turned on", %{conn: init_conn, user: user} do
    user =
      user
      |> Ecto.Changeset.change(%{otp_required_for_login: true})
      |> Repo.update!()

    config = Keyword.put(@config, :session_ttl_renewal, 0)

    no_otp_auth_conn =
      init_conn
      |> prepare_session_conn(user, config)
      |> init_plug(config)

    assert no_otp_auth_conn.halted

    init_conn =
      init_conn
      |> Conn.put_private(:pow_session_metadata, valid_totp_at: DateTime.utc_now())
      |> prepare_session_conn(user, config)

    conn = run_plug(init_conn, config)

    assert Pow.Plug.current_user(conn).id == user.id
    assert metadata = conn.private[:pow_session_metadata]
    assert metadata[:valid_totp_at]
    assert metadata[:inserted_at]

    :timer.sleep(100)
    conn = run_plug(init_conn, config)

    assert Pow.Plug.current_user(conn).id == user.id
    assert metadata = conn.private[:pow_session_metadata]
    assert metadata[:valid_totp_at]
    refute metadata[:inserted_at]
  end

  test "call/2 with simultaneous requests", %{conn: init_conn, user: user} do
    init_conn = prepare_persistent_session_conn(init_conn, user)

    t1 =
      Task.async(fn ->
        init_conn
        |> init_plug(@config, fn conn ->
          Plug.Conn.register_before_send(conn, fn conn ->
            send(:task_2, :continue)

            receive do
              :continue -> conn
            end
          end)
        end)
        |> Conn.send_resp(200, "")
      end)

    Process.register(t1.pid, :task_1)

    t2 =
      Task.async(fn ->
        receive do
          :continue -> :ok
        end

        conn =
          init_conn
          |> init_plug(@config)
          |> Conn.send_resp(200, "")

        send(:task_1, :continue)

        conn
      end)

    Process.register(t2.pid, :task_2)

    conn_1 = Task.await(t1)
    conn_2 = Task.await(t2)

    assert Pow.Plug.current_user(conn_1)
    assert Pow.Plug.current_user(conn_2)
  end

  test "call/2 with aborted requests", %{conn: init_conn, user: user} do
    no_session_conn = prepare_persistent_session_conn(init_conn, user)

    # This request succeeds and rolls the session, but is not received because
    # the client aborted it
    _t1 =
      no_session_conn
      |> init_plug(@config)
      |> Conn.send_resp(200, "")

    # This request succeeds and does nothing
    t2 =
      no_session_conn
      |> init_plug(@config)
      |> Conn.send_resp(200, "")

    # This will work due to the invalidated session plug
    attempt_1 =
      init_conn
      |> Test.recycle_cookies(t2)
      |> init_plug(@config)
      |> Conn.send_resp(200, "")

    assert Pow.Plug.current_user(attempt_1)

    # It will subsequently fail, and the user will be signed out after their
    # session expires
    init_conn
    |> Test.recycle_cookies(attempt_1)
    |> Session.do_delete(@config)
    |> Conn.send_resp(200, "")

    # Commenting this line causes the test to pass
    :timer.sleep(@invalidated_ttl)

    attempt_2 =
      init_conn
      |> Test.recycle_cookies(t2)
      |> init_plug(@config)
      |> Conn.send_resp(200, "")

    assert Pow.Plug.current_user(attempt_2)
  end

  defp init_session_plug(conn) do
    conn
    |> Map.put(:secret_key_base, String.duplicate("abcdefghijklmnopqrstuvxyz0123456789", 2))
    |> PlugSession.call(PlugSession.init(store: :cookie, key: "foobar", signing_salt: "salt"))
  end

  defp init_plug(conn, config, before_session_callback \\ nil) do
    callback = before_session_callback || (& &1)

    conn
    |> init_session_plug()
    |> PowInvalidatedSessionPlug.call(
      PowInvalidatedSessionPlug.init({:pow_session, ttl: @invalidated_ttl})
    )
    |> PowInvalidatedSessionPlug.call(
      PowInvalidatedSessionPlug.init({:pow_persistent_session, ttl: @invalidated_ttl})
    )
    |> callback.()
    |> Session.call(Session.init(config))
    |> Cookie.call(Cookie.init([]))
    |> PowInvalidatedSessionPlug.call(PowInvalidatedSessionPlug.init(:load))
    |> PhilomenaWeb.TotpPlug.call(PhilomenaWeb.TotpPlug.init([]))
  end

  defp run_plug(conn, config \\ @config) do
    conn
    |> init_plug(config)
    |> Conn.send_resp(200, "")
  end

  defp create_persistent_session(conn, user, config) do
    conn
    |> init_plug(config)
    |> Session.do_create(user, config)
    |> Cookie.create(user, config)
    |> Conn.send_resp(200, "")
  end

  defp prepare_persistent_session_conn(conn, user, config \\ @config) do
    session_conn = create_persistent_session(conn, user, config)

    :timer.sleep(100)

    no_session_conn =
      conn
      |> Test.recycle_cookies(session_conn)
      |> delete_session_from_conn(config)

    :timer.sleep(100)

    conn
    |> Test.recycle_cookies(no_session_conn)
    |> Conn.fetch_cookies()
  end

  defp delete_session_from_conn(conn, config) do
    conn
    |> init_plug(config)
    |> Session.do_delete(config)
    |> Conn.send_resp(200, "")
  end

  defp create_session(conn, user, config) do
    conn
    |> init_plug(config)
    |> Session.do_create(user, config)
    |> Conn.send_resp(200, "")
  end

  defp prepare_session_conn(conn, user, config) do
    session_conn = create_session(conn, user, config)

    :timer.sleep(100)

    Test.recycle_cookies(conn, session_conn)
  end
end
