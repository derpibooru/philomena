defmodule Philomena.StaticPages do
  @moduledoc """
  The StaticPages context.
  """

  import Ecto.Query, warn: false
  alias Philomena.Repo

  alias Philomena.StaticPages.StaticPage

  @doc """
  Returns the list of static_pages.

  ## Examples

      iex> list_static_pages()
      [%StaticPage{}, ...]

  """
  def list_static_pages do
    Repo.all(StaticPage)
  end

  @doc """
  Gets a single static_page.

  Raises `Ecto.NoResultsError` if the Static page does not exist.

  ## Examples

      iex> get_static_page!(123)
      %StaticPage{}

      iex> get_static_page!(456)
      ** (Ecto.NoResultsError)

  """
  def get_static_page!(id), do: Repo.get!(StaticPage, id)

  @doc """
  Creates a static_page.

  ## Examples

      iex> create_static_page(%{field: value})
      {:ok, %StaticPage{}}

      iex> create_static_page(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_static_page(attrs \\ %{}) do
    %StaticPage{}
    |> StaticPage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a static_page.

  ## Examples

      iex> update_static_page(static_page, %{field: new_value})
      {:ok, %StaticPage{}}

      iex> update_static_page(static_page, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_static_page(%StaticPage{} = static_page, attrs) do
    static_page
    |> StaticPage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a StaticPage.

  ## Examples

      iex> delete_static_page(static_page)
      {:ok, %StaticPage{}}

      iex> delete_static_page(static_page)
      {:error, %Ecto.Changeset{}}

  """
  def delete_static_page(%StaticPage{} = static_page) do
    Repo.delete(static_page)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking static_page changes.

  ## Examples

      iex> change_static_page(static_page)
      %Ecto.Changeset{source: %StaticPage{}}

  """
  def change_static_page(%StaticPage{} = static_page) do
    StaticPage.changeset(static_page, %{})
  end
end
