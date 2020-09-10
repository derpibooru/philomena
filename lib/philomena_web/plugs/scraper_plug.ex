defmodule PhilomenaWeb.ScraperPlug do
  def init(opts) do
    opts
  end

  def call(conn, opts) do
    params_name = Keyword.get(opts, :params_name, "image")
    params_key = Keyword.get(opts, :params_key, "image")

    case conn.params do
      %{^params_name => %{^params_key => %Plug.Upload{}}} ->
        conn

      %{"scraper_cache" => url} when not is_nil(url) ->
        url
        |> Philomena.Http.get()
        |> maybe_fixup_params(opts, conn)

      _ ->
        conn
    end
  end

  defp maybe_fixup_params({:ok, %Tesla.Env{body: body, status: 200}}, opts, conn) do
    params_name = Keyword.get(opts, :params_name, "image")
    params_key = Keyword.get(opts, :params_key, "image")
    file = Briefly.create!()
    now = DateTime.utc_now() |> DateTime.to_unix(:microsecond)

    File.write!(file, body)

    fake_upload = %Plug.Upload{
      path: file,
      content_type: "application/octet-stream",
      filename: "scraper-#{now}"
    }

    updated_form = Map.put(conn.params[params_name], params_key, fake_upload)

    updated_params = Map.put(conn.params, params_name, updated_form)

    %Plug.Conn{conn | params: updated_params}
  end

  defp maybe_fixup_params(_response, _opts, conn), do: conn
end
