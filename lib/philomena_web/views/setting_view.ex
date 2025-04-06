defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view
  alias Philomena.Users.User

  def themes do
    [
      Dark: "dark",
      Light: "light"
    ]
  end

  def theme_colors do
    Enum.map(User.theme_colors(), fn name ->
      {String.capitalize(name), name}
    end)
  end

  def theme_paths do
    Map.new(User.themes(), fn name ->
      {name, static_path(PhilomenaWeb.Endpoint, "/css/#{name}.css")}
    end)
  end

  def scale_options do
    [
      [key: "Load full images on image pages", value: "false"],
      [key: "Load full images on image pages, sized to fit the page", value: "partscaled"],
      [key: "Scale large images down before downloading", value: "true"]
    ]
  end

  def local_tab_class(conn) do
    case conn.assigns.current_user do
      nil -> ""
      _user -> "hidden"
    end
  end

  def staff?(%{role: role}), do: role != "user"
  def staff?(_), do: false

  def field_with_help(title, children) do
    content =
      children
      |> Enum.intersperse(" ")
      |> Enum.concat([
        content_tag :span, class: "field-help-button" do
          [
            content_tag(:i, "", class: "fa-regular fa-question-circle"),
            " Help"
          ]
        end,
        content_tag :div, class: "field-help-content hidden" do
          [
            # The `title` is static and doesn't include dynamic user input.
            # sobelow_skip ["XSS.Raw"]
            raw(text_to_html(title)),
            tag(:hr)
          ]
        end
      ])

    content_tag(:div, content, class: "field", title: title)
  end
end
