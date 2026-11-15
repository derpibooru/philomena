# Permissions for logged-in users.
defimpl Canada.Can, for: Philomena.Users.User do
  alias Philomena.Activities.FrontPage
  alias Philomena.Adverts.Advert
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Badges.Award
  alias Philomena.Badges.Badge
  alias Philomena.Bans
  alias Philomena.Channels.Channel
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.Conversations.Message
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Filters.Filter
  alias Philomena.Forums.Forum
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.ModerationLogs.ModerationLog
  alias Philomena.ModNotes.ModNote
  alias Philomena.Posts.Post
  alias Philomena.Reports.Report
  alias Philomena.Roles.Role
  alias Philomena.Rules.Rule
  alias Philomena.SiteNotices.SiteNotice
  alias Philomena.SourceChanges.SourceChange
  alias Philomena.StaticPages.StaticPage
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags.Tag
  alias Philomena.Topics.Topic
  alias Philomena.UserNameChanges.UserNameChange
  alias Philomena.Users.User

  @award_class_actions [:new, :create]
  @award_member_actions [:edit, :update, :delete]
  @badge_class_actions [:index, :new, :create]
  @badge_member_actions [:edit, :update, :update_image, :show_users]
  @commission_management_actions [
    :new,
    :create,
    :edit,
    :update,
    :delete,
    :new_item,
    :create_item,
    :edit_item,
    :update_item,
    :delete_item
  ]
  @conversation_class_actions [:index, :new, :create]
  @topic_moderation_actions [
    :show,
    :subscribe,
    :unsubscribe,
    :mark_read,
    :stick,
    :unstick,
    :lock,
    :unlock,
    :move,
    :hide,
    :unhide,
    :update_title,
    :edit_poll,
    :update_poll,
    :list_poll_votes,
    :delete_poll_vote
  ]
  @post_moderation_actions [:edit, :update, :hide, :unhide, :approve]
  @tag_moderation_actions [
    :edit,
    :update,
    :edit_image,
    :update_image,
    :delete_image,
    :show_details
  ]
  @dnp_entry_class_actions [:index, :new, :create, :select_any_tag]
  @dnp_entry_member_actions [
    :show,
    :show_reason,
    :show_feedback,
    :edit,
    :update,
    :transition
  ]
  @duplicate_report_member_actions [:show, :accept, :accept_reverse, :claim, :unclaim, :reject]
  @user_management_actions [
    :index,
    :edit,
    :update,
    :reactivate,
    :deactivate,
    :reset_api_key,
    :remove_avatar,
    :wipe_downvotes,
    :erase,
    :force_filter,
    :unforce_filter,
    :unlock,
    :verify,
    :unverify,
    :wipe_votes,
    :wipe
  ]

  # Admins can do anything
  def can?(%User{role: "admin"}, _action, _model), do: true

  #
  # Moderators can...
  #

  # Show details of profiles and view user list
  def can?(%User{role: "moderator"}, :show_details, %User{}), do: true
  def can?(%User{role: "moderator"}, :edit_description, %User{}), do: true
  def can?(%User{role: "moderator"}, :index, User), do: true

  # View filters
  def can?(%User{role: "moderator"}, :show, %Filter{}), do: true
  def can?(%User{role: "moderator"}, :search_all, Filter), do: true

  # Privileged mods can hard-delete images
  def can?(%User{role: "moderator", role_map: %{"Image" => %{"admin" => _}}}, :destroy, %Image{}),
    do: true

  # ...but normal ones cannot
  def can?(%User{role: "moderator"}, :destroy, %Image{}), do: false

  # Manage images
  def can?(%User{role: "moderator"}, _action, Image), do: true
  def can?(%User{role: "moderator"}, _action, %Image{}), do: true

  # Manage channels
  def can?(%User{role: "moderator"}, _action, Channel), do: true
  def can?(%User{role: "moderator"}, _action, %Channel{}), do: true

  # View comments
  def can?(%User{role: "moderator"}, :show, %Comment{}), do: true
  def can?(%User{role: "moderator"}, :search_sensitive, Comment), do: true

  # View forums
  def can?(%User{role: "moderator"}, action, %Forum{})
      when action in [:show, :subscribe, :unsubscribe, :create_topic],
      do: true

  def can?(%User{role: "moderator"}, :show, %Topic{hidden_from_users: true}), do: true

  def can?(%User{role: "moderator"}, :show, %Post{}), do: true

  # View and approve conversations
  def can?(%User{role: "moderator"}, :show, %Conversation{}), do: true
  def can?(%User{role: "moderator"}, :reply, %Conversation{}), do: true
  def can?(%User{role: "moderator"}, :approve, %Message{}), do: true

  # View sensitive identity metadata such as IP addresses and fingerprints
  def can?(%User{role: "moderator"}, :show, :identity_metadata), do: true

  # Manage duplicate reports
  def can?(%User{role: "moderator"}, :index, DuplicateReport), do: true

  def can?(%User{role: "moderator"}, action, %DuplicateReport{})
      when action in @duplicate_report_member_actions,
      do: true

  # Manage reports
  def can?(%User{role: "moderator"}, :index, Report), do: true

  def can?(%User{role: "moderator"}, action, %Report{})
      when action in [:show, :claim, :unclaim, :close],
      do: true

  def can?(%User{role: role}, :bypass_submission_limit, Report)
      when role in ["assistant", "moderator"],
      do: true

  # Manage artist links
  def can?(%User{role: "moderator"}, :create_links, %User{}), do: true
  def can?(%User{role: "moderator"}, :edit_links, %User{}), do: true

  def can?(%User{role: "moderator"}, :index, ArtistLink), do: true

  def can?(%User{role: "moderator"}, action, %ArtistLink{})
      when action in [:show, :edit, :update, :verify, :reject, :contact],
      do: true

  # Reveal anon users
  def can?(%User{role: "moderator"}, :reveal_anon, _object), do: true

  # Edit posts and comments
  def can?(%User{role: "moderator"}, action, %Post{})
      when action in @post_moderation_actions,
      do: true

  def can?(%User{role: "moderator"}, :delete, %Post{}), do: true

  def can?(%User{role: "moderator"}, action, %Comment{}) when action in [:edit, :update],
    do: true

  def can?(%User{role: "moderator"}, :hide, %Comment{}), do: true
  def can?(%User{role: "moderator"}, :delete, %Comment{}), do: true
  def can?(%User{role: "moderator"}, :approve, %Comment{}), do: true

  # Manage DNP entries
  def can?(%User{role: "moderator"}, action, DnpEntry)
      when action in @dnp_entry_class_actions,
      do: true

  def can?(%User{role: "moderator"}, action, %DnpEntry{})
      when action in @dnp_entry_member_actions,
      do: true

  # Manage bans, but not delete them
  @ban_management_actions [:index, :new, :create, :edit, :update]

  def can?(%User{role: "moderator"}, action, Bans.User)
      when action in @ban_management_actions,
      do: true

  def can?(%User{role: "moderator"}, action, %Bans.User{})
      when action in @ban_management_actions,
      do: true

  def can?(%User{role: "moderator"}, action, Bans.Subnet)
      when action in @ban_management_actions,
      do: true

  def can?(%User{role: "moderator"}, action, %Bans.Subnet{})
      when action in @ban_management_actions,
      do: true

  def can?(%User{role: "moderator"}, action, Bans.Fingerprint)
      when action in @ban_management_actions,
      do: true

  def can?(%User{role: "moderator"}, action, %Bans.Fingerprint{})
      when action in @ban_management_actions,
      do: true

  # Hide topics
  def can?(%User{role: "moderator"}, action, %Topic{})
      when action in @topic_moderation_actions,
      do: true

  def can?(%User{role: "moderator"}, :create_post, %Topic{}), do: true

  # Moderate tags
  def can?(%User{role: "moderator"}, action, %Tag{})
      when action in @tag_moderation_actions,
      do: true

  # Award badges
  def can?(%User{role: "moderator"}, action, %Award{})
      when action in @award_member_actions,
      do: true

  def can?(%User{role: "moderator"}, action, Award) when action in @award_class_actions,
    do: true

  # Revert tag changes
  def can?(%User{role: "moderator"}, :squash, SourceChange), do: true
  def can?(%User{role: "moderator"}, :squash, TagChange), do: true

  def can?(%User{role: "moderator"}, :index, TagChange), do: true
  def can?(%User{role: "moderator"}, :revert, TagChange), do: true
  def can?(%User{role: "moderator"}, :delete, %TagChange{}), do: true

  # Manage commissions
  def can?(%User{role: "moderator"}, action, %Commission{})
      when action in @commission_management_actions,
      do: true

  # Manage galleries
  def can?(%User{role: "moderator"}, _action, %Gallery{}), do: true

  # See moderation logs
  def can?(%User{role: "moderator"}, _action, ModerationLog), do: true

  # View user name changes
  def can?(%User{role: "moderator"}, :index, UserNameChange), do: true

  # And some privileged moderators can...

  # Manage site notices
  def can?(
        %User{role: "moderator", role_map: %{"SiteNotice" => %{"admin" => _}}},
        _action,
        SiteNotice
      ),
      do: true

  def can?(
        %User{role: "moderator", role_map: %{"SiteNotice" => %{"admin" => _}}},
        _action,
        %SiteNotice{}
      ),
      do: true

  # Manage badges
  def can?(
        %User{role: "moderator", role_map: %{"Badge" => %{"admin" => _}}},
        action,
        Badge
      )
      when action in @badge_class_actions,
      do: true

  def can?(
        %User{role: "moderator", role_map: %{"Badge" => %{"admin" => _}}},
        action,
        %Badge{}
      )
      when action in @badge_member_actions,
      do: true

  # Manage tags
  def can?(%User{role: "moderator", role_map: %{"Tag" => %{"admin" => _}}}, _action, Tag),
    do: true

  def can?(%User{role: "moderator", role_map: %{"Tag" => %{"admin" => _}}}, _action, %Tag{}),
    do: true

  # Manage user roles
  def can?(%User{role: "moderator", role_map: %{"Role" => %{"admin" => _}}}, _action, %Role{}),
    do: true

  # Manage users
  def can?(%User{role: "moderator", role_map: %{"User" => %{"moderator" => _}}}, action, User)
      when action in @user_management_actions,
      do: true

  def can?(
        %User{role: "moderator", role_map: %{"User" => %{"moderator" => _}}},
        action,
        %User{}
      )
      when action in @user_management_actions,
      do: true

  # Manage advertisements
  @advert_class_actions [:index, :new, :create]
  @advert_member_actions [:edit, :update, :update_image, :delete]

  def can?(
        %User{role: "moderator", role_map: %{"Advert" => %{"admin" => _}}},
        action,
        Advert
      )
      when action in @advert_class_actions,
      do: true

  def can?(
        %User{role: "moderator", role_map: %{"Advert" => %{"admin" => _}}},
        action,
        %Advert{}
      )
      when action in @advert_member_actions,
      do: true

  # Manage static pages
  def can?(
        %User{role: "moderator", role_map: %{"StaticPage" => %{"admin" => _}}},
        _action,
        StaticPage
      ),
      do: true

  def can?(
        %User{role: "moderator", role_map: %{"StaticPage" => %{"admin" => _}}},
        _action,
        %StaticPage{}
      ),
      do: true

  #
  # Both assistants and moderators can...
  #

  # Read and create mod notes
  def can?(%User{role: role}, action, ModNote)
      when role in ~W(assistant moderator) and action in [:index, :new, :create],
      do: true

  # Update and delete their own mod notes
  def can?(%User{id: id, role: role}, action, %ModNote{moderator_id: id})
      when role in ~W(assistant moderator) and action in [:edit, :update, :delete],
      do: true

  # Read or annotate mod note targets
  @mod_note_target_actions [:show_mod_notes, :annotate]

  def can?(%User{role: role}, action, %User{})
      when role in ~W(assistant moderator) and action in @mod_note_target_actions,
      do: true

  def can?(%User{role: role}, :edit_scratchpad, %User{})
      when role in ~W(assistant moderator),
      do: true

  def can?(%User{role: role}, action, %Report{})
      when role in ~W(assistant moderator) and action in @mod_note_target_actions,
      do: true

  def can?(%User{role: role}, action, %DnpEntry{})
      when role in ~W(assistant moderator) and action in @mod_note_target_actions,
      do: true

  #
  # Assistants can...
  #

  # Image assistant actions
  def can?(
        %User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}},
        :show,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}},
        :hide,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}},
        :edit,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}},
        :edit_metadata,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}},
        :edit_description,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}},
        :approve,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}},
        action,
        %Image{}
      )
      when action in [
             :feature,
             :lock_comments,
             :lock_description,
             :lock_tags,
             :remove_hash,
             :edit_scratchpad,
             :remove_source_history,
             :repair,
             :replace_file,
             :update_hide_reason,
             :unhide
           ],
      do: true

  # Dupe assistant actions
  def can?(
        %User{role: "assistant", role_map: %{"DuplicateReport" => %{"moderator" => _}}},
        :index,
        DuplicateReport
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"DuplicateReport" => %{"moderator" => _}}},
        action,
        %DuplicateReport{}
      )
      when action in @duplicate_report_member_actions,
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"DuplicateReport" => %{"moderator" => _}}},
        :show,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"DuplicateReport" => %{"moderator" => _}}},
        :edit,
        %Image{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"DuplicateReport" => %{"moderator" => _}}},
        :hide,
        %Comment{}
      ),
      do: true

  # Comment assistant actions
  def can?(
        %User{role: "assistant", role_map: %{"Comment" => %{"moderator" => _}}},
        :show,
        %Comment{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Comment" => %{"moderator" => _}}},
        action,
        %Comment{}
      )
      when action in [:edit, :update],
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Comment" => %{"moderator" => _}}},
        :hide,
        %Comment{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Comment" => %{"moderator" => _}}},
        :approve,
        %Comment{}
      ),
      do: true

  # Topic assistant actions
  def can?(
        %User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}},
        action,
        %Topic{}
      )
      when action in @topic_moderation_actions,
      do: true

  def can?(%User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}}, :show, %Post{}),
    do: true

  def can?(
        %User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}},
        action,
        %Post{}
      )
      when action in @post_moderation_actions,
      do: true

  # Tag assistant actions
  def can?(%User{role: "assistant", role_map: %{"Tag" => %{"moderator" => _}}}, action, %Tag{})
      when action in @tag_moderation_actions,
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"Tag" => %{"moderator" => _}}},
        :batch_update,
        Tag
      ),
      do: true

  # Artist link assistant actions
  def can?(
        %User{role: "assistant", role_map: %{"ArtistLink" => %{"moderator" => _}}},
        _action,
        %ArtistLink{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"ArtistLink" => %{"moderator" => _}}},
        :create_links,
        %User{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"ArtistLink" => %{"moderator" => _}}},
        :edit,
        %ArtistLink{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"ArtistLink" => %{"moderator" => _}}},
        :edit_links,
        %User{}
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"ArtistLink" => %{"moderator" => _}}},
        :index,
        ArtistLink
      ),
      do: true

  # View forums
  def can?(%User{role: "assistant"}, action, %Forum{access_level: level})
      when action in [:show, :subscribe, :unsubscribe, :create_topic] and
             level in ["normal", "assistant"],
      do: true

  def can?(%User{role: "assistant"}, :show, %Topic{hidden_from_users: true}), do: true

  #
  # Regular users can...

  def can?(%User{}, :index, TagChange), do: true

  # View their own reports
  def can?(%User{}, :index_own, Report), do: true
  #

  # Batch tag
  def can?(%User{role_map: %{"Tag" => %{"batch_update" => _}}}, :batch_update, Tag), do: true

  # Edit their description and personal title
  def can?(%User{id: id}, :edit_description, %User{id: id}), do: true
  def can?(%User{id: id}, :edit_title, %User{id: id}), do: true
  def can?(%User{id: id}, :deactivate_account, %User{id: id}), do: true

  # Update their personal filter settings
  def can?(%User{id: id}, :update_spoiler_type, %User{id: id}), do: true
  def can?(%User{id: id}, :delete_recent_filters, %User{id: id}), do: true

  # Edit their username
  def can?(%User{id: id}, :change_username, %User{id: id} = user) do
    time_ago = DateTime.utc_now() |> DateTime.add(-1 * 60 * 60 * 24 * 90)
    DateTime.diff(user.last_renamed_at, time_ago) < 0
  end

  # List and create conversations, and view/reply to ones they participate in.
  def can?(%User{}, action, Conversation) when action in @conversation_class_actions, do: true
  def can?(%User{id: id}, :show, %Conversation{to_id: id}), do: true
  def can?(%User{id: id}, :show, %Conversation{from_id: id}), do: true
  def can?(%User{id: id}, :reply, %Conversation{to_id: id}), do: true
  def can?(%User{id: id}, :reply, %Conversation{from_id: id}), do: true

  # View filters they own and public/system filters
  def can?(%User{}, :show, %Filter{system: true}), do: true
  def can?(%User{}, :show, %Filter{public: true}), do: true

  def can?(%User{}, action, Filter)
      when action in [:index, :index_system, :index_own, :search, :switch, :new, :create],
      do: true

  # View the homepage
  def can?(%User{}, :show, FrontPage), do: true

  def can?(%User{id: id}, action, %Filter{user_id: id})
      when action in [
             :show,
             :edit,
             :update,
             :publish,
             :delete,
             :hide_tag,
             :unhide_tag,
             :spoiler_tag,
             :unspoiler_tag
           ],
      do: true

  # View artist links they've created
  def can?(%User{id: id}, :create_links, %User{id: id}), do: true
  def can?(%User{id: id}, :show, %ArtistLink{user_id: id}), do: true

  # View the directory/listings and manage their own commission
  def can?(%User{}, :index, Commission), do: true
  def can?(%User{}, :show, %Commission{}), do: true

  def can?(%User{id: id}, action, %Commission{user_id: id})
      when action in @commission_management_actions,
      do: true

  # View non-deleted and watched images
  def can?(%User{}, action, Image)
      when action in [:new, :create, :index, :index_watched],
      do: true

  def can?(%User{}, action, %Image{hidden_from_users: false})
      when action in [:show, :index, :subscribe, :unsubscribe],
      do: true

  # Users must be able to dismiss notifications even after an image is hidden.
  def can?(%User{}, :mark_read, %Image{}), do: true

  # Submit and inspect duplicate reports involving visible images.
  def can?(%User{}, action, DuplicateReport) when action in [:create, :search], do: true
  def can?(%User{}, :show, %DuplicateReport{}), do: true

  def can?(%User{}, :index, Tag), do: true
  def can?(%User{}, :show, %Tag{}), do: true

  # Comment on images where that is allowed
  def can?(%User{}, :create_comment, %Image{hidden_from_users: false, commenting_allowed: true}),
    do: true

  # Edit comments on images
  def can?(%User{id: id}, action, %Comment{hidden_from_users: false, user_id: id})
      when action in [:edit, :update],
      do: true

  # Edit metadata on images where that is allowed
  def can?(%User{}, :edit_metadata, %Image{hidden_from_users: false, tag_editing_allowed: true}),
    do: true

  def can?(%User{id: id}, :edit_description, %Image{
        user_id: id,
        hidden_from_users: false,
        description_editing_allowed: true
      }),
      do: true

  # Vote on images they can see
  def can?(%User{} = user, :vote, image), do: can?(user, :show, image)

  # View non-deleted comments
  def can?(%User{}, :show, %Comment{hidden_from_users: false}), do: true

  # View forums
  def can?(%User{}, :index, Forum), do: true

  def can?(%User{}, action, %Forum{access_level: "normal"})
      when action in [:show, :subscribe, :unsubscribe, :create_topic],
      do: true

  def can?(%User{}, action, %Topic{hidden_from_users: false})
      when action in [:show, :subscribe, :unsubscribe, :mark_read, :vote],
      do: true

  def can?(%User{}, action, %Topic{}) when action in [:unsubscribe, :mark_read], do: true
  def can?(%User{}, :show, %Post{hidden_from_users: false}), do: true

  # Create and edit posts
  def can?(%User{}, :create_post, %Topic{locked_at: nil, hidden_from_users: false}), do: true

  def can?(%User{id: id}, action, %Post{hidden_from_users: false, user_id: id})
      when action in [:edit, :update],
      do: true

  # View profile pages
  def can?(%User{}, :show, %User{}), do: true

  # View and create DNP entries
  def can?(%User{}, action, DnpEntry) when action in [:new, :create], do: true
  def can?(%User{id: id}, :show, %DnpEntry{requesting_user_id: id}), do: true
  def can?(%User{id: id}, :show_reason, %DnpEntry{requesting_user_id: id}), do: true
  def can?(%User{id: id}, :show_feedback, %DnpEntry{requesting_user_id: id}), do: true

  def can?(%User{}, :show, %DnpEntry{aasm_state: "listed"}), do: true
  def can?(%User{}, :show_reason, %DnpEntry{aasm_state: "listed", hide_reason: false}), do: true

  # Create and edit galleries
  def can?(%User{}, :show, %Gallery{}), do: true

  def can?(%User{}, action, Gallery)
      when action in [:index, :search, :new, :create, :select_for_image],
      do: true

  def can?(%User{}, action, %Gallery{}) when action in [:subscribe, :unsubscribe, :mark_read],
    do: true

  def can?(%User{id: id}, action, %Gallery{user_id: id})
      when action in [:edit, :update, :delete, :add_image, :remove_image, :reorder],
      do: true

  # Index and show public rules
  def can?(%User{} = user, :show, %Rule{hidden: hidden, internal: internal} = rule)
      when hidden or internal,
      do: can?(user, :edit, rule)

  def can?(%User{}, action, %Rule{}) when action in [:index, :show], do: true

  # Show static pages
  def can?(%User{}, :show, %StaticPage{}), do: true

  # View channels and manage personal channel state
  def can?(%User{}, action, %Channel{})
      when action in [:show, :visit, :mark_read, :subscribe, :unsubscribe],
      do: true

  # Otherwise...
  def can?(%User{}, _action, _model), do: false
