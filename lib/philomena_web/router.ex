defmodule PhilomenaWeb.Router do
  use PhilomenaWeb, :router
  use Pow.Phoenix.Router
  use Pow.Extension.Phoenix.Router, otp_app: :philomena

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PhilomenaWeb.Plugs.CurrentFilter
    plug PhilomenaWeb.Plugs.ImageFilter
    plug PhilomenaWeb.Plugs.Pagination
    plug PhilomenaWeb.Plugs.EnsureUserEnabledPlug
    plug PhilomenaWeb.Plugs.CurrentBan
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :ensure_totp do
    plug PhilomenaWeb.Plugs.TotpPlug
  end

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  scope "/" do
    pipe_through [:browser, :ensure_totp]
  
    pow_routes()
    pow_extension_routes()
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :protected]

    # Additional routes for TOTP
    scope "/registrations", Registration, as: :registration do
      resources "/totp", TotpController, only: [:edit, :update], singleton: true
    end

    scope "/sessions", Session, as: :session do
      resources "/totp", TotpController, only: [:new, :create], singleton: true
    end
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :ensure_totp, :protected]

    resources "/notifications", NotificationController, only: [:index, :delete]
    resources "/conversations", ConversationController, only: [:index, :show]
    resources "/images", ImageController, only: [] do
      resources "/vote", Image.VoteController, only: [:create, :delete], singleton: true
      resources "/fave", Image.FaveController, only: [:create, :delete], singleton: true
      resources "/hide", Image.HideController, only: [:create, :delete], singleton: true
    end
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :ensure_totp]

    get "/", ActivityController, :index

    resources "/activity", ActivityController, only: [:index]
    resources "/images", ImageController, only: [:index, :show] do
      resources "/comments", Image.CommentController, only: [:index, :show]
    end
    resources "/tags", TagController, only: [:index, :show]
    resources "/search", SearchController, only: [:index]
    resources "/forums", ForumController, only: [:index, :show] do
      resources "/topics", TopicController, only: [:show]
    end
    resources "/comments", CommentController, only: [:index]

    scope "/filters", Filter, as: :filter do
      resources "/current", CurrentController, only: [:update], singleton: true
    end
    resources "/filters", FilterController
    resources "/profiles", ProfileController, only: [:show]
    resources "/captchas", CaptchaController, only: [:create]

    get "/:id", ImageController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhilomenaWeb do
  #   pipe_through :api
  # end
end
