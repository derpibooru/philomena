defmodule Philomena.Donations do
  @moduledoc """
  Authorized administration of donation records.
  """

  import Ecto.Query, warn: false

  import Philomena.Authorization,
    only: [authorize: 3, verify_not_banned: 1, verify_write_access: 1]

  alias Philomena.Attribution.Actor
  alias Philomena.Authorization
  alias Philomena.Donations.Donation
  alias Philomena.Loader
  alias Philomena.Repo
  alias Philomena.Users.User

  @doc """
  Returns the paginated donation listing for the admin index, on behalf of
  `actor`, newest first, with each donation's user preloaded.

  ## Examples

      iex> list_donations(admin, pagination)
      {:ok, %Scrivener.Page{}}

      iex> list_donations(user, pagination)
      {:error, :unauthorized}

  """
  @spec list_donations(Actor.t(), Repo.pagination_params()) ::
          {:ok, Scrivener.Page.t()} | {:error, :unauthorized}
  def list_donations(%Actor{} = actor, pagination) do
    with :ok <- authorize(actor, :index, Donation) do
      donations =
        Donation
        |> order_by(desc: :created_at, asc: :user_id)
        |> preload(:user)
        |> Repo.paginate(pagination)

      {:ok, donations}
    end
  end

  @doc """
  Loads the user named by `slug` with their donations and a new-donation
  changeset.

  This form loader rejects a banned actor, authorizes the routed `:show` action
  against donations, then loads and authorizes the target user's
  donation history.

  ## Examples

      iex> show_user_donations(admin, user.slug)
      {:ok, {%User{}, %Ecto.Changeset{}}}

      iex> show_user_donations(admin, invalid_slug)
      {:error, :not_found}

      iex> show_user_donations(user, user.slug)
      {:error, :unauthorized}

  """
  @spec show_user_donations(Actor.t(), String.t()) ::
          {:ok, {User.t(), Ecto.Changeset.t()}}
          | {:error, Authorization.write_error_reason() | :not_found}
  def show_user_donations(%Actor{} = actor, slug) do
    user_query =
      User
      |> where(slug: ^slug)
      |> preload(donations: :user)

    with :ok <- verify_not_banned(actor),
         :ok <- authorize(actor, :show, Donation),
         {:ok, user} <- Loader.one(user_query),
         :ok <- authorize(actor, :show_donations, user) do
      {:ok, {user, Donation.changeset(%Donation{})}}
    end
  end

  @doc """
  Creates a donation on behalf of `actor` from `attrs`.

  Verifies write access and authorizes `:create` before inserting. Database and
  validation failures are returned as changesets.

  ## Examples

      iex> create_donation(admin, donation_params)
      {:ok, %Donation{}}

      iex> create_donation(admin, invalid_params)
      {:error, %Ecto.Changeset{}}

      iex> create_donation(user, donation_params)
      {:error, :unauthorized}

  """
  @spec create_donation(Actor.t(), map()) ::
          {:ok, Donation.t()}
          | Authorization.write_error()
          | {:error, Ecto.Changeset.t()}
  def create_donation(%Actor{} = actor, attrs) do
    with :ok <- verify_write_access(actor),
         :ok <- authorize(actor, :create, Donation) do
      %Donation{}
      |> Donation.changeset(attrs)
      |> Repo.insert()
    end
  end
end
