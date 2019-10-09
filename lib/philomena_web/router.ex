defmodule PhilomenaWeb.Router do
  use PhilomenaWeb, :router
  use Pow.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PhilomenaWeb.Plugs.ImageFilter
    plug PhilomenaWeb.Plugs.Pagination
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  #scope "/" do
  #  pipe_through :browser
  #
  #  pow_routes()
  #end

  scope "/", PhilomenaWeb do
    pipe_through :browser

    get "/", ActivityController, :index

    resources "/activity", ActivityController, only: [:index]
    resources "/images", ImageController, only: [:index, :show]
    resources "/tags", TagController, only: [:index, :show]
    resources "/search", SearchController, only: [:index]
    resources "/forums", ForumController, only: [:index, :show] do
      resources "/topics", TopicController, only: [:show]
    end

    scope "/filters", Filter, as: :filter do
      resources "/current", CurrentController, only: [:update], singular: true
    end
    resources "/filters", FilterController

    get "/:id", ImageController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhilomenaWeb do
  #   pipe_through :api
  # end
end
