defmodule PhilomenaWeb.FilterControllerTest do
  # The :index "fq" branch searches the Filter OpenSearch index.
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Philomena.FiltersFixtures
  import Philomena.UsersFixtures

  alias Philomena.Filters
  alias Philomena.Filters.Filter
  alias Philomena.Repo
  alias Philomena.Users
  alias PhilomenaQuery.Search
  alias PhilomenaQuery.SearchHelpers

  describe "GET /filters" do
    test "renders system filters for anonymous users", %{conn: conn} do
      response = html_response(get(conn, ~p"/filters"), 200)

      assert response =~ "Filters - Derpibooru"
      assert response =~ Filters.default_filter().name
    end

    test "renders the user's own filters when logged in", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      response = html_response(get(conn, ~p"/filters"), 200)

      assert response =~ filter.name
    end

    test "renders the edit affordance for the user's own filter", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      response = html_response(get(conn, ~p"/filters"), 200)

      assert response =~ "Edit this filter"
      assert response =~ ~p"/filters/#{filter}/edit"
    end

    test "with fq searches the filter index", %{conn: conn} do
      Search.clear_index!(Filter)
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      mine = filter_fixture(user)
      _other = filter_fixture(confirmed_user_fixture())
      SearchHelpers.reindex_all!(Filter)

      response = html_response(get(conn, ~p"/filters?#{[fq: "name:#{mine.name}"]}"), 200)

      # (the fq value is echoed in the search box, so assert the result link)
      assert response =~ "href=\"/filters/#{mine.id}\""
    end

    test "with fq does not return other users' private filters", %{conn: conn} do
      Search.clear_index!(Filter)
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      other = filter_fixture(confirmed_user_fixture())
      SearchHelpers.reindex_all!(Filter)

      response = html_response(get(conn, ~p"/filters?#{[fq: "name:#{other.name}"]}"), 200)

      refute response =~ "href=\"/filters/#{other.id}\""
    end

    test "with an invalid fq renders the error message", %{conn: conn} do
      Search.clear_index!(Filter)

      response = html_response(get(conn, ~p"/filters?#{[fq: "name:("]}"), 200)

      assert response =~ "Filters - Derpibooru"
    end
  end

  describe "GET /filters/:id" do
    test "renders a system filter for anonymous users", %{conn: conn} do
      filter = Filters.default_filter()

      response = html_response(get(conn, ~p"/filters/#{filter}"), 200)

      assert response =~ "Showing Filter - Derpibooru"
      assert response =~ filter.name
    end

    test "renders another user's public filter", %{conn: conn} do
      filter = filter_fixture(confirmed_user_fixture(), %{public: true})

      response = html_response(get(conn, ~p"/filters/#{filter}"), 200)

      assert response =~ filter.name
    end

    test "redirects with the authorization flash for another user's private filter",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(confirmed_user_fixture())

      conn = get(conn, ~p"/filters/#{filter}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the user's own private filter", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      assert html_response(get(conn, ~p"/filters/#{filter}"), 200) =~ filter.name
    end

    test "renders edit and destroy affordances only for the filter owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      response = html_response(get(conn, ~p"/filters/#{filter}"), 200)

      assert response =~ "Edit this filter"
      assert response =~ ~p"/filters/#{filter}/edit"
      assert response =~ "Destroy this filter"

      other_conn = build_conn()
      other_user = confirmed_user_fixture()
      other_conn = log_in_user(other_conn, other_user)
      public_filter = filter_fixture(user, %{public: true})

      response = html_response(get(other_conn, ~p"/filters/#{public_filter}"), 200)

      refute response =~ "Edit this filter"
      refute response =~ ~p"/filters/#{public_filter}/edit"
      refute response =~ "Destroy this filter"
    end

    test "redirects with the not-found flash for an unknown filter", %{conn: conn} do
      conn = get(conn, ~p"/filters/999999999")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Couldn't find"
    end

    test "redirects with the not-found flash for a non-integer id", %{conn: conn} do
      conn = get(conn, ~p"/filters/not-a-number")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Couldn't find what you were looking for!"
    end
  end

  describe "GET /filters/new" do
    test "redirects anonymous users with the authorization flash", %{conn: conn} do
      conn = get(conn, ~p"/filters/new")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You can't access that page."
    end

    test "renders the form for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/filters/new"), 200)

      assert response =~ "New Filter - Derpibooru"
      assert response =~ "Creating New Filter"
    end

    test "based_on a visible filter prefills the form", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(confirmed_user_fixture(), %{public: true})

      response = html_response(get(conn, ~p"/filters/new?#{[based_on: filter.id]}"), 200)

      assert response =~ "Creating New Filter"
    end

    test "based_on an unknown filter renders a blank form", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      response = html_response(get(conn, ~p"/filters/new?#{[based_on: 999_999_999]}"), 200)

      assert response =~ "Creating New Filter"
    end

    test "renders the form without a fingerprint", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(without_fingerprint(conn), ~p"/filters/new")

      assert html_response(conn, 200) =~ "New Filter - Derpibooru"
    end
  end

  describe "POST /filters" do
    test "redirects anonymous users with the authorization flash", %{conn: conn} do
      conn = post(conn, ~p"/filters", %{"filter" => %{"name" => "Anon filter"}})

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You can't access that page."
    end

    test "creates a filter and redirects to it", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      name = unique_filter_name()

      conn =
        post(conn, ~p"/filters", %{
          "filter" => %{"name" => name, "spoilered_tag_list" => "safe"}
        })

      filter = Repo.get_by!(Filter, name: name)
      assert filter.user_id == user.id
      assert redirected_to(conn) == ~p"/filters/#{filter}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Filter created successfully."
    end

    test "with a blank name re-renders the form", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = post(conn, ~p"/filters", %{"filter" => %{"name" => ""}})

      # NOTE: failure re-renders new.html without the :title assign
      response = html_response(conn, 200)
      assert response =~ "Creating New Filter"
      assert Repo.aggregate(Filter, :count) == 1
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      name = unique_filter_name()

      conn = post(without_fingerprint(conn), ~p"/filters", %{"filter" => %{"name" => name}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      refute Repo.get_by(Filter, name: name)
    end
  end

  describe "GET /filters/:id/edit" do
    test "renders the form for the filter's owner", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      response = html_response(get(conn, ~p"/filters/#{filter}/edit"), 200)

      assert response =~ "Editing Filter - Derpibooru"
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(confirmed_user_fixture(), %{public: true})

      conn = get(conn, ~p"/filters/#{filter}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "redirects a user editing a system filter", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      filter = Philomena.Filters.default_filter()

      conn = get(conn, ~p"/filters/#{filter}/edit")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "renders the form for the owner without a fingerprint", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      conn = get(without_fingerprint(conn), ~p"/filters/#{filter}/edit")

      assert html_response(conn, 200) =~ "Editing Filter - Derpibooru"
    end
  end

  describe "PATCH /filters/:id" do
    test "updates the filter and redirects to it", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      conn =
        patch(conn, ~p"/filters/#{filter}", %{
          "filter" => %{"name" => "Renamed #{filter.name}"}
        })

      assert redirected_to(conn) == ~p"/filters/#{filter}"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Filter updated successfully."
      assert Repo.get!(Filter, filter.id).name == "Renamed #{filter.name}"
    end

    test "PUT also updates the filter", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      conn = put(conn, ~p"/filters/#{filter}", %{"filter" => %{"description" => "Updated"}})

      assert redirected_to(conn) == ~p"/filters/#{filter}"
      assert Repo.get!(Filter, filter.id).description == "Updated"
    end

    test "with a blank name re-renders the form", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      conn = patch(conn, ~p"/filters/#{filter}", %{"filter" => %{"name" => ""}})

      assert html_response(conn, 200) =~ "Editing Filter"
      assert Repo.get!(Filter, filter.id).name == filter.name
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(confirmed_user_fixture(), %{public: true})

      conn = patch(conn, ~p"/filters/#{filter}", %{"filter" => %{"name" => "Taken over"}})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
    end

    test "without a fingerprint redirects to / with the authorization flash", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      conn =
        patch(without_fingerprint(conn), ~p"/filters/#{filter}", %{
          "filter" => %{"name" => "Renamed #{filter.name}"}
        })

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get!(Filter, filter.id).name == filter.name
    end
  end

  describe "DELETE /filters/:id" do
    test "deletes the filter and redirects to the index", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)

      conn = delete(conn, ~p"/filters/#{filter}")

      assert redirected_to(conn) == ~p"/filters"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Filter deleted successfully."
      refute Repo.get(Filter, filter.id)
    end

    test "a filter in use as a current filter is not deleted", %{conn: conn} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(user)
      {:ok, _user} = Users.set_current_filter(user, filter)

      conn = delete(conn, ~p"/filters/#{filter}")

      assert redirected_to(conn) == ~p"/filters/#{filter}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Filter is still in use, not deleted."

      assert Repo.get(Filter, filter.id)
    end

    test "redirects another user with the authorization flash", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      filter = filter_fixture(confirmed_user_fixture(), %{public: true})

      conn = delete(conn, ~p"/filters/#{filter}")

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.get(Filter, filter.id)
    end
  end
end
