defmodule PhilomenaWeb.IDValidationPlug do
  @moduledoc """
  If an ID number was passed with an image upload, checks that the ID fits the
  upload URL site.

  ## Example

      plug PhilomenaWeb.IDValidationPlug when action in [:create]
  """
  alias Philomena.Images.IDValidator
  alias Plug.Conn

  def init(opts), do: opts

  @spec call(Conn.t(), map()) :: Conn.t()
  def call(conn, _opts) do
    case skip_verify?(conn) do
      true ->
        conn
      _ ->
        params = conn.params

        conn
          |> maybe_validate_id(params)
    end
  end

  @spec maybe_validate_id(Conn.t(), %{}) :: Conn.t()
  # ID as string, try to convert to integer
  defp maybe_validate_id(conn, %{"image" => %{"id" => id_str}, "url" => url})
  when is_binary(id_str) and is_binary(url) do
    case Integer.parse(id_str) do
      {id, ""} when is_integer(id) -> # reject all but pure ints
        maybe_validate_id(conn, %{"image" => %{"id" => id}, "url" => url})
      _ ->
        conn |> go_away(:bad_request)
    end
  end
  # ID as integer, validate against source_url
  defp maybe_validate_id(conn, %{"image" => %{"id" => id}, "url" => url})
  when is_integer(id) and is_binary(url) do
    case IDValidator.validate_id(id, url) do
      {:ok, _site} ->
        conn
      _ ->
        conn
          |> go_away(:expectation_failed)
    end
  end
  # Other invalid ID values
  defp maybe_validate_id(conn, %{"id" => _id}), do: conn |> go_away(:bad_request)
  # No ID, handle as normal
  defp maybe_validate_id(conn, _blorp), do: conn

  @spec go_away(Conn.t(), integer() | atom()) :: Conn.t()
  defp go_away(conn, reason) do
    import Plug.Conn.Status
    sc = code(reason)

    conn
      |> Conn.put_resp_content_type("text/plain")
      |> Conn.send_resp(sc, reason_phrase(sc))
      |> Conn.halt()
  end

  defp skip_verify?(conn),
    do: Canada.Can.can?(conn.assigns.current_user, :create, IDValidator)
end
