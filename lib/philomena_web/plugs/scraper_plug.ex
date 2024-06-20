defmodule PhilomenaWeb.ScraperPlug do
  @filename_regex ~r/filename="([^"]+)"/

  @spec init(keyword()) :: keyword()
  def init(opts) do
    opts
  end

  @spec call(Plug.Conn.t(), keyword()) :: Plug.Conn.t()
  def call(conn, opts) do
    params_name = Keyword.get(opts, :params_name, "image")
    params_key = Keyword.get(opts, :params_key, "image")

    case conn.params do
      %{^params_name => %{^params_key => %Plug.Upload{}}} ->
        conn

      %{"scraper_cache" => url} when not is_nil(url) and url != "" ->
        url
        |> PhilomenaProxy.Http.get()
        |> maybe_fixup_params(url, opts, conn)

      _ ->
        conn
    end
  end

  # Writing the tempfile doesn't allow traversal
  # sobelow_skip ["Traversal.FileModule"]
  defp maybe_fixup_params({:ok, %{status: 200} = resp}, url, opts, conn) do
    params_name = Keyword.get(opts, :params_name, "image")
    params_key = Keyword.get(opts, :params_key, "image")
    name = extract_filename(url, resp.headers)
    file = Plug.Upload.random_file!(UUID.uuid1())

    File.write!(file, resp.body)

    fake_upload = %Plug.Upload{
      path: file,
      content_type: "application/octet-stream",
      filename: name
    }

    put_in(conn.params[params_name][params_key], fake_upload)
  end

  defp maybe_fixup_params(_response, _url, _opts, conn), do: conn

  defp extract_filename(url, headers) do
    name =
      with [value | _] <- headers["content-disposition"],
           [name] <- Regex.run(@filename_regex, value, capture: :all_but_first) do
        name
      else
        _ ->
          Path.basename(url)
      end

    String.slice(name, 0, 127)
  end
end
