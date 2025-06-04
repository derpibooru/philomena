defimpl Canada.Can, for: [Atom, Philomena.Users.User] do
  alias Philomena.Users.User
  alias Philomena.Roles.Role
  alias Philomena.Badges.Award
  alias Philomena.Badges.Badge
  alias Philomena.Channels.Channel
  alias Philomena.Comments.Comment
  alias Philomena.Commissions.Commission
  alias Philomena.Conversations.Conversation
  alias Philomena.DuplicateReports.DuplicateReport
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.Images.Image
  alias Philomena.Forums.Forum
  alias Philomena.Topics.Topic
  alias Philomena.ModNotes.ModNote
  alias Philomena.Posts.Post
  alias Philomena.Filters.Filter
  alias Philomena.Galleries.Gallery
  alias Philomena.DnpEntries.DnpEntry
  alias Philomena.ArtistLinks.ArtistLink
  alias Philomena.Tags.Tag
  alias Philomena.TagChanges.TagChange
  alias Philomena.Reports.Report
  alias Philomena.StaticPages.StaticPage
  alias Philomena.Adverts.Advert
  alias Philomena.SiteNotices.SiteNotice
  alias Philomena.ModerationLogs.ModerationLog

  alias Philomena.Bans.User, as: UserBan
  alias Philomena.Bans.Subnet, as: SubnetBan
  alias Philomena.Bans.Fingerprint, as: FingerprintBan

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

  # View forums
  def can?(%User{role: "moderator"}, :show, %Forum{}), do: true

  def can?(%User{role: "moderator"}, :show, %Topic{hidden_from_users: true}), do: true

  # View and approve conversations
  def can?(%User{role: "moderator"}, :show, %Conversation{}), do: true
  def can?(%User{role: "moderator"}, :approve, %Conversation{}), do: true

  # View IP addresses and fingerprints
  def can?(%User{role: "moderator"}, :show, :ip_address), do: true

  # Manage duplicate reports
  def can?(%User{role: "moderator"}, :index, DuplicateReport), do: true
  def can?(%User{role: "moderator"}, :edit, %DuplicateReport{}), do: true

  # Manage reports
  def can?(%User{role: "moderator"}, :index, Report), do: true
  def can?(%User{role: "moderator"}, :show, %Report{}), do: true
  def can?(%User{role: "moderator"}, :edit, %Report{}), do: true

  # Manage artist links
  def can?(%User{role: "moderator"}, :create_links, %User{}), do: true
  def can?(%User{role: "moderator"}, :edit_links, %User{}), do: true
  def can?(%User{role: "moderator"}, _action, ArtistLink), do: true
  def can?(%User{role: "moderator"}, _action, %ArtistLink{}), do: true

  # Reveal anon users
  def can?(%User{role: "moderator"}, :reveal_anon, _object), do: true

  # Edit posts and comments
  def can?(%User{role: "moderator"}, :edit, %Post{}), do: true
  def can?(%User{role: "moderator"}, :hide, %Post{}), do: true
  def can?(%User{role: "moderator"}, :delete, %Post{}), do: true
  def can?(%User{role: "moderator"}, :approve, %Post{}), do: true
  def can?(%User{role: "moderator"}, :edit, %Comment{}), do: true
  def can?(%User{role: "moderator"}, :hide, %Comment{}), do: true
  def can?(%User{role: "moderator"}, :delete, %Comment{}), do: true
  def can?(%User{role: "moderator"}, :approve, %Comment{}), do: true

  # Show the DNP list
  def can?(%User{role: "moderator"}, _action, DnpEntry), do: true
  def can?(%User{role: "moderator"}, _action, %DnpEntry{}), do: true

  # Create bans
  def can?(%User{role: "moderator"}, _action, UserBan), do: true
  def can?(%User{role: "moderator"}, _action, SubnetBan), do: true
  def can?(%User{role: "moderator"}, _action, FingerprintBan), do: true

  # Hide topics
  def can?(%User{role: "moderator"}, :show, %Topic{}), do: true
  def can?(%User{role: "moderator"}, :hide, %Topic{}), do: true
  def can?(%User{role: "moderator"}, :edit, %Topic{}), do: true
  def can?(%User{role: "moderator"}, :create_post, %Topic{}), do: true

  # Edit tags
  def can?(%User{role: "moderator"}, :edit, %Tag{}), do: true

  # Award badges
  def can?(%User{role: "moderator"}, _action, %Award{}), do: true
  def can?(%User{role: "moderator"}, _action, Award), do: true

  # Create mod notes
  def can?(%User{role: "moderator"}, :index, ModNote), do: true

  # Revert tag changes
  def can?(%User{role: "moderator"}, :revert, TagChange), do: true
  def can?(%User{role: "moderator"}, :delete, %TagChange{}), do: true

  # Manage commissions
  def can?(%User{role: "moderator"}, _action, %Commission{}), do: true

  # Manage galleries
  def can?(%User{role: "moderator"}, _action, %Gallery{}), do: true

  # See moderation logs
  def can?(%User{role: "moderator"}, _action, ModerationLog), do: true

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
  def can?(%User{role: "moderator", role_map: %{"Badge" => %{"admin" => _}}}, _action, Badge),
    do: true

  def can?(%User{role: "moderator", role_map: %{"Badge" => %{"admin" => _}}}, _action, %Badge{}),
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
  def can?(%User{role: "moderator", role_map: %{"User" => %{"moderator" => _}}}, _action, User),
    do: true

  def can?(%User{role: "moderator", role_map: %{"User" => %{"moderator" => _}}}, _action, %User{}),
    do: true

  # Manage advertisements
  def can?(%User{role: "moderator", role_map: %{"Advert" => %{"admin" => _}}}, _action, Advert),
    do: true

  def can?(%User{role: "moderator", role_map: %{"Advert" => %{"admin" => _}}}, _action, %Advert{}),
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
  # Assistants can...
  #

  # Image assistant actions
  def can?(%User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}}, :show, %Image{}),
    do: true

  def can?(%User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}}, :hide, %Image{}),
    do: true

  def can?(%User{role: "assistant", role_map: %{"Image" => %{"moderator" => _}}}, :edit, %Image{}),
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

  # Dupe assistant actions
  def can?(
        %User{role: "assistant", role_map: %{"DuplicateReport" => %{"moderator" => _}}},
        :index,
        DuplicateReport
      ),
      do: true

  def can?(
        %User{role: "assistant", role_map: %{"DuplicateReport" => %{"moderator" => _}}},
        :edit,
        %DuplicateReport{}
      ),
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
        :edit,
        %Comment{}
      ),
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
  def can?(%User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}}, :show, %Topic{}),
    do: true

  def can?(%User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}}, :edit, %Topic{}),
    do: true

  def can?(%User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}}, :hide, %Topic{}),
    do: true

  def can?(%User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}}, :show, %Post{}),
    do: true

  def can?(%User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}}, :edit, %Post{}),
    do: true

  def can?(%User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}}, :hide, %Post{}),
    do: true

  def can?(
        %User{role: "assistant", role_map: %{"Topic" => %{"moderator" => _}}},
        :approve,
        %Post{}
      ),
      do: true

  # Tag assistant actions
  def can?(%User{role: "assistant", role_map: %{"Tag" => %{"moderator" => _}}}, :edit, %Tag{}),
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
        %ArtistLink{}
      ),
      do: true

  # View forums
  def can?(%User{role: "assistant"}, :show, %Forum{access_level: level})
      when level in ["normal", "assistant"],
      do: true

  def can?(%User{role: "assistant"}, :show, %Topic{hidden_from_users: true}), do: true

  #
  # Users and anonymous users can...
  #

  # Batch tag
  def can?(%User{role_map: %{"Tag" => %{"batch_update" => _}}}, :batch_update, Tag), do: true

  # Edit their description and personal title
  def can?(%User{id: id}, :edit_description, %User{id: id}), do: true
  def can?(%User{id: id}, :edit_title, %User{id: id}), do: true

  # Edit their username
  def can?(%User{id: id}, :change_username, %User{id: id} = user) do
    time_ago = DateTime.utc_now() |> DateTime.add(-1 * 60 * 60 * 24 * 90)
    DateTime.diff(user.last_renamed_at, time_ago) < 0
  end

  # View conversations they are involved in
  def can?(%User{id: id}, :show, %Conversation{to_id: id}), do: true
  def can?(%User{id: id}, :show, %Conversation{from_id: id}), do: true

  # View filters they own and public/system filters
  def can?(_user, :show, %Filter{system: true}), do: true
  def can?(_user, :show, %Filter{public: true}), do: true
  def can?(%User{}, action, Filter) when action in [:index, :new, :create], do: true

  def can?(%User{id: id}, action, %Filter{user_id: id}) when action in [:show, :edit, :update],
    do: true

  # Edit filters they own
  def can?(%User{id: id}, action, %Filter{user_id: id}) when action in [:edit, :update, :delete],
    do: true

  # View artist links they've created
  def can?(%User{id: id}, :create_links, %User{id: id}), do: true
  def can?(%User{id: id}, :show, %ArtistLink{user_id: id}), do: true

  # Edit their commissions
  def can?(%User{id: id}, action, %Commission{user_id: id})
      when action in [:edit, :update, :delete],
      do: true

  # View non-deleted images
  def can?(_user, action, Image)
      when action in [:new, :create, :index],
      do: true

  def can?(_user, action, %Image{hidden_from_users: false})
      when action in [:show, :index],
      do: true

  def can?(_user, :show, %Tag{}), do: true

  # Comment on images where that is allowed
  def can?(_user, :create_comment, %Image{hidden_from_users: false, commenting_allowed: true}),
    do: true

  # Edit comments on images
  def can?(%User{id: id}, action, %Comment{hidden_from_users: false, user_id: id})
      when action in [:edit, :update],
      do: true

  # Edit metadata on images where that is allowed
  def can?(_user, :edit_metadata, %Image{hidden_from_users: false, tag_editing_allowed: true}),
    do: true

  def can?(%User{id: id}, :edit_description, %Image{
        user_id: id,
        hidden_from_users: false,
        description_editing_allowed: true
      }),
      do: true

  # Vote on images they can see
  def can?(user, :vote, image), do: can?(user, :show, image)

  # View non-deleted comments
  def can?(_user, :show, %Comment{hidden_from_users: false}), do: true

  # View forums
  def can?(_user, :index, Forum), do: true
  def can?(_user, :show, %Forum{access_level: "normal"}), do: true
  def can?(_user, :show, %Topic{hidden_from_users: false}), do: true
  def can?(_user, :show, %Post{hidden_from_users: false}), do: true

  # Create and edit posts
  def can?(_user, :create_post, %Topic{locked_at: nil, hidden_from_users: false}), do: true

  def can?(%User{id: id}, action, %Post{hidden_from_users: false, user_id: id})
      when action in [:edit, :update],
      do: true

  # View profile pages
  def can?(_user, :show, %User{}), do: true

  # View and create DNP entries
  def can?(%User{}, action, DnpEntry) when action in [:new, :create], do: true
  def can?(%User{id: id}, :show, %DnpEntry{requesting_user_id: id}), do: true
  def can?(%User{id: id}, :show_reason, %DnpEntry{requesting_user_id: id}), do: true
  def can?(%User{id: id}, :show_feedback, %DnpEntry{requesting_user_id: id}), do: true

  def can?(_user, :show, %DnpEntry{aasm_state: "listed"}), do: true
  def can?(_user, :show_reason, %DnpEntry{aasm_state: "listed", hide_reason: false}), do: true

  # Create and edit galleries
  def can?(_user, :show, %Gallery{}), do: true
  def can?(%User{}, action, Gallery) when action in [:new, :create], do: true

  def can?(%User{id: id}, action, %Gallery{creator_id: id})
      when action in [:edit, :update, :delete],
      do: true

  # Show static pages
  def can?(_user, :show, %StaticPage{}), do: true

  # Show channels
  def can?(_user, :show, %Channel{}), do: true

  # Otherwise...
  def can?(_user, _action, _model), do: false
end
