defmodule PhilomenaWeb.CompromisedPasswordCheckPlug do
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    error_if_password_compromised(conn, conn.params)
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

    case HTTPoison.get(make_api_url(prefix)) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} -> String.contains?(body, rest)
      _ -> false
    end
  end

  defp make_api_url(prefix) do
    "https://api.pwnedpasswords.com/range/#{prefix}"
  end
end