end

# Permissions for non-logged-in users.
defimpl Canada.Can, for: Atom do
  alias Philomena.Activities.FrontPage
  alias Philomena.Channels.Channel
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.Filters.Filter
  alias Philomena.Forums.Forum
  alias Philomena.Galleries.Gallery
  alias Philomena.Images.Image
  alias Philomena.Posts.Post
  alias Philomena.Rules.Rule
  alias Philomena.StaticPages.StaticPage
  alias Philomena.TagChanges.TagChange
  alias Philomena.Tags.Tag
  alias Philomena.Topics.Topic
  alias Philomena.Users.User

  #
  # Anonymous / non-logged-in users can...

  def can?(_user, :index, TagChange), do: true
  def can?(_user, :index, Tag), do: true
  #

  # View the assembled homepage
  def can?(_user, :show, FrontPage), do: true

  # View filters they own and public/system filters
  def can?(_user, action, Filter) when action in [:index, :index_system, :search, :switch],
    do: true

  def can?(_user, :show, %Filter{system: true}), do: true
  def can?(_user, :show, %Filter{public: true}), do: true

  # View non-deleted images
  def can?(_user, action, Image)
      when action in [:new, :create, :index],
      do: true

  def can?(_user, action, %Image{hidden_from_users: false})
      when action in [:show, :index],
      do: true

  # Submit and inspect duplicate reports involving visible images.
  def can?(_user, action, DuplicateReport) when action in [:create, :search], do: true
  def can?(_user, :show, %DuplicateReport{}), do: true

  def can?(_user, :show, %Tag{}), do: true

  # Comment on images where that is allowed
  def can?(_user, :create_comment, %Image{hidden_from_users: false, commenting_allowed: true}),
    do: true

  # Edit metadata on images where that is allowed
  def can?(_user, :edit_metadata, %Image{hidden_from_users: false, tag_editing_allowed: true}),
    do: true

  # View non-deleted comments
  def can?(_user, :show, %Comment{hidden_from_users: false}), do: true

  # View forums
  def can?(_user, :index, Forum), do: true
  def can?(_user, :show, %Forum{access_level: "normal"}), do: true
  def can?(_user, :show, %Topic{hidden_from_users: false}), do: true
  def can?(_user, :mark_read, %Topic{hidden_from_users: false}), do: true
  def can?(_user, :show, %Post{hidden_from_users: false}), do: true

  # Create and edit posts
  def can?(_user, :create_post, %Topic{locked_at: nil, hidden_from_users: false}), do: true

  # View profile pages
  def can?(_user, :show, %User{}), do: true

  # View the commission directory and listings.
  def can?(_user, :index, Commission), do: true
  def can?(_user, :show, %Commission{}), do: true

  def can?(_user, :show, %DnpEntry{aasm_state: "listed"}), do: true
  def can?(_user, :show_reason, %DnpEntry{aasm_state: "listed", hide_reason: false}), do: true

  # Create and edit galleries
  def can?(_user, action, Gallery) when action in [:index, :search], do: true
  def can?(_user, :show, %Gallery{}), do: true

  # Index and show public rules
  def can?(_user, :show, %Rule{hidden: true}), do: false
  def can?(_user, :show, %Rule{internal: true}), do: false
  def can?(_user, action, %Rule{}) when action in [:index, :show], do: true

  # Show static pages
  def can?(_user, :show, %StaticPage{}), do: true

  # Show and visit channels
  def can?(_user, action, %Channel{}) when action in [:show, :visit], do: true

  # Otherwise...
  def can?(_user, _action, _model), do: false
end
