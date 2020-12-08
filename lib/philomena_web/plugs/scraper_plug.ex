defmodule PhilomenaWeb.ScraperPlug do
  @filename_regex ~r/filename="([^"]+)"/

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    params_name = Keyword.get(opts, :params_name, "image")
    params_key = Keyword.get(opts, :params_key, "image")

    case conn.params do
      %{^params_name => %{^params_key => %Plug.Upload{}}} ->
        conn

      %{"scraper_cache" => url} when not is_nil(url) and url != "" ->
        url
        |> Philomena.Http.get()
        |> maybe_fixup_params(url, opts, conn)

      _ ->
        conn
    end
  end

  defp maybe_fixup_params(
         {:ok, %Tesla.Env{body: body, status: 200, headers: headers}},
         url,
         opts,
         conn
       ) do
    params_name = Keyword.get(opts, :params_name, "image")
    params_key = Keyword.get(opts, :params_key, "image")
    name = extract_filename(url, headers)
    file = Briefly.create!()

    File.write!(file, body)

    fake_upload = %Plug.Upload{
      path: file,
      content_type: "application/octet-stream",
      filename: name
    }

    updated_form = Map.put(conn.params[params_name], params_key, fake_upload)

    updated_params = Map.put(conn.params, params_name, updated_form)

    %Plug.Conn{conn | params: updated_params}
  end

  defp maybe_fixup_params(_response, _url, _opts, conn), do: conn

  defp extract_filename(url, resp_headers) do
    {_, header} =
      Enum.find(resp_headers, {nil, "filename=\"#{Path.basename(url)}\""}, fn {key, value} ->
        key == "content-disposition" and Regex.match?(@filename_regex, value)
      end)

    [name] = Regex.run(@filename_regex, header, capture: :all_but_first)

    String.slice(name, 0, 127)
  end
end
