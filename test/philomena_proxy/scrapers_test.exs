defmodule PhilomenaProxy.ScrapersTest do
  use ExUnit.Case, async: true

  alias PhilomenaProxy.Scrapers

  # No stub is registered for the rejection tests: a request that reached
  # Req.Test would raise, so a plain return proves nothing was sent.
  @rejected_urls [
    "/images/download-preview.png",
    "//example.com/image.png",
    "file:///etc/passwd",
    "ftp://example.com/image.png",
    "http:///nohost",
    "https://",
    "",
    nil
  ]

  @unstubbed ~r/cannot find mock\/stub PhilomenaProxy.Http/

  describe "rejected URLs" do
    test "scrape_cached/1 with an accepted URL and no stub registered raises" do
      assert_raise RuntimeError, @unstubbed, fn ->
        Scrapers.scrape_cached("https://example.com/image.png")
      end
    end

    # The Raw scraper probes the URL with a HEAD request.
    test "scrape!/1 with an accepted URL and no stub registered raises" do
      assert_raise RuntimeError, @unstubbed, fn ->
        Scrapers.scrape!("https://example.com/image.png")
      end
    end

    for url <- @rejected_urls do
      test "scrape_cached/1 rejects #{inspect(url)} without a request" do
        assert Scrapers.scrape_cached(unquote(url)) == {:error, :invalid_url}
      end

      test "scrape!/1 returns nil for #{inspect(url)} without a request" do
        assert Scrapers.scrape!(unquote(url)) == nil
      end
    end
  end

  describe "absolute http(s) URLs" do
    setup do
      Req.Test.stub(PhilomenaProxy.Http, fn conn ->
        Plug.Conn.resp(conn, 200, "#{conn.scheme}://#{conn.host}#{conn.request_path}")
      end)

      :ok
    end

    for url <- ["http://example.com/image.png", "https://example.com/image.png"] do
      test "scrape_cached/1 fetches #{url}" do
        assert {:ok, %{status: 200, body: unquote(url)}} = Scrapers.scrape_cached(unquote(url))
      end
    end
  end
end
