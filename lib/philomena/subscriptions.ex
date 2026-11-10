defmodule Philomena.Subscriptions do
  @moduledoc """
  Common subscription logic.

  `use Philomena.Subscriptions` requires the following option:

  - `:id_name`
    This is the name of the object field in the subscription table.
    For `m:Philomena.Images`, this would be `:image_id`.

  The following internal persistence functions are produced in the calling
  module:
  - `subscribed?/2`
  - `subscriptions/2`
  - `create_subscription/2`
  - `delete_subscription/2`
  - `maybe_subscribe_on/4`
  """

  import Ecto.Query, warn: false

  alias Philomena.Multi
  alias Philomena.Repo

  defmacro __using__(opts) do
    # For Philomena.Images, this yields :image_id
    field_name = Keyword.fetch!(opts, :id_name)

    # Deletion callback
    on_delete =
      case Keyword.get(opts, :on_delete) do
        nil ->
          []

        callback when is_atom(callback) ->
          quote do
            apply(__MODULE__, unquote(callback), [object, user])
          end
      end

    # For Philomena.Images, this yields Philomena.Images.Subscription
    subscription_module = Module.concat(__CALLER__.module, Subscription)

    quote do
      @doc false
      @spec subscribed?(struct(), Philomena.Users.User.t() | nil) :: boolean()
      def subscribed?(object, user) do
        Philomena.Subscriptions.subscribed?(
          unquote(subscription_module),
          unquote(field_name),
          object,
          user
        )
      end

      @doc false
      @spec subscriptions(Enumerable.t(), Philomena.Users.User.t() | nil) :: %{
              optional(term()) => true
            }
      def subscriptions(objects, user) do
        Philomena.Subscriptions.subscriptions(
          unquote(subscription_module),
          unquote(field_name),
          objects,
          user
        )
      end

      @doc false
      @spec create_subscription(struct(), Philomena.Users.User.t()) ::
              {:ok, struct()} | {:error, Ecto.Changeset.t()}
      def create_subscription(object, user) do
        Philomena.Subscriptions.create_subscription(
          unquote(subscription_module),
          unquote(field_name),
          object,
          user
        )
      end

      @doc false
      @spec delete_subscription(struct(), Philomena.Users.User.t()) :: {:ok, struct()}
      def delete_subscription(object, user) do
        unquote(on_delete)

        Philomena.Subscriptions.delete_subscription(
          unquote(subscription_module),
          unquote(field_name),
          object,
          user
        )
      end

      @doc false
      @spec maybe_subscribe_on(
              Philomena.Multi.t(),
              Philomena.Multi.name(),
              Philomena.Users.User.t() | nil,
              :watch_on_reply | :watch_on_upload | :watch_on_new_topic
            ) :: Philomena.Multi.t()
      def maybe_subscribe_on(multi, change_name, user, field) do
        Philomena.Subscriptions.maybe_subscribe_on(multi, __MODULE__, change_name, user, field)
      end
    end
  end

  @doc false
  @spec subscribed?(module(), atom(), struct(), Philomena.Users.User.t() | nil) :: boolean()
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
  @spec subscriptions(module(), atom(), Enumerable.t(), Philomena.Users.User.t() | nil) :: %{
          optional(term()) => true
        }
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
  @spec create_subscription(module(), atom(), struct(), Philomena.Users.User.t()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def create_subscription(subscription_module, field_name, object, user) do
    struct!(subscription_module, [{field_name, object.id}, {:user_id, user.id}])
    |> subscription_module.changeset(%{})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc false
  @spec delete_subscription(module(), atom(), struct(), Philomena.Users.User.t()) ::
          {:ok, struct()}
  def delete_subscription(subscription_module, field_name, object, user) do
    subscription = struct!(subscription_module, [{field_name, object.id}, {:user_id, user.id}])

    subscription_module
    |> where([s], field(s, ^field_name) == ^object.id and s.user_id == ^user.id)
    |> Repo.delete_all()

    {:ok, subscription}
  end

  @doc false
  @spec maybe_subscribe_on(
          Multi.t(),
          module(),
          Multi.name(),
          Philomena.Users.User.t() | nil,
          :watch_on_reply | :watch_on_upload | :watch_on_new_topic
        ) :: Multi.t()
  def maybe_subscribe_on(multi, module, change_name, user, field)
      when field in [:watch_on_reply, :watch_on_upload, :watch_on_new_topic] do
    case user do
      %{settings: %{^field => true}} ->
        Multi.run(multi, :subscribe, fn _repo, changes ->
          object = Map.fetch!(changes, change_name)
          module.create_subscription(object, user)
        end)

      _ ->
        multi
    end
  end
end
