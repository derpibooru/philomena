defimpl Canada.Can, for: [Atom, Philomena.Users.User] do
  alias Philomena.Users.User
  alias Philomena.Images.Image

  # Admins can do anything
  def can?(%User{role: "admin"}, _action, _model), do: true

  # Users can...

  # View non-deleted images
  def can?(_user, action, Image)
      when action in [:new, :create, :index],
      do: true

  def can?(_user, :show, %Image{hidden_from_users: true}), do: false
  def can?(_user, :show, %Image{hidden_from_users: false}), do: true

  # Otherwise...
  def can?(_user, _action, _model), do: false
end
