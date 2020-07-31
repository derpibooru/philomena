defmodule PhilomenaWeb.CompromisedPasswordCheckPlug do
  import Phoenix.Controller
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case pwned_passwords_enabled?() do
      true -> error_if_password_compromised(conn, conn.params)
      false -> conn
    end
  end

  defp error_if_password_compromised(conn, %{"user" => %{"password" => password}}) do
    case password_compromised?(password) do
      true ->
        conn
        |> put_flash(
          :error,
          "We've detected that the password you entered has been compromised during a data breach of another website. Please choose a different password."
        )
        |> redirect(external: conn.assigns.referrer)
        |> halt()

      false ->
        conn
    end
  end

  defp error_if_password_compromised(conn, _params),
    do: conn

  defp password_compromised?(password) do
    <<prefix::binary-size(5), rest::binary>> =
      :crypto.hash(:sha, password)
      |> Base.encode16()

    case Philomena.Http.get!(make_api_url(prefix)) do
      %Tesla.Env{body: body, status: 200} -> String.contains?(body, rest)
      _ -> false
    end
  end

  defp make_api_url(prefix) do
    "https://api.pwnedpasswords.com/range/#{prefix}"
  end

  defp pwned_passwords_enabled? do
    Application.get_env(:philomena, :pwned_passwords) != false
  end
end
