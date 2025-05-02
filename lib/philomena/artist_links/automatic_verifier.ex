defmodule Philomena.ArtistLinks.AutomaticVerifier do
  @moduledoc """
  Artist link automatic verification.

  Artist links contain a random code which is generated when the link is created. If the user
  places the code on their linked page and this verifier finds it, this expedites the process
  of verifying a link for the moderator, as they can simply use the presence of the code in a
  field controlled by the artist to ascertain the validity of the artist link.
  """

  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Repo
  import Ecto.Query

  @doc """
  Check links pending verification to see if the user placed the appropriate code on the page.

  Polls each artist link in unverified state and generates a changeset to either set it to
  link verified, if the code was found on the page, or reset the next check time, if the code
  was not found.

  Returns a list of changesets with updated links.
  """
  def generate_updates do
    # Automatically retry in an hour if we don't manage to
    # successfully verify any given link
    now = DateTime.utc_now(:second)
    recheck_time = DateTime.add(now, 3600, :second)

    Enum.map(links_to_check(now), fn link ->
      ArtistLink.automatic_verify_changeset(link, check_link(link, recheck_time))
    end)
  end

  defp links_to_check(now) do
    recheck_query =
      from ul in ArtistLink,
        where: ul.aasm_state == "unverified",
        where: ul.next_check_at < ^now

    Repo.all(recheck_query)
  end

  defp check_link(artist_link, recheck_time) do
    artist_link.uri
    |> PhilomenaProxy.Http.get()
    |> contains_verification_code?(artist_link.verification_code)
    |> if do
      %{next_check_at: nil, aasm_state: "link_verified"}
    else
      %{next_check_at: recheck_time}
    end
  end

  defp contains_verification_code?({:ok, %{body: body, status: 200}}, code) do
    String.contains?(body, code)
  end

  defp contains_verification_code?(_response, _code) do
    false
  end
end
