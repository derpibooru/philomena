defmodule PhilomenaWeb.Image.TagControllerTest do
  use PhilomenaWeb.ConnCase, async: false

  @moduletag :search

  import Ecto.Query
  import Philomena.AttributionFixtures
  import Philomena.ImagesFixtures
  import Philomena.TagsFixtures

  alias PhilomenaQuery.Search
  alias Philomena.TagChanges.Limits
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags.Tag
  alias Philomena.Repo

  setup do
    # The successful update actions re-render the image's _tags.html.slime
    # partial, whose quick tag table queries the tags index
    # (TagView.lookup_quick_tags/1). Without the index the render 500s.
    Search.clear_index!(Tag)

    # Valkey tag-change counters (rltcn:/rltcr:, 50 per 10 min) are scoped to the
    # acting identity - `u:<user_id>` for a logged-in user, `i:<ip>` for an
    # anonymous visitor - and are not rolled back by the SQL sandbox. The
    # logged-in tests below each register a fresh user, so their `u:` bucket
    # starts empty; the anonymous tests use put_unique_ip/1 for a fresh `i:`
    # bucket. This clears the anonymous `i:127.0.0.1` bucket (the default
    # ConnTest IP) defensively so accumulated counts can't trip check_limits.
    reset_tag_change_limits(ip: "127.0.0.1")
    :ok
  end

  defp tag_names(image) do
    image |> Repo.preload(:tags, force: true) |> Map.fetch!(:tags) |> Enum.map(& &1.name)
  end

  # Fills the user's Valkey tag bucket to the 50-change limit so the next
  # multi-tag update trips Images.update_image_tags' check_limits step and takes the
  # controller's rate-limited error branch. Registers cleanup of the counters
  # (they carry a 10-minute TTL and the SQL sandbox does not roll them back).
  defp fill_tag_bucket!(user) do
    ip = %Postgrex.INET{address: {127, 0, 0, 1}, netmask: 32}
    :ok = Limits.record_action(user, ip, 50, 0)
    on_exit(fn -> reset_tag_change_limits(user: user, ip: ip) end)
  end

  test "PATCH as a logged-in user updates the tags and renders the partial", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    response = html_response(conn, 200)

    assert response =~ "added test tag"
    refute response =~ "Derpibooru"

    assert Enum.sort(tag_names(image)) == ["added test tag", "other added tag", "safe"]

    assert Repo.exists?(
             from tc in TagChange,
               where: tc.image_id == ^image.id and tc.user_id == ^user.id
           )
  end

  test "PATCH can remove an implied tag listed in old_tag_input", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    implied_tag = tag_fixture(name: "implied tag")
    source_tag = tag_fixture(name: "source tag")

    source_tag =
      source_tag
      |> Repo.preload(:implied_tags)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:implied_tags, [implied_tag])
      |> Repo.update!()

    image = image_fixture(tags: "safe, #{source_tag.name}, #{implied_tag.name}")

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe, #{source_tag.name}, #{implied_tag.name}",
          "tag_input" => "safe, #{source_tag.name}, replacement tag"
        }
      })

    assert html_response(conn, 200)
    assert Enum.sort(tag_names(image)) == ["replacement tag", "safe", source_tag.name]
  end

  test "PATCH adds the oc tag for an oc-namespaced tag", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    oc_tag = tag_fixture(name: "oc")
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, #{oc_tag.name}:test character"
        }
      })

    assert html_response(conn, 200)
    assert Enum.sort(tag_names(image)) == ["oc", "oc:test character", "safe"]
  end

  test "PUT behaves like PATCH", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      put(conn, ~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    assert html_response(conn, 200) =~ "added test tag"
  end

  test "PATCH anonymously updates the tags", %{conn: conn} do
    image = image_fixture()

    conn =
      conn
      |> put_unique_ip()
      |> patch(~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    assert html_response(conn, 200) =~ "added test tag"

    assert Repo.exists?(
             from tc in TagChange,
               where: tc.image_id == ^image.id and is_nil(tc.user_id)
           )
  end

  test "PATCH without any tag change renders the partial", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{"old_tag_input" => "safe", "tag_input" => "safe"}
      })

    assert html_response(conn, 200) =~ "safe"
    assert tag_names(image) == ["safe"]
    refute Repo.exists?(from tc in TagChange, where: tc.image_id == ^image.id)
  end

  test "PATCH reducing the image below 3 tags renders the partial without changing tags",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{"old_tag_input" => "safe", "tag_input" => "safe, one more"}
      })

    assert html_response(conn, 200)
    assert tag_names(image) == ["safe"]
    refute Repo.exists?(from tc in TagChange, where: tc.image_id == ^image.id)
  end

  test "PATCH on an image with tag editing disabled redirects with the authorization flash",
       %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    image = image_fixture(tag_editing_allowed: false)

    conn =
      patch(conn, ~p"/images/#{image}/tags", %{
        "image" => %{"old_tag_input" => "safe", "tag_input" => "safe, a, b"}
      })

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
  end

  test "a rate-limited non-AJAX PATCH redirects to the referrer with a flash", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    fill_tag_bucket!(user)

    conn =
      conn
      |> put_req_header("referer", ~p"/images/#{image}")
      |> patch(~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    assert redirected_to(conn) == ~p"/images/#{image}"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Too many tags changed. Change fewer tags or try again later."

    # check_limits rolls the whole transaction back, so no tags were changed.
    assert tag_names(image) == ["safe"]
  end

  test "a rate-limited AJAX PATCH responds 300 with an empty body and the flash", %{conn: conn} do
    %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
    image = image_fixture()
    fill_tag_bucket!(user)

    conn =
      conn
      |> put_req_header("x-requested-with", "XMLHttpRequest")
      |> patch(~p"/images/#{image}/tags", %{
        "image" => %{
          "old_tag_input" => "safe",
          "tag_input" => "safe, added test tag, other added tag"
        }
      })

    assert response(conn, 300) == ""

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Too many tags changed. Change fewer tags or try again later."

    assert tag_names(image) == ["safe"]
  end

  test "PATCH as a banned user redirects with the ban flash", %{conn: conn} do
    %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

    conn = patch(conn, ~p"/images/999999999/tags", %{"image" => %{}})

    assert redirected_to(conn) == "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
  end
end
