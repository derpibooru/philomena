defmodule PhilomenaWeb.Plugs.Session do
  use Pow.Plug.Base

  alias Plug.Conn
  alias Philomena.{Repo, Users.User}

  @session_key :philomena_session

  def fetch(conn, _config) do
    conn = Conn.fetch_session(conn)
    user = Conn.get_session(conn, @session_key)

    conn
    |> maybe_load_user(user)
  end

  def create(conn, user, _config) do
    value = session_value(user)

    conn =
      conn
      |> Conn.fetch_session()
      |> Conn.put_session(@session_key, value)

    {conn, user}
  end

  def delete(conn, _config) do
    conn
    |> Conn.fetch_session()
    |> Conn.delete_session(@session_key)
  end

  defp maybe_load_user(conn, {:ok, user}) do
    with {:ok, [user_id, hash]} <- Jason.decode(user),
         %User{} = user <- Repo.get(User, user_id),
         true <- SecureCompare.compare(hash, binary_part(user.encrypted_password, 0, 25)) do
      {conn, user}
    else
      _ ->
        {conn, nil}
    end
  end

  defp maybe_load_user(conn, _) do
    {conn, nil}
  end

  defp session_value(user) do
    Jason.encode([user.id, binary_part(user.encrypted_password, 0, 25)])
  end
end
