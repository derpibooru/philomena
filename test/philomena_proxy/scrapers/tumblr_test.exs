defmodule PhilomenaProxy.Scrapers.TumblrTest do
  use ExUnit.Case, async: true

  alias PhilomenaProxy.Camo
  alias PhilomenaProxy.Scrapers.Tumblr

  # scrape/2 is called directly: can_handle?/2 resolves the host over real DNS.
  @post_url "https://tolsticotic.tumblr.com/post/832898111343116288/hey-twilight-you-look-awful"

  @media "https://64.media.tumblr.com"
  @first "#{@media}/80a892ad6eb1f66a15a970a14cebb314/a8697f6e070898e9-d7"
  @second "#{@media}/add6bce5ef3783b9ab3e2de9c18093b7/20314a8cbfe4f76e-10"

  @first_widest "#{@first}/s1280x1920/ec9648f5cf9cf7e1439a4653c3724cf88808fbc2.png"
  @second_widest "#{@second}/s1280x1920/f019b80e7075dfa7bc23421bd81e9f7f8711bcb5.png"

  # Inline image markup from a real answer post: the src plus every srcset size.
  @answer_html """
  <div class="npf_row"><figure class="tmblr-full" data-orig-height="916" data-orig-width="1132">
  <img src="#{@first}/s640x960/3e411a1518ea4ddf04709cfd9bbf5222ab1d7508.png"
  data-orig-height="916" data-orig-width="1132"
  srcset="#{@first}/s75x75_c1/f2fab0c33a8790a65c95f99f2bc26c38588d7785.png 75w,
  #{@first}/s100x200/b1b80036ff164d1873bbbdb0063e73d5baf6309d.png 100w,
  #{@first}/s250x400/d112f087ef598585d06c54702141417f8e4107bf.png 250w,
  #{@first}/s400x600/5bd3f5ce8931c8b24e3b9f5fcd2ae4db62785b03.png 400w,
  #{@first}/s500x750/b599cc61232b25ceeac1afe7021529903bc17d3d.png 500w,
  #{@first}/s540x810/b74f2e1cf8157fdc99db0afacc5f53f1f9dbd642.png 540w,
  #{@first}/s640x960/3e411a1518ea4ddf04709cfd9bbf5222ab1d7508.png 640w,
  #{@first_widest} 1132w"
  sizes="(max-width: 1132px) 100vw, 1132px"/></figure></div>
  """

  # The widest size is neither the first nor the last match.
  @second_html """
  <figure><img src="#{@second}/s640x960/5349501e61b64c74d6782d5c37a34fa6f0e77fb9.png"
  srcset="#{@second}/s400x600/0123456789abcdef0123456789abcdef01234567.png 400w,
  #{@second_widest} 1280w,
  #{@second}/s540x810/89abcdef0123456789abcdef0123456789abcdef.png 540w"/></figure>
  """

  defp scrape(post) do
    test_pid = self()

    Req.Test.stub(PhilomenaProxy.Http, fn conn ->
      send(test_pid, {:tumblr_api, conn.host, conn.request_path, conn.query_string})
      Req.Test.json(conn, %{"response" => %{"posts" => [post]}})
    end)

    Tumblr.scrape(URI.parse(@post_url), @post_url)
  end

  defp post(type, html_field, html) do
    %{
      "type" => type,
      "post_url" => @post_url,
      "blog_name" => "tolsticotic",
      "summary" => "Hey twilight, you look awful",
      html_field => html
    }
  end

  defp image(url), do: %{url: url, camo_url: Camo.image_url(url)}

  describe "scrape/2" do
    test "requests the post by id from the blog's photo posts endpoint" do
      scrape(post("answer", "answer", @answer_html))

      assert_received {:tumblr_api, "api.tumblr.com",
                       "/v2/blog/tolsticotic.tumblr.com/posts/photo", query}

      assert %{"id" => "832898111343116288", "api_key" => _key} = URI.decode_query(query)
    end

    test "returns the widest size of an answer post's inline image" do
      assert scrape(post("answer", "answer", @answer_html)) == %{
               source_url: @post_url,
               author_name: "tolsticotic",
               description: "Hey twilight, you look awful",
               images: [image(@first_widest)]
             }
    end

    test "returns the widest size of each text post image in document order" do
      assert %{images: images} = scrape(post("text", "body", @second_html <> @answer_html))

      assert images == [image(@second_widest), image(@first_widest)]
    end

    test "returns no images for inline markup without tumblr media URLs" do
      html = ~s(<p>No art here.</p><img src="https://example.com/s1280x1920/abc.png"/>)

      assert %{images: []} = scrape(post("text", "body", html))
      assert %{images: []} = scrape(post("answer", "answer", html))
    end

    test "returns no images for an answer post without an answer field" do
      post = "answer" |> post("answer", "") |> Map.delete("answer")

      assert %{images: [], source_url: @post_url} = scrape(post)
    end

    for type <- ~w(video audio quote link chat) do
      test "returns nil for a #{type} post" do
        assert scrape(post(unquote(type), "body", @answer_html)) == nil
      end
    end
  end
end
