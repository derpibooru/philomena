defmodule PhilomenaWeb.CompromisedPasswordCheckPlug do
  import Phoenix.Controller
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    error_if_password_compromised(conn, conn.params)
  end

  defp error_if_password_compromised(conn, %{"user" => %{"password" => password}}) do
    if password_compromised?(password) do
      conn
      |> put_flash(
        :error,
        "We've detected that the password you entered has been compromised during a data breach of another website. Please choose a different password."
      )
      |> redirect(external: conn.assigns.referrer)
      |> halt()
    else
      conn
    end
  end

  defp error_if_password_compromised(conn, _params),
    do: conn

  @doc """
  Returns whether a password appears in the Pwned Passwords database.

  The range query only sends the first five characters of the password's SHA-1
  hash. If the check is disabled or unavailable, passwords are allowed through.
  """
  def password_compromised?(password) when is_binary(password) do
    if pwned_passwords_enabled?() do
      password_compromised_in_breach?(password)
    else
      false
    end
  end

  def password_compromised?(_password), do: false

  defp password_compromised_in_breach?(password) do
    <<prefix::binary-size(5), rest::binary>> =
      :crypto.hash(:sha, password)
      |> Base.encode16()

    case PhilomenaProxy.Http.get(make_api_url(prefix)) do
      {:ok, %{body: body, status: 200}} ->
        Enum.any?(String.split(body, "\n"), &String.starts_with?(&1, rest <> ":"))

      _ ->
        false
    end
  end

  defp make_api_url(prefix) do
    "https://api.pwnedpasswords.com/range/#{prefix}"
  end

  defp pwned_passwords_enabled? do
    Application.get_env(:philomena, :pwned_passwords) != false
  end
end
