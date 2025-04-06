defmodule PhilomenaWeb.Admin.UserView do
  use PhilomenaWeb, :view

  def page_params(params) do
    []
    |> page_param(params, "uq", :uq)
    |> page_param(params, "staff", :staff)
    |> page_param(params, "twofactor", :twofactor)
  end

  defp page_param(list, params, key, key_atom) do
    case params[key] do
      nil -> list
      "" -> list
      val -> [{key_atom, val} | list]
    end
  end

  def checkbox_mapper(form, field, input_opts, role, _label_opts, _opts) do
    input_id = "user_roles_#{role.id}"
    label_opts = [for: input_id]

    input_opts =
      Keyword.merge(input_opts,
        class: "checkbox",
        id: input_id,
        checked_value: to_string(role.id),
        hidden_input: false,
        checked: Enum.member?(Enum.map(Map.get(form.data, field), & &1.id), role.id)
      )

    content_tag(:li, class: "table-list__label") do
      content_tag(:div) do
        [
          checkbox(form, field, input_opts),
          " ",
          content_tag(:label, description(role.name, role.resource_type), label_opts)
        ]
      end
    end
  end

  def description("moderator", "Image"), do: "Manage images"
  def description("moderator", "DuplicateReport"), do: "Manage duplicates"
  def description("moderator", "Comment"), do: "Manage comments"
  def description("moderator", "ArtistLink"), do: "Manage artist links"
  def description("moderator", "Topic"), do: "Moderate forums"

  def description("moderator", "Tag"), do: "Manage tag details"
  def description("admin", "Tag"), do: "Alias tags"
  def description("batch_update", "Tag"), do: "Update tags in batches"

  def description("moderator", "User"), do: "Manage users and wipe votes"
  def description("admin", "Role"), do: "Manage permissions"
  def description("admin", "SiteNotice"), do: "Manage site notices"
  def description("admin", "Badge"), do: "Manage badges"
  def description("admin", "Advert"), do: "Manage ads"
  def description("admin", "StaticPage"), do: "Manage static pages"
  def description("admin", "Image"), do: "Hard-delete images"

  def description(_name, _resource_type), do: "(unknown permission)"

  def filtered_roles(permission_set, roles) do
    roles
    |> Enum.filter(&Enum.member?(permission_set, [&1.name, &1.resource_type]))
    |> Enum.map(&{&1, ""})
  end

  def general_permissions do
    [
      ["batch_update", "Tag"]
    ]
  end

  def assistant_permissions do
    [
      ["moderator", "Image"],
      ["moderator", "DuplicateReport"],
      ["moderator", "Comment"],
      ["moderator", "Tag"],
      ["moderator", "ArtistLink"],
      ["moderator", "Topic"]
    ]
  end

  def moderator_permissions do
    [
      ["moderator", "User"],
      ["admin", "Tag"],
      ["admin", "Role"],
      ["admin", "SiteNotice"],
      ["admin", "Badge"],
      ["admin", "Advert"],
      ["admin", "StaticPage"],
      ["admin", "Image"]
    ]
  end
end
