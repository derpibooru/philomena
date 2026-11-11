defmodule PhilomenaProxy.HttpTest do
  use ExUnit.Case, async: true

  alias PhilomenaProxy.Http

  # No stub is registered for the rejection tests: a request that reached
  # Req.Test would raise, so an error tuple proves nothing was sent.
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

  @rejection "URL must be absolute http or https"

  describe "rejected URLs" do
    test "an accepted URL with no stub registered raises" do
      assert_raise RuntimeError, ~r/cannot find mock\/stub PhilomenaProxy.Http/, fn ->
        Http.get("https://example.com/image.png")
      end
    end

    for url <- @rejected_urls do
      test "get/1 rejects #{inspect(url)} without a request" do
        assert {:error, %ArgumentError{message: @rejection}} = Http.get(unquote(url))
      end

      test "head/1 rejects #{inspect(url)} without a request" do
        assert {:error, %ArgumentError{message: @rejection}} = Http.head(unquote(url))
      end

      test "post/2 rejects #{inspect(url)} without a request" do
        assert {:error, %ArgumentError{message: @rejection}} = Http.post(unquote(url), "body")
      end
    end
  end

  describe "absolute http(s) URLs" do
    setup do
      Req.Test.stub(Http, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        conn
        |> Plug.Conn.put_resp_header("x-method", conn.method)
        |> Plug.Conn.put_resp_header("x-host", conn.host)
        |> Plug.Conn.put_resp_header("x-path", conn.request_path)
        |> Plug.Conn.resp(200, body)
      end)

      :ok
    end

    test "get/1 sends the request" do
      assert {:ok, %{status: 200} = resp} = Http.get("https://example.com/image.png")

      assert resp.headers["x-method"] == ["GET"]
      assert resp.headers["x-host"] == ["example.com"]
      assert resp.headers["x-path"] == ["/image.png"]
    end

    test "head/1 sends the request" do
      assert {:ok, %{status: 200} = resp} = Http.head("http://example.com/image.png")

      assert resp.headers["x-method"] == ["HEAD"]
    end

    test "post/2 sends the request with its body" do
      assert {:ok, %{status: 200, body: "payload"} = resp} =
               Http.post("https://example.com/upload", "payload")

      assert resp.headers["x-method"] == ["POST"]
    end
  end
end
