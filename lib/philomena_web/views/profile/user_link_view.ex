defmodule PhilomenaWeb.Profile.ArtistLinkView do
  use PhilomenaWeb, :view

  def verified?(%{aasm_state: state}), do: state == "verified"
  def contacted?(%{aasm_state: state}), do: state == "contacted"
  def link_verified?(%{aasm_state: state}), do: state == "link_verified"
  def unverified?(%{aasm_state: state}), do: state == "unverified"
  def rejected?(%{aasm_state: state}), do: state == "rejected"

  def public?(%{public: public}), do: !!public

  def verified_as_string(%{aasm_state: "verified"}), do: "Yes"
  def verified_as_string(_artist_link), do: "No"

  def public_as_string(%{public: true}), do: "Yes"
  def public_as_string(_artist_link), do: "No"

  def tag_name(%{tag: nil}), do: nil
  def tag_name(%{tag: tag}), do: tag.name
end
