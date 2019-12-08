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
    plug PhilomenaWeb.ContentSecurityPolicyPlug
    plug PhilomenaWeb.CurrentFilterPlug
    plug PhilomenaWeb.ImageFilterPlug
    plug PhilomenaWeb.PaginationPlug
    plug PhilomenaWeb.EnsureUserEnabledPlug
    plug PhilomenaWeb.CurrentBanPlug
    plug PhilomenaWeb.NotificationCountPlug
    plug PhilomenaWeb.SiteNoticePlug
    plug PhilomenaWeb.ForumListPlug
    plug PhilomenaWeb.FilterSelectPlug
    plug PhilomenaWeb.ChannelPlug
    plug PhilomenaWeb.AdminCountersPlug
  end

  pipeline :api do
    plug PhilomenaWeb.ApiTokenPlug
    plug PhilomenaWeb.EnsureUserEnabledPlug
    plug PhilomenaWeb.CurrentFilterPlug
    plug PhilomenaWeb.FilterIdPlug
    plug PhilomenaWeb.ImageFilterPlug
    plug PhilomenaWeb.PaginationPlug
  end

  pipeline :accepts_rss do
    plug :accepts, ["rss"]
  end

  pipeline :accepts_json do
    plug :accepts, ["json"]
  end

  pipeline :ensure_totp do
    plug PhilomenaWeb.TotpPlug
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

  scope "/api/v1/rss", PhilomenaWeb.Api.Rss, as: :api_rss do
    pipe_through [:accepts_rss, :protected, :api]
    resources "/watched", WatchedController, only: [:index]
  end

  scope "/api/v1/json", PhilomenaWeb.Api.Json, as: :api_json do
    pipe_through [:accepts_json, :api]
    resources "/images", ImageController, only: [:show]

    scope "/search", Search, as: :search do
      resources "/reverse", ReverseController, only: [:create]
    end
    resources "/search", SearchController, only: [:index]
    resources "/oembed", OembedController, only: [:index]
    resources "/tags", TagController, only: [:show]
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :ensure_totp, :protected]

    scope "/notifications", Notification, as: :notification do
      resources "/unread", UnreadController, only: [:index]
    end
    resources "/notifications", NotificationController, only: [:index, :delete]
    resources "/conversations", ConversationController, only: [:index, :show, :new, :create] do
      resources "/reports", Conversation.ReportController, only: [:new, :create]
      resources "/messages", Conversation.MessageController, only: [:create]
      resources "/read", Conversation.ReadController, only: [:create, :delete], singleton: true
      resources "/hide", Conversation.HideController, only: [:create, :delete], singleton: true
    end
    resources "/images", ImageController, only: [] do
      resources "/vote", Image.VoteController, only: [:create, :delete], singleton: true
      resources "/fave", Image.FaveController, only: [:create, :delete], singleton: true
      resources "/hide", Image.HideController, only: [:create, :delete], singleton: true
      resources "/subscription", Image.SubscriptionController, only: [:create, :delete], singleton: true
      resources "/read", Image.ReadController, only: [:create], singleton: true
      resources "/comments", Image.CommentController, only: [:edit, :update]
      resources "/delete", Image.DeleteController, only: [:create, :delete], singleton: true
    end

    resources "/forums", ForumController, only: [] do
      resources "/topics", TopicController, only: [:new, :create] do
        resources "/subscription", Topic.SubscriptionController, only: [:create, :delete], singleton: true
        resources "/read", Topic.ReadController, only: [:create], singleton: true
        resources "/posts", Topic.PostController, only: [:edit, :update]
      end

      resources "/subscription", Forum.SubscriptionController, only: [:create, :delete], singleton: true
      resources "/read", Forum.ReadController, only: [:create], singleton: true
    end

    resources "/profiles", ProfileController, only: [] do
      resources "/commission", Profile.CommissionController, only: [:new, :create, :edit, :update, :delete], singleton: true do
        resources "/items", Profile.Commission.ItemController, only: [:new, :create, :edit, :update, :delete]
        resources "/reports", Profile.Commission.ReportController, only: [:new, :create]
      end
      resources "/description", Profile.DescriptionController, only: [:edit, :update], singleton: true
    end

    scope "/filters", Filter, as: :filter do
      resources "/spoiler_type", SpoilerTypeController, only: [:update], singleton: true
      resources "/hide", HideController, only: [:create, :delete], singleton: true
      resources "/spoiler", SpoilerController, only: [:create, :delete], singleton: true
    end

    resources "/tags", TagController, only: [] do
      resources "/watch", Tag.WatchController, only: [:create, :delete], singleton: true
    end

    resources "/avatar", AvatarController, only: [:edit, :update, :delete], singleton: true

    resources "/reports", ReportController, only: [:index]
    resources "/user_links", UserLinkController, only: [:index, :new, :create, :show]
    resources "/galleries", GalleryController, only: [:new, :create, :edit, :update, :delete] do
      resources "/images", Gallery.ImageController, only: [:create, :delete], singleton: true
      resources "/order", Gallery.OrderController, only: [:update], singleton: true
      resources "/read", Gallery.ReadController, only: [:create], singleton: true
      resources "/subscription", Gallery.SubscriptionController, only: [:create, :delete], singleton: true
    end

    resources "/channels", ChannelController, only: [] do
      resources "/read", Channel.ReadController, only: [:create], singleton: true
      resources "/subscription", Channel.SubscriptionController, only: [:create, :delete], singleton: true
    end

    resources "/ip_profiles", IpProfileController, only: [:show]
    resources "/fingerprint_profiles", FingerprintProfileController, only: [:show]
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :ensure_totp]

    get "/", ActivityController, :index

    resources "/activity", ActivityController, only: [:index]
    scope "/images", Image, as: :image do
      resources "/scrape", ScrapeController, only: [:create]
      resources "/random", RandomController, only: [:index]
    end
    resources "/images", ImageController, only: [:index, :show, :new, :create] do
      resources "/comments", Image.CommentController, only: [:index, :show, :create] do
        resources "/reports", Image.Comment.ReportController, only: [:new, :create]
        resources "/history", Image.Comment.HistoryController, only: [:index]
      end
      resources "/tags", Image.TagController, only: [:update], singleton: true
      resources "/sources", Image.SourceController, only: [:update], singleton: true
      resources "/tag_changes", Image.TagChangeController, only: [:index]
      resources "/source_changes", Image.SourceChangeController, only: [:index]
      resources "/description", Image.DescriptionController, only: [:update], singleton: true
      resources "/navigate", Image.NavigateController, only: [:index]
      resources "/reports", Image.ReportController, only: [:new, :create]
      resources "/reporting", Image.ReportingController, only: [:show], singleton: true
      resources "/favorites", Image.FavoritesController, only: [:index]
    end
    scope "/tags", Tag, as: :tag do
      resources "/autocomplete", AutocompleteController, only: [:show], singleton: true
      resources "/fetch", FetchController, only: [:index]
    end
    resources "/tags", TagController, only: [:index, :show] do
      resources "/tag_changes", Tag.TagChangeController, only: [:index]
    end
    scope "/search", Search, as: :search do
      resources "/reverse", ReverseController, only: [:index, :create]
    end
    resources "/search", SearchController, only: [:index]
    resources "/forums", ForumController, only: [:index, :show] do
      resources "/topics", TopicController, only: [:show] do
        resources "/posts", Topic.PostController, only: [:create] do
          resources "/reports", Topic.Post.ReportController, only: [:new, :create]
          resources "/history", Topic.Post.HistoryController, only: [:index]
        end
      end
    end
    resources "/comments", CommentController, only: [:index]

    scope "/filters", Filter, as: :filter do
      resources "/current", CurrentController, only: [:update], singleton: true
    end
    resources "/filters", FilterController
    resources "/profiles", ProfileController, only: [:show] do
      resources "/reports", Profile.ReportController, only: [:new, :create]
      resources "/commission", Profile.CommissionController, only: [:show], singleton: true
      resources "/tag_changes", Profile.TagChangeController, only: [:index]
      resources "/source_changes", Profile.SourceChangeController, only: [:index]
    end
    resources "/captchas", CaptchaController, only: [:create]
    scope "/posts", Post, as: :post do
      resources "/preview", PreviewController, only: [:create]
    end
    resources "/posts", PostController, only: [:index]
    resources "/commissions", CommissionController, only: [:index]
    resources "/galleries", GalleryController, only: [:index, :show] do
      resources "/reports", Gallery.ReportController, only: [:new, :create]
    end
    resources "/adverts", AdvertController, only: [:show]
    resources "/pages", PageController, only: [:show] do
      resources "/history", Page.HistoryController, only: [:index]
    end
    resources "/dnp", DnpEntryController, only: [:index, :show]
    resources "/staff", StaffController, only: [:index]
    resources "/stats", StatController, only: [:index]
    resources "/channels", ChannelController, only: [:index, :show]
    resources "/settings", SettingController, only: [:edit, :update], singleton: true
    resources "/duplicate_reports", DuplicateReportController, only: [:index, :show, :create]

    get "/:id", ImageController, :show
    # get "/:forum_id", ForumController, :show # impossible to do without constraints
    get "/:forum_id/:id", TopicController, :show
    get "/:forum_id/:id/:page", TopicController, :show
    get "/:forum_id/:id/post/:post_id", TopicController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhilomenaWeb do
  #   pipe_through :api
  # end
end
