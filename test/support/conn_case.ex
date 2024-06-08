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
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import PhilomenaWeb.ConnCase

      # The default endpoint for testing
      @endpoint PhilomenaWeb.Endpoint

      use PhilomenaWeb, :verified_routes
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Philomena.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Philomena.Repo, {:shared, self()})
    end

    # Insert default filter
    %Philomena.Filters.Filter{name: "Default", system: true}
    |> Philomena.Filters.change_filter()
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
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Philomena.Users.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
