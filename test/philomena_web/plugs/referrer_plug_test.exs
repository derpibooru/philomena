defmodule PhilomenaWeb.ReferrerPlugTest do
  @moduledoc """
  Unit tests for `PhilomenaWeb.ReferrerPlug`.

  The plug assigns `:referrer` from the Referer header (defaulting to `"/"`)
  and `:ajax?` from the X-Requested-With header.
  """

  use PhilomenaWeb.ConnCase, async: true

  alias PhilomenaWeb.ReferrerPlug

  defp with_referrers(referrers) do
    Enum.reduce(referrers, build_conn(), fn referrer, conn ->
      %{conn | req_headers: conn.req_headers ++ [{"referer", referrer}]}
    end)
  end

  test "defaults the referrer to / when the header is missing" do
    conn = ReferrerPlug.call(build_conn(), [])

    assert conn.assigns.referrer == "/"
  end

  test "assigns the referrer from the header" do
    conn = ReferrerPlug.call(with_referrers(["https://example.com/a"]), [])

    assert conn.assigns.referrer == "https://example.com/a"
  end

  test "uses the first referrer when the header is repeated" do
    conn =
      ["https://example.com/a", "https://example.com/b"]
      |> with_referrers()
      |> ReferrerPlug.call([])

    assert conn.assigns.referrer == "https://example.com/a"
  end

  test "detects ajax requests" do
    conn =
      build_conn()
      |> put_req_header("x-requested-with", "XMLHttpRequest")
      |> ReferrerPlug.call([])

    assert conn.assigns.ajax?
  end
end
