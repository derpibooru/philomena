defmodule PhilomenaWeb.SingletonToggleTests do
  @moduledoc """
  Shared characterization-test generators for the singleton toggle
  controller family: the long tail of nearly identical singleton
  `create`/`delete` controllers - subscriptions, notification reads, and
  the image interaction endpoints.

  Every route in this family sits in the `require_authenticated_user`
  scope, so the generators pin the uniform anonymous login redirect plus
  the family-shaped success and failure paths. Controller-specific
  behavior (banned users, hidden topics, parameter quirks) stays
  hand-written in the individual test files.

  ## Usage

      use PhilomenaWeb.ConnCase, async: true
      use PhilomenaWeb.SingletonToggleTests

  ### The anonymous tests and `anonymous_path/0`

  `subscription_toggle_tests/0` and `read_singleton_tests/0` both require a
  zero-arity `anonymous_path/0` returning the route under test with dummy
  ids:

      defp anonymous_path, do: ~p"/images/1/subscription"

  `require_authenticated_user` runs in the router pipeline and halts before
  the controller - and therefore before the context loads or authorizes any
  record - so the ids in that path need not exist, and the anonymous tests
  build no fixtures at all. They only ever assert the login redirect.

  ### Subscription controllers (`*.SubscriptionController`)

  Define `subscription_target/1`, taking the acting user (always a real
  user - the anonymous tests use `anonymous_path/0` instead), then call
  `subscription_toggle_tests()`:

      defp subscription_target(user) do
        image = image_fixture()

        %{
          path: ~p"/images/\#{image}/subscription",
          subscribe!: fn -> {:ok, _} = Images.create_subscription(image, user) end,
          subscribed?: fn -> Repo.exists?(...) end
        }
      end

  ### Read controllers (`*.ReadController`, notification clearing)

  Define `read_target/1` (same `user` contract) returning
  `%{path:, arrange!:, notification?:}` - `arrange!` must create a
  notification of the kind the controller clears for `user` - then call
  `read_singleton_tests()`.

  ### Image interaction controllers (vote/fave/hide)

  Define `interaction_path/1`, taking an image id (or anything that
  interpolates into the path), then call
  `image_interaction_guard_tests([:post, :delete])` for the shared
  auth/not-found pins. Success paths differ per controller and stay
  hand-written.
  """

  import ExUnit.Assertions
  import Phoenix.ConnTest, only: [html_response: 2]

  defmacro __using__(_opts) do
    quote do
      import PhilomenaWeb.SingletonToggleTests,
        only: [
          subscription_toggle_tests: 0,
          read_singleton_tests: 0,
          image_interaction_guard_tests: 1
        ]
    end
  end

  @doc """
  Asserts the `require_authenticated_user` redirect every route in this
  family gives anonymous users.
  """
  def assert_login_redirect(conn) do
    assert Phoenix.ConnTest.redirected_to(conn) == "/sessions/new"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "You must log in to access this page."
  end

  @doc """
  Asserts the 200 subscription partial (`_subscription.html`,
  `layout: false`) and returns whether it renders in the watching state -
  the Subscribe (`data-method="post"`) link is the hidden one iff the
  user is subscribed.
  """
  def subscription_partial_watching?(conn) do
    response = html_response(conn, 200)

    # layout: false - a bare partial, no page chrome
    refute response =~ "Derpibooru"
    assert response =~ "js-subscription-target"

    subscribe_link = Regex.run(~r/<a[^>]*data-method="post"[^>]*>/, response)
    assert subscribe_link, "expected a subscribe link in the partial, got: #{response}"

    hd(subscribe_link) =~ "hidden"
  end

  @doc """
  Generates the shared tests for a subscription toggle controller.
  Requires `anonymous_path/0` and `subscription_target/1` (see the moduledoc).
  """
  defmacro subscription_toggle_tests do
    quote do
      test "anonymous POST redirects to the login page", %{conn: conn} do
        conn = post(conn, anonymous_path())
        PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
      end

      test "anonymous DELETE redirects to the login page", %{conn: conn} do
        conn = delete(conn, anonymous_path())
        PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
      end

      test "POST creates the subscription and renders the watching partial", %{conn: conn} do
        %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
        target = subscription_target(user)

        conn = post(conn, target.path)

        assert PhilomenaWeb.SingletonToggleTests.subscription_partial_watching?(conn)
        assert target.subscribed?.()
      end

      test "POST when already subscribed renders the watching partial and stays subscribed",
           %{conn: conn} do
        # create_subscription inserts with on_conflict: :nothing, so
        # resubscribing is idempotent rather than an error
        %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
        target = subscription_target(user)
        target.subscribe!.()

        conn = post(conn, target.path)

        assert PhilomenaWeb.SingletonToggleTests.subscription_partial_watching?(conn)
        assert target.subscribed?.()
      end

      test "DELETE removes the subscription and renders the non-watching partial",
           %{conn: conn} do
        %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
        target = subscription_target(user)
        target.subscribe!.()

        conn = delete(conn, target.path)

        refute PhilomenaWeb.SingletonToggleTests.subscription_partial_watching?(conn)
        refute target.subscribed?.()
      end

      test "DELETE when not subscribed renders the non-watching partial idempotently",
           %{conn: conn} do
        # delete_subscription/2 now deletes via delete_all (idempotent, like
        # create's on_conflict: :nothing), so unsubscribing while not
        # subscribed is a clean success rather than an Ecto.StaleEntryError.
        %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
        target = subscription_target(user)

        conn = delete(conn, target.path)

        refute PhilomenaWeb.SingletonToggleTests.subscription_partial_watching?(conn)
        refute target.subscribed?.()
      end
    end
  end

  @doc """
  Generates the shared tests for a notification-clearing read controller.
  Requires `anonymous_path/0` and `read_target/1` (see the moduledoc).
  """
  defmacro read_singleton_tests do
    quote do
      test "anonymous POST redirects to the login page", %{conn: conn} do
        conn = post(conn, anonymous_path())
        PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
      end

      test "POST clears the user's notification and responds 200 with an empty body",
           %{conn: conn} do
        %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
        target = read_target(user)
        target.arrange!.()
        assert target.notification?.()

        conn = post(conn, target.path)

        assert response(conn, 200) == ""
        refute target.notification?.()
      end

      test "POST with no notification to clear still responds 200 with an empty body",
           %{conn: conn} do
        %{conn: conn, user: user} = register_and_log_in_user(%{conn: conn})
        target = read_target(user)

        conn = post(conn, target.path)

        assert response(conn, 200) == ""
      end
    end
  end

  @doc """
  Generates the shared auth/not-found pins for the image interaction
  controllers (vote/fave/hide). Requires `interaction_path/1` (see the
  moduledoc). `verbs` is the list of routed verbs (`[:post]` or
  `[:post, :delete]`), known at compile time.
  """
  defmacro image_interaction_guard_tests(verbs) do
    anonymous_tests =
      for verb <- verbs do
        quote do
          test "anonymous #{unquote(verb)} redirects to the login page", %{conn: conn} do
            # require_authenticated_user halts before the image is loaded,
            # so the id doesn't need to exist
            conn = unquote(verb)(conn, interaction_path(1))
            PhilomenaWeb.SingletonToggleTests.assert_login_redirect(conn)
          end
        end
      end

    shared_tests =
      quote do
        test "banned users are redirected back with the ban flash", %{conn: conn} do
          # FilterBannedUsersPlug runs before the image is loaded, so the
          # id doesn't need to exist; it redirects to the referrer ("/")
          %{conn: conn} = register_and_log_in_banned_user(%{conn: conn})

          conn = post(conn, interaction_path(1))

          assert redirected_to(conn) == "/"
          assert Phoenix.Flash.get(conn.assigns.flash, :error) == "You are currently banned."
        end

        test "an unknown image redirects to / with the not-found flash", %{conn: conn} do
          %{conn: conn} = register_and_log_in_user(%{conn: conn})

          conn = post(conn, interaction_path(999_999_999))

          assert redirected_to(conn) == "/"

          assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
                   "Couldn't find what you were looking for!"
        end

        test "a non-integer image id redirects to / with the not-found flash", %{conn: conn} do
          # The member loader normalizes malformed and missing ids alike before
          # authorization runs.
          %{conn: conn} = register_and_log_in_user(%{conn: conn})

          conn = post(conn, interaction_path("not-a-number"))

          assert redirected_to(conn) == "/"

          assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
                   "Couldn't find what you were looking for!"
        end
      end

    anonymous_tests ++ [shared_tests]
  end
end
