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

  pipeline :ensure_tor_authorized do
    plug PhilomenaWeb.TorPlug
  end

  pipeline :ensure_not_banned do
    plug PhilomenaWeb.FilterBannedUsersPlug
  end

  pipeline :ensure_password_not_compromised do
    plug PhilomenaWeb.CompromisedPasswordCheckPlug
  end

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  scope "/" do
    pipe_through [
      :browser,
      :ensure_totp,
      :ensure_not_banned,
      :ensure_tor_authorized,
      :ensure_password_not_compromised
    ]

    resources "/registration", PhilomenaWeb.Registration.NewController, only: [:create], singleton: true

    pow_registration_routes()
  end

  scope "/" do
    pipe_through [:browser, :ensure_totp]

    pow_session_routes()
  end

  scope "/" do
    pipe_through [:browser, :ensure_totp, :ensure_tor_authorized]

    pow_extension_routes()
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :protected]

    # Additional routes for TOTP
    scope "/registrations", Registration, as: :registration do
      resources "/totp", TotpController, only: [:edit, :update], singleton: true
      resources "/name", NameController, only: [:edit, :update], singleton: true
    end

    scope "/sessions", Session, as: :session do
      resources "/totp", TotpController, only: [:new, :create], singleton: true
    end
  end

  scope "/api/v1/rss", PhilomenaWeb.Api.Rss, as: :api_rss do
    pipe_through [:accepts_rss, :api, :protected]
    resources "/watched", WatchedController, only: [:index]
  end

  scope "/api/v1/json", PhilomenaWeb.Api.Json, as: :api_json do
    pipe_through [:accepts_json, :api, :ensure_tor_authorized]

    scope "/images", Image, as: :image do
      resources "/featured", FeaturedController, only: [:show], singleton: true
    end

    resources "/images", ImageController, only: [:show, :create]

    scope "/search", Search, as: :search do
      resources "/reverse", ReverseController, only: [:create]
      resources "/images", ImageController, only: [:index]
      resources "/tags", TagController, only: [:index]
      resources "/posts", PostController, only: [:index]
      resources "/comments", CommentController, only: [:index]
      resources "/galleries", GalleryController, only: [:index]
    end

    # Convenience alias
    get "/search", Search.ImageController, :index

    resources "/oembed", OembedController, only: [:index]
    resources "/tags", TagController, only: [:show]
    resources "/comments", CommentController, only: [:show]
    resources "/posts", PostController, only: [:show]
    resources "/profiles", ProfileController, only: [:show]

    scope "/filters", Filter, as: :filter do
      resources "/user", UserFilterController, only: [:index]
      resources "/system", SystemFilterController, only: [:index]
    end

    resources "/filters", FilterController, only: [:show]

    resources "/forums", ForumController, only: [:show, :index] do
      resources "/topics", Forum.TopicController, only: [:show, :index] do
        resources "/posts", Forum.Topic.PostController, only: [:show, :index]
      end
    end
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :ensure_totp, :ensure_tor_authorized]

    # A curiosity due to the fact that Phoenix routes cannot have constraints
    scope "/channels", Channel, as: :channel do
      resources "/nsfw", NsfwController, only: [:create, :delete], singleton: true
    end
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

      resources "/subscription", Image.SubscriptionController,
        only: [:create, :delete],
        singleton: true

      resources "/read", Image.ReadController, only: [:create], singleton: true

      resources "/comments", Image.CommentController, only: [:edit, :update] do
        resources "/hide", Image.Comment.HideController, only: [:create, :delete], singleton: true
        resources "/delete", Image.Comment.DeleteController, only: [:create], singleton: true
      end

      resources "/delete", Image.DeleteController,
        only: [:create, :delete, :update],
        singleton: true

      resources "/tamper", Image.TamperController, only: [:create], singleton: true
      resources "/hash", Image.HashController, only: [:delete], singleton: true
      resources "/source_history", Image.SourceHistoryController, only: [:delete], singleton: true
      resources "/repair", Image.RepairController, only: [:create], singleton: true
      resources "/feature", Image.FeatureController, only: [:create], singleton: true
      resources "/file", Image.FileController, only: [:update], singleton: true
      resources "/scratchpad", Image.ScratchpadController, only: [:edit, :update], singleton: true
      resources "/uploader", Image.UploaderController, only: [:update], singleton: true
      resources "/anonymous", Image.AnonymousController, only: [:create, :delete], singleton: true

      resources "/comment_lock", Image.CommentLockController,
        only: [:create, :delete],
        singleton: true

      resources "/description_lock", Image.DescriptionLockController,
        only: [:create, :delete],
        singleton: true

      resources "/tag_lock", Image.TagLockController, only: [:create, :delete], singleton: true
    end

    resources "/forums", ForumController, only: [] do
      resources "/topics", TopicController, only: [:new, :create, :update] do
        resources "/subscription", Topic.SubscriptionController,
          only: [:create, :delete],
          singleton: true

        resources "/read", Topic.ReadController, only: [:create], singleton: true
        resources "/move", Topic.MoveController, only: [:create], singleton: true
        resources "/stick", Topic.StickController, only: [:create, :delete], singleton: true
        resources "/lock", Topic.LockController, only: [:create, :delete], singleton: true
        resources "/hide", Topic.HideController, only: [:create, :delete], singleton: true

        resources "/posts", Topic.PostController, only: [:edit, :update] do
          resources "/hide", Topic.Post.HideController, only: [:create, :delete], singleton: true
          resources "/delete", Topic.Post.DeleteController, only: [:create], singleton: true
        end

        resources "/poll", Topic.PollController, only: [:edit, :update], singleton: true do
          resources "/votes", Topic.Poll.VoteController, only: [:index, :create, :delete]
        end
      end

      resources "/subscription", Forum.SubscriptionController,
        only: [:create, :delete],
        singleton: true

      resources "/read", Forum.ReadController, only: [:create], singleton: true
    end

    resources "/profiles", ProfileController, only: [] do
      resources "/commission", Profile.CommissionController,
        only: [:new, :create, :edit, :update, :delete],
        singleton: true do
        resources "/items", Profile.Commission.ItemController,
          only: [:new, :create, :edit, :update, :delete]

        resources "/reports", Profile.Commission.ReportController, only: [:new, :create]
      end

      resources "/description", Profile.DescriptionController,
        only: [:edit, :update],
        singleton: true

      resources "/scratchpad", Profile.ScratchpadController,
        only: [:edit, :update],
        singleton: true

      resources "/user_links", Profile.UserLinkController
      resources "/awards", Profile.AwardController, except: [:index, :show]

      resources "/details", Profile.DetailController, only: [:index]
      resources "/ip_history", Profile.IpHistoryController, only: [:index]
      resources "/fp_history", Profile.FpHistoryController, only: [:index]
      resources "/aliases", Profile.AliasController, only: [:index]
    end

    scope "/filters", Filter, as: :filter do
      resources "/spoiler_type", SpoilerTypeController, only: [:update], singleton: true
      resources "/hide", HideController, only: [:create, :delete], singleton: true
      resources "/spoiler", SpoilerController, only: [:create, :delete], singleton: true
    end

    resources "/tags", TagController, only: [] do
      resources "/watch", Tag.WatchController, only: [:create, :delete], singleton: true
      resources "/details", Tag.DetailController, only: [:index]
    end

    resources "/avatar", AvatarController, only: [:edit, :update, :delete], singleton: true

    resources "/reports", ReportController, only: [:index]

    resources "/galleries", GalleryController, only: [:new, :create, :edit, :update, :delete] do
      resources "/images", Gallery.ImageController, only: [:create, :delete], singleton: true
      resources "/order", Gallery.OrderController, only: [:update], singleton: true
      resources "/read", Gallery.ReadController, only: [:create], singleton: true

      resources "/subscription", Gallery.SubscriptionController,
        only: [:create, :delete],
        singleton: true
    end

    resources "/channels", ChannelController, only: [] do
      resources "/read", Channel.ReadController, only: [:create], singleton: true

      resources "/subscription", Channel.SubscriptionController,
        only: [:create, :delete],
        singleton: true
    end

    resources "/dnp", DnpEntryController, only: [:new, :create, :edit, :update]

    resources "/ip_profiles", IpProfileController, only: [:show] do
      resources "/tag_changes", IpProfile.TagChangeController, only: [:index]
      resources "/source_changes", IpProfile.SourceChangeController, only: [:index]
    end

    resources "/fingerprint_profiles", FingerprintProfileController, only: [:show] do
      resources "/tag_changes", FingerprintProfile.TagChangeController, only: [:index]
      resources "/source_changes", FingerprintProfile.SourceChangeController, only: [:index]
    end

    scope "/admin", Admin, as: :admin do
      resources "/reports", ReportController, only: [:index, :show] do
        resources "/claim", Report.ClaimController, only: [:create, :delete], singleton: true
        resources "/close", Report.CloseController, only: [:create], singleton: true
      end

      resources "/user_links", UserLinkController, only: [:index] do
        resources "/verification", UserLink.VerificationController,
          only: [:create],
          singleton: true

        resources "/contact", UserLink.ContactController, only: [:create], singleton: true
        resources "/reject", UserLink.RejectController, only: [:create], singleton: true
      end

      resources "/dnp_entries", DnpEntryController, only: [:index] do
        resources "/transition", DnpEntry.TransitionController, only: [:create], singleton: true
      end

      resources "/user_bans", UserBanController,
        only: [:index, :new, :create, :edit, :update, :delete]

      resources "/subnet_bans", SubnetBanController,
        only: [:index, :new, :create, :edit, :update, :delete]

      resources "/fingerprint_bans", FingerprintBanController,
        only: [:index, :new, :create, :edit, :update, :delete]

      resources "/site_notices", SiteNoticeController, except: [:show]

      resources "/adverts", AdvertController, except: [:show] do
        resources "/image", Advert.ImageController, only: [:edit, :update], singleton: true
      end

      resources "/forums", ForumController, except: [:show, :delete]

      resources "/badges", BadgeController, except: [:show, :delete] do
        resources "/users", Badge.UserController, only: [:index]
        resources "/image", Badge.ImageController, only: [:edit, :update], singleton: true
      end

      resources "/mod_notes", ModNoteController, except: [:show]

      resources "/users", UserController, only: [:index, :edit, :update] do
        resources "/avatar", User.AvatarController, only: [:delete], singleton: true

        resources "/activation", User.ActivationController,
          only: [:create, :delete],
          singleton: true

        resources "/api_key", User.ApiKeyController, only: [:delete], singleton: true
        resources "/downvotes", User.DownvoteController, only: [:delete], singleton: true
        resources "/votes", User.VoteController, only: [:delete], singleton: true
        resources "/wipe", User.WipeController, only: [:create], singleton: true

        resources "/force_filter", User.ForceFilterController,
          only: [:new, :create, :delete],
          singleton: true
      end

      resources "/batch/tags", Batch.TagController, only: [:update], singleton: true

      scope "/donations", Donation, as: :donation do
        resources "/user", UserController, only: [:show]
      end

      resources "/donations", DonationController, only: [:index, :create]
    end

    resources "/duplicate_reports", DuplicateReportController, only: [] do
      resources "/accept", DuplicateReport.AcceptController, only: [:create], singleton: true

      resources "/accept_reverse", DuplicateReport.AcceptReverseController,
        only: [:create],
        singleton: true

      resources "/reject", DuplicateReport.RejectController, only: [:create], singleton: true

      resources "/claim", DuplicateReport.ClaimController,
        only: [:create, :delete],
        singleton: true
    end

    resources "/tags", TagController, only: [:edit, :update, :delete] do
      resources "/image", Tag.ImageController, only: [:edit, :update, :delete], singleton: true
      resources "/alias", Tag.AliasController, only: [:edit, :update, :delete], singleton: true
      resources "/reindex", Tag.ReindexController, only: [:create], singleton: true
    end

    resources "/tag_changes/revert", TagChange.RevertController,
      as: :tag_change_revert,
      only: [:create],
      singleton: true

    resources "/pages", PageController, only: [:index, :new, :create, :edit, :update]
    resources "/channels", ChannelController, only: [:new, :create, :edit, :update, :delete]
  end

  scope "/", PhilomenaWeb do
    pipe_through [:browser, :ensure_totp, :ensure_tor_authorized]

    get "/", ActivityController, :index

    resources "/activity", ActivityController, only: [:index]

    scope "/images", Image, as: :image do
      resources "/scrape", ScrapeController, only: [:create]
      resources "/random", RandomController, only: [:index]
    end

    resources "/images", ImageController, only: [:index, :show, :new, :create] do
      resources "/related", Image.RelatedController, only: [:index]

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
      resources "/favorites", Image.FavoriteController, only: [:index]
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

    resources "/filters", FilterController do
      resources "/public", Filter.PublicController, only: [:create], singleton: true
    end

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
