defmodule PhilomenaWeb.Admin.UserView do
  use PhilomenaWeb, :view

  def checkbox_mapper(form, field, input_opts, role, _label_opts, _opts) do
    input_id = "user_roles_#{role.id}"
    label_opts = [for: input_id]

    input_opts =
      Keyword.merge(input_opts,
        class: "checkbox",
        id: input_id,
        checked_value: to_string(role.id),
        hidden_input: false,
        checked: Enum.member?(Enum.map(input_value(form, field), & &1.id), role.id)
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
  def description("moderator", "UserLink"), do: "Manage user links"
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
      ["moderator", "UserLink"],
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
      ["admin", "StaticPage"]
    ]
  end

  def can_view_emails?(conn),
    do: can?(conn, :index, :email_address)
end
