defmodule PhilomenaWeb.SourceChangeView do
  use PhilomenaWeb, :view

  def staff?(source_change),
    do:
      not is_nil(source_change.user) and not Philomena.Attribution.anonymous?(source_change) and
        source_change.user.role != "user" and not source_change.user.hide_default_role

  def user_column_class(source_change) do
    case staff?(source_change) do
      true -> "success"
      false -> nil
    end
  end
end
