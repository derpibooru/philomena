defmodule Philomena.Servers.UserLinkUpdater do
  alias Philomena.UserLinks.UserLink
  alias Philomena.Repo
  import Ecto.Query

  @seven_days 7 * 24 * 60 * 60
  @three_days 3 * 24 * 60 * 60
  @twelve_hours 12 * 60 * 60
  @one_hour 60 * 60
  @two_minutes 2 * 60

  def child_spec([]) do
    %{
      id: Philomena.Servers.UserLinkUpdater,
      start: {Philomena.Servers.UserLinkUpdater, :start_link, [[]]}
    }
  end

  def start_link([]) do
    {:ok, spawn_link(&run/0)}
  end

  defp run do
    now = DateTime.utc_now()

    UserLink
    |> where([ul], ul.aasm_state == "unverified" and ul.next_check_at < ^now)
    |> Repo.all(log: false)
    |> Enum.map(&automatic_verify/1)

    :timer.sleep(:timer.seconds(120))
    run()
  end

  defp automatic_verify(user_link) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    diff = DateTime.diff(now, DateTime.from_naive!(user_link.created_at, "Etc/UTC"), :second)

    # Set next check time according to how long link has been pending

    next_check_at =
      cond do
        diff > @seven_days ->
          DateTime.add(now, @seven_days)

        diff > @three_days ->
          DateTime.add(now, @twelve_hours)

        diff > @one_hour ->
          DateTime.add(now, @one_hour)

        true ->
          DateTime.add(now, @two_minutes)
      end

    UserLink
    |> where(id: ^user_link.id)
    |> Repo.update_all(set: [next_check_at: next_check_at])

    user_link
    |> Map.get(:uri)
    |> Philomena.Http.get()
    |> handle_response(user_link)
  end

  defp handle_response({:ok, %Tesla.Env{body: body, status: 200}}, user_link) do
    case :binary.match(body, user_link.verification_code) do
      :nomatch ->
        nil

      _match ->
        UserLink
        |> where(id: ^user_link.id)
        |> Repo.update_all(set: [next_check_at: nil, aasm_state: "link_verified"])
    end
  end

  defp handle_response(_, _user_link), do: nil
end
