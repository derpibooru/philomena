defmodule PhilomenaWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import PhilomenaWeb.ConnCase

      @endpoint PhilomenaWeb.Endpoint

      use PhilomenaWeb, :verified_routes
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Philomena.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Philomena.Repo, {:shared, self()})
    end

    %Philomena.Filters.Filter{name: "Default", system: true}
    |> Philomena.Filters.Filter.changeset(nil)
    |> Philomena.Repo.insert!()

    fingerprint = to_string(:io_lib.format(~c"d~14.16.0b", [:rand.uniform(2 ** 53)]))

    conn =
      Phoenix.ConnTest.build_conn()
      |> Phoenix.ConnTest.put_req_cookie("_ses", fingerprint)

    {:ok, conn: conn}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Philomena.UsersFixtures.confirmed_user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that registers and logs in a moderator.

      setup :register_and_log_in_moderator
  """
  def register_and_log_in_moderator(%{conn: conn}) do
    user = Philomena.UsersFixtures.moderator_user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that registers and logs in an admin.

      setup :register_and_log_in_admin
  """
  def register_and_log_in_admin(%{conn: conn}) do
    user = Philomena.UsersFixtures.admin_user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that registers and logs in a user with an active ban.

      setup :register_and_log_in_banned_user
  """
  def register_and_log_in_banned_user(%{conn: conn}) do
    user = Philomena.UsersFixtures.banned_user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that registers and logs in an admin with an active ban.

      setup :register_and_log_in_banned_admin
  """
  def register_and_log_in_banned_admin(%{conn: conn}) do
    user = Philomena.UsersFixtures.admin_user_fixture()
    Philomena.BansFixtures.user_ban_fixture(user)
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that registers and logs in a TOTP-enabled user, including
  the TOTP session token.

      setup :register_and_log_in_totp_user
  """
  def register_and_log_in_totp_user(%{conn: conn}) do
    user = Philomena.UsersFixtures.totp_user_fixture()
    %{conn: log_in_totp_user(conn, user), user: user}
  end

  @doc """
  Setup-style helper that registers a moderator granted the `resource_type`
  admin `role_map` entry and logs them in, returning `%{conn:, user:}`.

      setup %{conn: conn} do
        register_and_log_in_role_moderator(%{conn: conn}, "Badge")
      end

  Several admin resources (Badge, Advert, SiteNotice, …) gate their abilities
  on a `{resource_type => %{"admin" => _}}` entry in the user's `role_map`,
  which is rebuilt at login from the `roles` association - so the grant is a
  `Philomena.Roles.Role` row plus a `users_roles` join. A "Forum" resource_type
  is inert (no ability rule keys on it); the admin forum controller test uses
  it to prove the grant still does nothing.
  """
  def register_and_log_in_role_moderator(%{conn: conn}, resource_type) do
    user = role_moderator_fixture(resource_type)
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs in a fresh moderator granted the `resource_type` admin `role_map` entry,
  returning the updated `conn`. See `register_and_log_in_role_moderator/2` for
  what the grant is and why it is needed.
  """
  def log_in_role_moderator(conn, resource_type) do
    log_in_user(conn, role_moderator_fixture(resource_type))
  end

  defp role_moderator_fixture(resource_type) do
    user = Philomena.UsersFixtures.moderator_user_fixture()

    role =
      Philomena.Repo.insert!(%Philomena.Roles.Role{name: "admin", resource_type: resource_type})

    Philomena.Repo.insert_all("users_roles", [%{user_id: user.id, role_id: role.id}])
    user
  end

  @doc """
  Setup-style helper that registers a moderator granted the `User` "moderator"
  `role_map` entry (`%{"User" => %{"moderator" => _}}`) and logs them in,
  returning `%{conn:, user:}`.

  The `Admin.User.*` child controllers gate on `can?(:edit, %User{})`, which a
  plain moderator lacks but which this grant satisfies (`Philomena.Users.Ability`
  "Manage users", `role_map: %{"User" => %{"moderator" => _}}`). The grant is a
  `Philomena.Roles.Role` row with `name: "moderator", resource_type: "User"` plus
  a `users_roles` join - distinct from `register_and_log_in_role_moderator/2`,
  which inserts a `name: "admin"` role and so produces
  `%{resource_type => %{"admin" => _}}`.
  """
  def register_and_log_in_user_role_moderator(%{conn: conn}) do
    user = Philomena.UsersFixtures.moderator_user_fixture()

    role =
      Philomena.Repo.insert!(%Philomena.Roles.Role{name: "moderator", resource_type: "User"})

    Philomena.Repo.insert_all("users_roles", [%{user_id: user.id, role_id: role.id}])
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper providing a user and their API key for `/api/v1` requests.

      setup :create_api_user

  The `:api` pipeline authenticates solely via the `key` query parameter
  (`PhilomenaWeb.ApiTokenPlug`); session login has no effect on it. Any
  user fixture's `authentication_token` works as a key, so for other roles
  use e.g. `moderator_user_fixture().authentication_token` directly.
  """
  def create_api_user(_context) do
    user = Philomena.UsersFixtures.confirmed_user_fixture()
    %{user: user, api_key: user.authentication_token}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Philomena.Users.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  @doc """
  Logs the given TOTP-enabled `user` into the `conn` along with the TOTP
  session token that `PhilomenaWeb.TotpPlug` (the `:ensure_totp` pipeline)
  checks. Without it, any request from a TOTP-enabled user to an
  `:ensure_totp` route redirects to `/sessions/totp/new`.

  It returns an updated `conn`.
  """
  def log_in_totp_user(conn, user) do
    totp_token = Philomena.Users.generate_user_totp_token(user)

    conn
    |> log_in_user(user)
    |> Plug.Conn.put_session(:totp_token, totp_token)
  end

  @doc """
  Drops the `_ses` fingerprint cookie from `conn`, as on a visitor's first
  request before the frontend has set it.

  It returns an updated `conn`.
  """
  def without_fingerprint(conn), do: Phoenix.ConnTest.delete_req_cookie(conn, "_ses")

  @doc """
  Gives the `conn` a fresh, unique `remote_ip`.

  It returns an updated `conn`.

  `Philomena.RateLimiter` rate-limits writes on a Valkey counter keyed per
  operation and per acting identity - the actor's user when signed in, otherwise
  its IP - so anonymous writes are IP-scoped and the IP is the only part that
  varies. The SQL sandbox does not roll Valkey back, and the counter's TTL (a few
  seconds to a minute) outlives a ~6 s suite run, so a fixed address inherits
  counters from earlier tests and from earlier runs, and eventually trips the
  limit. Every anonymous write test therefore needs its own address.
  """
  def put_unique_ip(conn) do
    n = System.unique_integer([:positive])
    %{conn | remote_ip: {10, rem(div(n, 65536), 256), rem(div(n, 256), 256), rem(n, 256)}}
  end

  @doc """
  Helper to set up the conn with global assigns set by the application shell.
  """
  def viewer_conn(conn, user) do
    conn
    |> Plug.Conn.assign(:current_user, user)
    |> Plug.Conn.assign(:image_filter, %Philomena.Filters.ImageFilter{
      query: %{match_all: %{}},
      display_query: %{match_none: %{}},
      display_tag_ids: []
    })
    |> Phoenix.ConnTest.init_test_session(%{})
    |> PhilomenaWeb.Fingerprint.fetch_fingerprint([])
    |> PhilomenaWeb.UserAttributionPlug.call([])
    |> PhilomenaWeb.AdminCountersPlug.call([])
  end
end
