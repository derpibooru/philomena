defmodule PhilomenaWeb.SettingView do
  use PhilomenaWeb, :view
  alias Philomena.Users.Settings

  def themes do
    [
      Dark: "dark",
      Light: "light"
    ]
  end

  def theme_colors do
    Enum.map(Settings.theme_colors(), fn name ->
      {String.capitalize(name), name}
    end)
  end

  def theme_paths do
    Map.new(Settings.themes(), fn name ->
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

  def staff?(%{role: role}), do: role != "user"
  def staff?(_), do: false

  def tab_class(conn, tab_id, opts \\ []) do
    if is_active_tab(conn, tab_id, opts), do: "", else: "hidden"
  end

  def tab_link(conn, display_name, tab_id, opts \\ []) do
    default = Keyword.get(opts, :default, false)
    class = if is_active_tab(conn, tab_id, opts), do: "selected", else: ""

    link(display_name,
      to: "?tab=#{tab_id}",
      data: [click_tab: tab_id, tab_default: default],
      class: class
    )
  end

  defp is_active_tab(conn, tab_id, opts) do
    default = Keyword.get(opts, :default, false)
    tab = conn.params["tab"]

    if is_nil(tab) do
      default
    else
      tab == tab_id
    end
  end

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
