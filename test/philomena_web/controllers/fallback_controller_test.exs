defmodule PhilomenaWeb.FallbackControllerTest do
  @moduledoc """
  Unit tests for `PhilomenaWeb.FallbackController`, the Phoenix `action_fallback`
  that translates the two global context error shapes into the exact
  responses.

  It delegates to `NotAuthorizedPlug` / `NotFoundPlug`, both of which branch on
  `conn.assigns.ajax?`. All four combinations are exercised at the unit level by
  building a conn, setting the `:ajax?` assign, and calling `call/2` directly.
  """

  use PhilomenaWeb.ConnCase, async: true

  alias PhilomenaWeb.FallbackController

  # A conn with a session initialised (so the non-AJAX redirect path can
  # `fetch_flash`) and the `:ajax?` assign set to the requested value.
  defp conn_with_ajax(ajax?) do
    build_conn()
    |> Plug.Test.init_test_session(%{})
    |> assign(:ajax?, ajax?)
  end

  # A conn with a session initialised and the `:referrer` assign populated the
  # way `PhilomenaWeb.ReferrerPlug` does - from the Referer header, or "/" when
  # that header is absent.
  defp conn_with_referer(referer) do
    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> Phoenix.Controller.fetch_flash([])

    conn =
      case referer do
        nil -> conn
        value -> put_req_header(conn, "referer", value)
      end

    PhilomenaWeb.ReferrerPlug.call(conn, [])
  end

  describe "call/2 with {:error, :unauthorized}" do
    test "AJAX request gets a bare 403 with the not-authorized message" do
      conn = FallbackController.call(conn_with_ajax(true), {:error, :unauthorized})

      assert response(conn, 403) == "You can't access that page."
      assert conn.halted
    end

    test "non-AJAX request gets a flash + redirect to /" do
      conn = FallbackController.call(conn_with_ajax(false), {:error, :unauthorized})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert conn.halted
    end
  end

  describe "call/2 with {:error, :not_found}" do
    test "AJAX request gets a bare 404 with the not-found message" do
      conn = FallbackController.call(conn_with_ajax(true), {:error, :not_found})

      assert response(conn, 404) == "Couldn't find what you were looking for!"
      assert conn.halted
    end

    test "non-AJAX request gets a flash + redirect to /" do
      conn = FallbackController.call(conn_with_ajax(false), {:error, :not_found})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"

      assert conn.halted
    end
  end

  describe "call/2 with {:error, :ban}" do
    test "redirects to / with the banned flash when no referer header is present" do
      conn = FallbackController.call(conn_with_referer(nil), {:error, :ban})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
      assert conn.halted
    end

    test "redirects to the referer when one is set" do
      conn = FallbackController.call(conn_with_referer("/forums/dis"), {:error, :ban})

      assert redirected_to(conn) == "/forums/dis"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
      assert conn.halted
    end
  end
end
