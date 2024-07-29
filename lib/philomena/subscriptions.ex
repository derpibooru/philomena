defmodule Philomena.Subscriptions do
  @moduledoc """
  Common subscription logic.

  `use Philomena.Subscriptions` requires the following option:

  - `:id_name`
    This is the name of the object field in the subscription table.
    For `m:Philomena.Images`, this would be `:image_id`.

  The following functions and documentation are produced in the calling module:
  - `subscribed?/2`
  - `subscriptions/2`
  - `create_subscription/2`
  - `delete_subscription/2`
  - `maybe_subscribe_on/4`
  """

  import Ecto.Query, warn: false
  alias Ecto.Multi

  alias Philomena.Repo

  defmacro __using__(opts) do
    # For Philomena.Images, this yields :image_id
    field_name = Keyword.fetch!(opts, :id_name)

    # For Philomena.Images, this yields Philomena.Images.Subscription
    subscription_module = Module.concat(__CALLER__.module, Subscription)

    quote do
      @doc """
      Returns whether the user is currently subscribed to this object.

      ## Examples

          iex> subscribed?(object, user)
          false

      """
      def subscribed?(object, user) do
        Philomena.Subscriptions.subscribed?(
          unquote(subscription_module),
          unquote(field_name),
          object,
          user
        )
      end

      @doc """
      Returns a map containing whether the user is currently subscribed to any of
      the provided objects.

      ## Examples

          iex> subscriptions([%{id: 1}, %{id: 2}], user)
          %{2 => true}

      """
      def subscriptions(objects, user) do
        Philomena.Subscriptions.subscriptions(
          unquote(subscription_module),
          unquote(field_name),
          objects,
          user
        )
      end

      @doc """
      Creates a subscription.

      ## Examples

          iex> create_subscription(object, user)
          {:ok, %Subscription{}}

          iex> create_subscription(object, user)
          {:error, %Ecto.Changeset{}}

      """
      def create_subscription(object, user) do
        Philomena.Subscriptions.create_subscription(
          unquote(subscription_module),
          unquote(field_name),
          object,
          user
        )
      end

      @doc """
      Deletes a subscription and removes notifications for it.

      ## Examples

          iex> delete_subscription(object, user)
          {:ok, %Subscription{}}

          iex> delete_subscription(object, user)
          {:error, %Ecto.Changeset{}}

      """
      def delete_subscription(object, user) do
        Philomena.Subscriptions.delete_subscription(
          unquote(subscription_module),
          unquote(field_name),
          object,
          user
        )
      end

      @doc """
      Creates a subscription inside the `m:Ecto.Multi` flow if `user` is not nil
      and `field` in `user` is `true`.

      Valid values for field are `:watch_on_reply`, `:watch_on_upload`, `:watch_on_new_topic`.

      ## Examples

          iex> maybe_subscribe_on(multi, :image, user, :watch_on_reply)
          %Ecto.Multi{}

          iex> maybe_subscribe_on(multi, :topic, nil, :watch_on_reply)
          %Ecto.Multi{}

      """
      def maybe_subscribe_on(multi, change_name, user, field) do
        Philomena.Subscriptions.maybe_subscribe_on(multi, __MODULE__, change_name, user, field)
      end
    end
  end

  @doc false
  def subscribed?(subscription_module, field_name, object, user) do
    case user do
      nil ->
        false

      _ ->
        subscription_module
        |> where([s], field(s, ^field_name) == ^object.id and s.user_id == ^user.id)
        |> Repo.exists?()
    end
  end

  @doc false
  def subscriptions(subscription_module, field_name, objects, user) do
    case user do
      nil ->
        %{}

      _ ->
        object_ids = Enum.map(objects, & &1.id)

        subscription_module
        |> where([s], field(s, ^field_name) in ^object_ids and s.user_id == ^user.id)
        |> Repo.all()
        |> Map.new(&{Map.fetch!(&1, field_name), true})
    end
  end

  @doc false
  def create_subscription(subscription_module, field_name, object, user) do
    struct!(subscription_module, [{field_name, object.id}, {:user_id, user.id}])
    |> subscription_module.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc false
  def delete_subscription(subscription_module, field_name, object, user) do
    struct!(subscription_module, [{field_name, object.id}, {:user_id, user.id}])
    |> Repo.delete()
  end

  @doc false
  def maybe_subscribe_on(multi, module, change_name, user, field)
      when field in [:watch_on_reply, :watch_on_upload, :watch_on_new_topic] do
    case user do
      %{^field => true} ->
        Multi.run(multi, :subscribe, fn _repo, changes ->
          object = Map.fetch!(changes, change_name)
          module.create_subscription(object, user)
        end)

      _ ->
        multi
    end
  end
end
