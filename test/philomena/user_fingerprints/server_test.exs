defmodule Philomena.UserFingerprints.ServerTest do
  # async: false - the server is registered globally, so concurrent request
  # tests would cast their own usages into it.
  use Philomena.DataCase, async: false

  import Philomena.UsersFixtures

  alias Philomena.UserFingerprints
  alias Philomena.UserFingerprints.UserFingerprint

  test "repeated requests between flushes count as one use" do
    user = confirmed_user_fixture()
    server = start_supervised!(UserFingerprints.Server)
    now = DateTime.utc_now(:second)

    assert UserFingerprints.record_usage(user, "d015c342859dde3", now) == :ok
    assert UserFingerprints.record_usage(user, "d015c342859dde3", now) == :ok
    :sys.get_state(server)
    refute Repo.exists?(where(UserFingerprint, user_id: ^user.id))

    send(server, :flush)
    :sys.get_state(server)
    assert [%UserFingerprint{uses: 1}] = Repo.all(where(UserFingerprint, user_id: ^user.id))
  end
end
