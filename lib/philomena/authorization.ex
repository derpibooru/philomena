defmodule Philomena.Authorization do
  @moduledoc """
  The single authorization entry point for context functions.

  Context functions call `authorize/3` at the start of a write
  (or before returning a loaded record on a read).

  This is a thin wrapper over Canada: the permission rules themselves remain the
  single source of truth in `Philomena.Users.Ability` (`lib/philomena/users/ability.ex`).

  The actor is permitted to be `nil` (an anonymous visitor).
  """

  alias Philomena.Attribution.Actor
  alias Philomena.Users.User

  @typedoc "Type of acceptable actor inputs."
  @type actor :: Actor.t() | User.t() | nil

  @typedoc "The normalized reason returned by a failed ability check."
  @type error_reason :: :unauthorized

  @typedoc "The normalized failure returned by an ability check."
  @type error :: {:error, error_reason()}

  @typedoc "Reasons returned by the global write prerequisite."
  @type write_error_reason :: :ban | error_reason()

  @typedoc "Failures returned by the global write prerequisite."
  @type write_error :: {:error, write_error_reason()}

  @doc """
  Authorizes `actor` to perform `action` on `subject`.

  Returns `:ok` when Canada permits the action, otherwise
  `{:error, :unauthorized}`.

  `actor` may be `nil` for an anonymous visitor. It may also be a
  `Philomena.Attribution.Actor`: permissions are decided by its `user` alone -
  the IP and fingerprint attribute the action but grant nothing - so contexts
  that take an attribution can pass it here unchanged.

  ## Examples

      iex> authorize(user, :hide, image)
      :ok

      iex> authorize(nil, :hide, image)
      {:error, :unauthorized}

      iex> authorize(%Actor{user: moderator, ip: ip}, :revert, TagChange)
      :ok

  """
  @spec authorize(actor :: actor(), action :: atom(), subject :: any()) ::
          :ok | error()
  def authorize(%Actor{user: user}, action, subject), do: authorize(user, action, subject)

  def authorize(actor, action, subject) do
    if Canada.Can.can?(actor, action, subject), do: :ok, else: {:error, :unauthorized}
  end

  @doc """
  Verifies that `actor` may perform a write.

  Decides, in order:

    * `{:error, :ban}` when the actor carries an active ban;
    * `{:error, :unauthorized}` when the actor has no fingerprint;
    * `:ok` otherwise.

  The fingerprint requirement applies regardless of whether a user is signed in.

  ## Deliberate exceptions

  These personal preference actions intentionally permit banned users:

  - Switching the current filter
  - Clearing recent filters
  - Changing the active spoiler type
  - Clearing notifications
  - Updating user settings
  - Watching/unwatching tags
  - Creating/deleting subscriptions

  The actions still perform their own authentication and resource
  authorization checks.
  """
  @spec verify_write_access(actor :: Actor.t()) :: :ok | write_error()
  def verify_write_access(%Actor{ban: ban}) when not is_nil(ban), do: {:error, :ban}
  def verify_write_access(%Actor{fingerprint: nil}), do: {:error, :unauthorized}
  def verify_write_access(%Actor{}), do: :ok

  @doc """
  Verifies that `actor` may be offered a write, for pages and forms that
  prepare one.

  Returns `{:error, :ban}` when the actor carries an active ban, otherwise
  `:ok`. Unlike `verify_write_access/1` it does not require a fingerprint,
  which a visitor's first request lacks; the write itself still does.
  """
  @spec verify_not_banned(actor :: Actor.t()) :: :ok | {:error, :ban}
  def verify_not_banned(%Actor{ban: nil}), do: :ok
  def verify_not_banned(%Actor{}), do: {:error, :ban}
end
