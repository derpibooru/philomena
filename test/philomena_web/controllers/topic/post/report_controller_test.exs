defmodule PhilomenaWeb.Topic.Post.ReportControllerTest do
  use PhilomenaWeb.ConnCase, async: true

  import Ecto.Query
  import Philomena.ForumsFixtures
  import Philomena.RulesFixtures
  import Philomena.TopicsFixtures

  alias Philomena.Reports.Report
  alias Philomena.Repo

  setup do
    forum = forum_fixture()
    topic = topic_fixture(forum)
    post = hd(topic.posts)

    %{forum: forum, topic: topic, post: post}
  end

  describe "GET /forums/:forum_id/topics/:topic_id/posts/:post_id/reports/new" do
    test "renders the report form for anonymous users",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports/new")

      # NOTE: unlike the image/gallery report forms, no :title assign is set
      response = html_response(conn, 200)
      assert response =~ "Submit a report"
    end

    test "renders the report form for logged-in users",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports/new")

      assert html_response(conn, 200) =~ "Submit a report"
    end

    test "redirects to / with the not-found flash for an unknown post",
         %{conn: conn, forum: forum, topic: topic} do
      conn = get(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/999999999/reports/new")

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Couldn't find what you were looking for!"
    end

    test "renders the report form without a fingerprint",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      conn =
        get(
          without_fingerprint(conn),
          ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports/new"
        )

      assert html_response(conn, 200) =~ "Submit a report"
    end
  end

  describe "POST /forums/:forum_id/topics/:topic_id/posts/:post_id/reports" do
    test "as a logged-in user creates the report and redirects to /reports",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
      rule = rule_fixture()

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports", %{
          "report" => %{
            "reason" => "Test post report",
            "rule_id" => rule.id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert redirected_to(conn) == ~p"/reports"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Your report has been received and will be checked by staff shortly."

      report =
        Repo.one!(
          from r in Report,
            where: r.post_id == ^post.id
        )

      assert report.user_id == user.id
      assert report.state == "open"
    end

    test "anonymously creates the report and redirects to /",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      rule = rule_fixture()

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports", %{
          "report" => %{
            "reason" => "Anonymous post report",
            "rule_id" => rule.id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert redirected_to(conn) == "/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Your report has been received and will be checked by staff shortly."

      report =
        Repo.one!(
          from r in Report,
            where: r.post_id == ^post.id
        )

      assert report.user_id == nil
    end

    test "with a blank reason re-renders the report form",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      # NOTE: the create failure now renders new.html through the shared
      # PhilomenaWeb.ReportView (200) rather than raising on a missing view.
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      rule = rule_fixture()

      conn =
        post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports", %{
          "report" => %{
            "reason" => "",
            "rule_id" => rule.id,
            "user_agent" => "Test Browser/1.0"
          }
        })

      assert html_response(conn, 200) =~ "Submit a report"
      assert Repo.aggregate(Report, :count) == 0
    end

    test "as a banned user redirects with the ban flash",
         %{conn: conn, forum: forum, topic: topic, post: post} do
      %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

      conn = post(conn, ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports", %{})

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You are currently banned"
    end

    test "without a fingerprint redirects to / with the authorization flash", %{
      conn: conn,
      forum: forum,
      topic: topic,
      post: post
    } do
      conn =
        post(
          without_fingerprint(conn),
          ~p"/forums/#{forum}/topics/#{topic}/posts/#{post}/reports",
          %{
            "report" => %{
              "reason" => "Reported without a fingerprint",
              "rule_id" => rule_fixture().id,
              "user_agent" => "Test Browser/1.0"
            }
          }
        )

      assert redirected_to(conn) == "/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You can't access that page."
      assert Repo.aggregate(Report, :count) == 0
    end
  end
end
