defmodule PhilomenaWeb.CommissionView do
  use PhilomenaWeb, :view

  alias Philomena.Commissions.Commission

  def categories, do: [[key: "-", value: ""] | Commission.categories()]
  def types, do: Commission.types()
end
