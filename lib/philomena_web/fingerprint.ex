defmodule PhilomenaWeb.Fingerprint do
  import Plug.Conn

  @type t :: String.t()
  @name "_ses"

  @doc """
  Assign the current fingerprint to the conn.
  """
  @spec fetch_fingerprint(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def fetch_fingerprint(conn, _opts) do
    conn =
      conn
      |> fetch_session()
      |> fetch_cookies()

    # Try to get the fingerprint from the session, then from the cookie.
    fingerprint = upgrade(get_session(conn, @name), conn.cookies[@name])

    # If the fingerprint is valid, persist to session.
    case valid_format?(fingerprint) do
      true ->
        conn
        |> put_session(@name, fingerprint)
        |> assign(:fingerprint, fingerprint)

      false ->
        assign(conn, :fingerprint, nil)
    end
  end

  defp upgrade(<<"c", _::binary>> = session_value, <<"d", _::binary>> = cookie_value) do
    if valid_format?(cookie_value) do
      # When both fingerprint values are valid and the session value
      # is an old version, use the cookie value.
      cookie_value
    else
      # Use the session value.
      session_value
    end
  end

  defp upgrade(session_value, cookie_value) do
    # Prefer the session value, using the cookie value if it is unavailable.
    session_value || cookie_value
  end

  @doc """
  Determine whether the fingerprint corresponds to a valid format.

  Valid formats start with `c` or `d` (for the version). The `c` format is a legacy format
  corresponding to an integer-valued hash from the frontend. The `d` format is the current
  format corresponding to a hex-valued hash from the frontend. By design, it is not
  possible to infer anything else about these values from the server.

  See assets/js/fp.ts for additional information on the generation of the `d` format.

  ## Examples

      iex> valid_format?("b2502085657")
      false

      iex> valid_format?("c637334158")
      true

      iex> valid_format?("d63c4581f8cf58d")
      true

      iex> valid_format?("5162549b16e8448")
      false

  """
  @spec valid_format?(any()) :: boolean()
  def valid_format?(fingerprint)

  def valid_format?(<<"c", rest::binary>>) when byte_size(rest) <= 12 do
    match?({_result, ""}, Integer.parse(rest))
  end

  def valid_format?(<<"d", rest::binary>>) when byte_size(rest) == 14 do
    match?({:ok, _result}, Base.decode16(rest, case: :lower))
  end

  def valid_format?(_fingerprint), do: false
end
