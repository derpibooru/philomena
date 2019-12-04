defmodule PhilomenaWeb.Profile.Commission.ItemView do
  use PhilomenaWeb, :view

  alias Philomena.Commissions.Commission

  def types, do: Commission.types()
end
