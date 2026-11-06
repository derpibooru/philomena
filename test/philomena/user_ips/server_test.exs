defmodule Philomena.UserIps.ServerTest do
  # async: false - the server is registered globally, so concurrent request
  # tests would cast their own usages into it.
  use Philomena.DataCase, async: false

  import Philomena.UsersFixtures

  alias Philomena.UserIps
  alias Philomena.UserIps.UserIp

  test "repeated requests between flushes count as one use" do
    user = confirmed_user_fixture()
    server = start_supervised!(UserIps.Server)
    now = DateTime.utc_now(:second)

    assert UserIps.record_usage(user, {203, 0, 113, 7}, now) == :ok
    assert UserIps.record_usage(user, {203, 0, 113, 7}, now) == :ok
    :sys.get_state(server)
    refute Repo.exists?(where(UserIp, user_id: ^user.id))

    send(server, :flush)
    :sys.get_state(server)
    assert [%UserIp{uses: 1}] = Repo.all(where(UserIp, user_id: ^user.id))
  end
end
