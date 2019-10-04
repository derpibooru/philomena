defmodule PhilomenaWeb.Router do
  use PhilomenaWeb, :router
  use Pow.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
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

    resources "/images", ImageController, only: [:index, :show]
    resources "/tags", TagController, only: [:index, :show]
    resources "/search", SearchController, only: [:index]

    get "/:id", ImageController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhilomenaWeb do
  #   pipe_through :api
  # end
end
