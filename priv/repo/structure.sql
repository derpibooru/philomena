--
-- PostgreSQL database dump
--

-- Dumped from database version 12.3 (Debian 12.3-1.pgdg100+1)
-- Dumped by pg_dump version 12.3 (Debian 12.3-1.pgdg90+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: adverts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.adverts (
    id integer NOT NULL,
    image character varying,
    link character varying,
    title character varying,
    clicks integer DEFAULT 0,
    impressions integer DEFAULT 0,
    live boolean DEFAULT false,
    start_date timestamp without time zone,
    finish_date timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    restrictions character varying,
    notes character varying
);


--
-- Name: adverts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.adverts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: adverts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.adverts_id_seq OWNED BY public.adverts.id;


--
-- Name: badge_awards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badge_awards (
    id integer NOT NULL,
    label character varying,
    awarded_on timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    badge_id integer NOT NULL,
    awarded_by_id integer NOT NULL,
    reason character varying,
    badge_name character varying
);


--
-- Name: badge_awards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.badge_awards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: badge_awards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.badge_awards_id_seq OWNED BY public.badge_awards.id;


--
-- Name: badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badges (
    id integer NOT NULL,
    title character varying NOT NULL,
    description character varying NOT NULL,
    image character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    disable_award boolean DEFAULT false NOT NULL,
    priority boolean DEFAULT false
);


--
-- Name: badges_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.badges_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: badges_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.badges_id_seq OWNED BY public.badges.id;


--
-- Name: channel_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channel_subscriptions (
    channel_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channels (
    id integer NOT NULL,
    short_name character varying NOT NULL,
    title character varying NOT NULL,
    description character varying,
    channel_image character varying,
    tags character varying,
    viewers integer DEFAULT 0 NOT NULL,
    nsfw boolean DEFAULT false NOT NULL,
    is_live boolean DEFAULT false NOT NULL,
    last_fetched_at timestamp without time zone,
    next_check_at timestamp without time zone,
    last_live_at timestamp without time zone,
    watcher_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    watcher_count integer DEFAULT 0 NOT NULL,
    type character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    associated_artist_tag_id integer,
    viewer_minutes_today integer DEFAULT 0 NOT NULL,
    viewer_minutes_thisweek integer DEFAULT 0 NOT NULL,
    viewer_minutes_thismonth integer DEFAULT 0 NOT NULL,
    total_viewer_minutes integer DEFAULT 0 NOT NULL,
    banner_image character varying,
    remote_stream_id integer,
    thumbnail_url character varying DEFAULT ''::character varying
);


--
-- Name: channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channels_id_seq OWNED BY public.channels.id;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id integer NOT NULL,
    body character varying NOT NULL,
    ip inet,
    fingerprint character varying,
    user_agent character varying DEFAULT ''::character varying,
    referrer character varying DEFAULT ''::character varying,
    anonymous boolean DEFAULT false,
    hidden_from_users boolean DEFAULT false NOT NULL,
    user_id integer,
    deleted_by_id integer,
    image_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    edit_reason character varying,
    edited_at timestamp without time zone,
    deletion_reason character varying DEFAULT ''::character varying NOT NULL,
    destroyed_content boolean DEFAULT false,
    name_at_post_time character varying
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;


--
-- Name: commission_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commission_items (
    id integer NOT NULL,
    commission_id integer,
    item_type character varying,
    description character varying,
    base_price numeric,
    add_ons character varying,
    example_image_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: commission_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.commission_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commission_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.commission_items_id_seq OWNED BY public.commission_items.id;


--
-- Name: commissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commissions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    open boolean NOT NULL,
    categories character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    information character varying,
    contact character varying,
    sheet_image_id integer,
    will_create character varying,
    will_not_create character varying,
    commission_items_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: commissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.commissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: commissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.commissions_id_seq OWNED BY public.commissions.id;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id integer NOT NULL,
    title character varying NOT NULL,
    to_read boolean DEFAULT false NOT NULL,
    from_read boolean DEFAULT true NOT NULL,
    to_hidden boolean DEFAULT false NOT NULL,
    from_hidden boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    from_id integer NOT NULL,
    to_id integer NOT NULL,
    slug character varying NOT NULL,
    last_message_at timestamp without time zone NOT NULL
);


--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: dnp_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dnp_entries (
    id integer NOT NULL,
    requesting_user_id integer NOT NULL,
    modifying_user_id integer,
    tag_id integer NOT NULL,
    aasm_state character varying DEFAULT 'requested'::character varying NOT NULL,
    dnp_type character varying NOT NULL,
    conditions character varying NOT NULL,
    reason character varying NOT NULL,
    hide_reason boolean DEFAULT false NOT NULL,
    instructions character varying NOT NULL,
    feedback character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: dnp_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dnp_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dnp_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dnp_entries_id_seq OWNED BY public.dnp_entries.id;


--
-- Name: donations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.donations (
    id integer NOT NULL,
    email character varying,
    amount numeric,
    fee numeric,
    txn_id character varying,
    receipt_id character varying,
    note character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer
);


--
-- Name: donations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.donations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: donations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.donations_id_seq OWNED BY public.donations.id;


--
-- Name: duplicate_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.duplicate_reports (
    id integer NOT NULL,
    reason character varying,
    state character varying DEFAULT 'open'::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    image_id integer NOT NULL,
    duplicate_of_image_id integer NOT NULL,
    user_id integer,
    modifier_id integer
);


--
-- Name: duplicate_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.duplicate_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: duplicate_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.duplicate_reports_id_seq OWNED BY public.duplicate_reports.id;


--
-- Name: filters; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.filters (
    id integer NOT NULL,
    name character varying NOT NULL,
    description character varying NOT NULL,
    system boolean DEFAULT false NOT NULL,
    public boolean DEFAULT false NOT NULL,
    hidden_complex_str character varying,
    spoilered_complex_str character varying,
    hidden_tag_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    spoilered_tag_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    user_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer
);


--
-- Name: filters_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.filters_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: filters_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.filters_id_seq OWNED BY public.filters.id;


--
-- Name: fingerprint_bans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fingerprint_bans (
    id integer NOT NULL,
    reason character varying NOT NULL,
    note character varying,
    enabled boolean DEFAULT true NOT NULL,
    valid_until timestamp without time zone NOT NULL,
    fingerprint character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    banning_user_id integer NOT NULL,
    generated_ban_id character varying NOT NULL
);


--
-- Name: fingerprint_bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fingerprint_bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fingerprint_bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fingerprint_bans_id_seq OWNED BY public.fingerprint_bans.id;


--
-- Name: forum_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forum_subscriptions (
    forum_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: forums; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.forums (
    id integer NOT NULL,
    name character varying NOT NULL,
    short_name character varying NOT NULL,
    description character varying NOT NULL,
    access_level character varying DEFAULT 'normal'::character varying NOT NULL,
    topic_count integer DEFAULT 0 NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    watcher_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    watcher_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    last_post_id integer,
    last_topic_id integer
);


--
-- Name: forums_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.forums_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: forums_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.forums_id_seq OWNED BY public.forums.id;


--
-- Name: galleries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.galleries (
    id integer NOT NULL,
    title character varying NOT NULL,
    spoiler_warning character varying DEFAULT ''::character varying NOT NULL,
    description character varying DEFAULT ''::character varying NOT NULL,
    thumbnail_id integer NOT NULL,
    creator_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    watcher_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    watcher_count integer DEFAULT 0 NOT NULL,
    image_count integer DEFAULT 0 NOT NULL,
    order_position_asc boolean DEFAULT false NOT NULL
);


--
-- Name: galleries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.galleries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: galleries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.galleries_id_seq OWNED BY public.galleries.id;


--
-- Name: gallery_interactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gallery_interactions (
    id integer NOT NULL,
    "position" integer NOT NULL,
    image_id integer NOT NULL,
    gallery_id integer NOT NULL
);


--
-- Name: gallery_interactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gallery_interactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gallery_interactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gallery_interactions_id_seq OWNED BY public.gallery_interactions.id;


--
-- Name: gallery_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gallery_subscriptions (
    gallery_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: image_faves; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_faves (
    image_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: image_features; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_features (
    id bigint NOT NULL,
    image_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: image_features_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.image_features_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: image_features_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.image_features_id_seq OWNED BY public.image_features.id;


--
-- Name: image_hides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_hides (
    image_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: image_intensities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_intensities (
    id bigint NOT NULL,
    image_id bigint NOT NULL,
    nw double precision NOT NULL,
    ne double precision NOT NULL,
    sw double precision NOT NULL,
    se double precision NOT NULL
);


--
-- Name: image_intensities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.image_intensities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: image_intensities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.image_intensities_id_seq OWNED BY public.image_intensities.id;


--
-- Name: image_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_sources (
    id bigint NOT NULL,
    image_id bigint NOT NULL,
    source text NOT NULL,
    CONSTRAINT length_must_be_valid CHECK (((length(source) >= 8) AND (length(source) <= 1024)))
);


--
-- Name: image_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.image_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: image_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.image_sources_id_seq OWNED BY public.image_sources.id;


--
-- Name: image_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_subscriptions (
    image_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: image_taggings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_taggings (
    image_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: image_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.image_votes (
    image_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    up boolean NOT NULL
);


--
-- Name: images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.images (
    id integer NOT NULL,
    image character varying,
    image_name character varying,
    image_width integer,
    image_height integer,
    image_size integer,
    image_format character varying,
    image_mime_type character varying,
    image_aspect_ratio double precision,
    ip inet,
    fingerprint character varying,
    user_agent character varying DEFAULT ''::character varying,
    referrer character varying DEFAULT ''::character varying,
    anonymous boolean DEFAULT false,
    score integer DEFAULT 0 NOT NULL,
    faves_count integer DEFAULT 0 NOT NULL,
    upvotes_count integer DEFAULT 0 NOT NULL,
    downvotes_count integer DEFAULT 0 NOT NULL,
    votes_count integer DEFAULT 0 NOT NULL,
    watcher_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    watcher_count integer DEFAULT 0 NOT NULL,
    source_url character varying,
    description character varying DEFAULT ''::character varying NOT NULL,
    image_sha512_hash character varying,
    image_orig_sha512_hash character varying,
    deletion_reason character varying,
    tag_list_cache character varying,
    tag_list_plus_alias_cache character varying,
    file_name_cache character varying,
    duplicate_id integer,
    tag_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    comments_count integer DEFAULT 0 NOT NULL,
    processed boolean DEFAULT false NOT NULL,
    thumbnails_generated boolean DEFAULT false NOT NULL,
    duplication_checked boolean DEFAULT false NOT NULL,
    hidden_from_users boolean DEFAULT false NOT NULL,
    tag_editing_allowed boolean DEFAULT true NOT NULL,
    description_editing_allowed boolean DEFAULT true NOT NULL,
    commenting_allowed boolean DEFAULT true NOT NULL,
    is_animated boolean NOT NULL,
    first_seen_at timestamp without time zone NOT NULL,
    featured_on timestamp without time zone,
    se_intensity double precision,
    sw_intensity double precision,
    ne_intensity double precision,
    nw_intensity double precision,
    average_intensity double precision,
    user_id integer,
    deleted_by_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    destroyed_content boolean DEFAULT false NOT NULL,
    hidden_image_key character varying,
    scratchpad character varying,
    hides_count integer DEFAULT 0 NOT NULL,
    image_duration double precision
);


--
-- Name: images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.images_id_seq OWNED BY public.images.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id integer NOT NULL,
    body character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    from_id integer NOT NULL,
    conversation_id integer NOT NULL
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: mod_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mod_notes (
    id integer NOT NULL,
    moderator_id integer NOT NULL,
    notable_id integer NOT NULL,
    notable_type character varying NOT NULL,
    body text NOT NULL,
    deleted boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: mod_notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mod_notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mod_notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mod_notes_id_seq OWNED BY public.mod_notes.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    action character varying NOT NULL,
    watcher_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    actor_id integer NOT NULL,
    actor_type character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    actor_child_id integer,
    actor_child_type character varying
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: poll_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_options (
    id integer NOT NULL,
    label character varying(80) NOT NULL,
    vote_count integer DEFAULT 0 NOT NULL,
    poll_id integer NOT NULL
);


--
-- Name: poll_options_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.poll_options_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: poll_options_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.poll_options_id_seq OWNED BY public.poll_options.id;


--
-- Name: poll_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.poll_votes (
    id integer NOT NULL,
    rank integer,
    poll_option_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: poll_votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.poll_votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: poll_votes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.poll_votes_id_seq OWNED BY public.poll_votes.id;


--
-- Name: polls; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.polls (
    id integer NOT NULL,
    title character varying(140) NOT NULL,
    vote_method character varying(8) NOT NULL,
    active_until timestamp without time zone NOT NULL,
    total_votes integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    hidden_from_users boolean DEFAULT false NOT NULL,
    deleted_by_id integer,
    deletion_reason character varying DEFAULT ''::character varying NOT NULL,
    topic_id integer NOT NULL
);


--
-- Name: polls_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.polls_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: polls_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.polls_id_seq OWNED BY public.polls.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    body character varying NOT NULL,
    edit_reason character varying,
    ip inet,
    fingerprint character varying,
    user_agent character varying DEFAULT ''::character varying,
    referrer character varying DEFAULT ''::character varying,
    topic_position integer NOT NULL,
    hidden_from_users boolean DEFAULT false NOT NULL,
    anonymous boolean DEFAULT false,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer,
    topic_id integer NOT NULL,
    deleted_by_id integer,
    edited_at timestamp without time zone,
    deletion_reason character varying DEFAULT ''::character varying NOT NULL,
    destroyed_content boolean DEFAULT false NOT NULL,
    name_at_post_time character varying
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id integer NOT NULL,
    ip inet NOT NULL,
    fingerprint character varying,
    user_agent character varying DEFAULT ''::character varying,
    referrer character varying DEFAULT ''::character varying,
    reason character varying NOT NULL,
    state character varying DEFAULT 'open'::character varying NOT NULL,
    open boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer,
    admin_id integer,
    reportable_id integer NOT NULL,
    reportable_type character varying NOT NULL
);


--
-- Name: reports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reports_id_seq OWNED BY public.reports.id;


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying,
    resource_id integer,
    resource_type character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: site_notices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_notices (
    id integer NOT NULL,
    title character varying NOT NULL,
    text character varying NOT NULL,
    link character varying NOT NULL,
    link_text character varying NOT NULL,
    live boolean DEFAULT false NOT NULL,
    start_date timestamp without time zone NOT NULL,
    finish_date timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: site_notices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_notices_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_notices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_notices_id_seq OWNED BY public.site_notices.id;


--
-- Name: source_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_changes (
    id integer NOT NULL,
    ip inet NOT NULL,
    fingerprint character varying,
    user_agent character varying DEFAULT ''::character varying,
    referrer character varying DEFAULT ''::character varying,
    new_value character varying,
    initial boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer,
    image_id integer NOT NULL
);


--
-- Name: source_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.source_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: source_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.source_changes_id_seq OWNED BY public.source_changes.id;


--
-- Name: static_page_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.static_page_versions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    static_page_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    title text NOT NULL,
    slug text NOT NULL,
    body text NOT NULL
);


--
-- Name: static_page_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.static_page_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: static_page_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.static_page_versions_id_seq OWNED BY public.static_page_versions.id;


--
-- Name: static_pages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.static_pages (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    title text NOT NULL,
    slug text NOT NULL,
    body text NOT NULL
);


--
-- Name: static_pages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.static_pages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: static_pages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.static_pages_id_seq OWNED BY public.static_pages.id;


--
-- Name: subnet_bans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subnet_bans (
    id integer NOT NULL,
    reason character varying NOT NULL,
    note character varying,
    enabled boolean DEFAULT true NOT NULL,
    valid_until timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    banning_user_id integer NOT NULL,
    specification inet,
    generated_ban_id character varying NOT NULL
);


--
-- Name: subnet_bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.subnet_bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: subnet_bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.subnet_bans_id_seq OWNED BY public.subnet_bans.id;


--
-- Name: tag_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tag_changes (
    id integer NOT NULL,
    ip inet,
    fingerprint character varying,
    user_agent character varying DEFAULT ''::character varying,
    referrer character varying DEFAULT ''::character varying,
    added boolean NOT NULL,
    tag_name_cache character varying DEFAULT ''::character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer,
    tag_id integer,
    image_id integer NOT NULL
);


--
-- Name: tag_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tag_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tag_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tag_changes_id_seq OWNED BY public.tag_changes.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    description character varying DEFAULT ''::character varying,
    short_description character varying DEFAULT ''::character varying,
    namespace character varying,
    name_in_namespace character varying,
    images_count integer DEFAULT 0 NOT NULL,
    image character varying,
    image_format character varying,
    image_mime_type character varying,
    aliased_tag_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    category character varying,
    mod_notes character varying
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: tags_implied_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags_implied_tags (
    tag_id integer NOT NULL,
    implied_tag_id integer NOT NULL
);


--
-- Name: topic_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topic_subscriptions (
    topic_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: topics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.topics (
    id integer NOT NULL,
    title character varying NOT NULL,
    post_count integer DEFAULT 0 NOT NULL,
    view_count integer DEFAULT 0 NOT NULL,
    sticky boolean DEFAULT false NOT NULL,
    last_replied_to_at timestamp without time zone,
    locked_at timestamp without time zone,
    deletion_reason character varying,
    lock_reason character varying,
    slug character varying NOT NULL,
    anonymous boolean DEFAULT false,
    watcher_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    watcher_count integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    forum_id integer NOT NULL,
    user_id integer,
    deleted_by_id integer,
    locked_by_id integer,
    last_post_id integer,
    hidden_from_users boolean DEFAULT false NOT NULL
);


--
-- Name: topics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.topics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: topics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.topics_id_seq OWNED BY public.topics.id;


--
-- Name: unread_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unread_notifications (
    id integer NOT NULL,
    notification_id integer NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: unread_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.unread_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: unread_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.unread_notifications_id_seq OWNED BY public.unread_notifications.id;


--
-- Name: user_bans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_bans (
    id integer NOT NULL,
    reason character varying NOT NULL,
    note character varying,
    enabled boolean DEFAULT true NOT NULL,
    valid_until timestamp without time zone NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    banning_user_id integer NOT NULL,
    generated_ban_id character varying NOT NULL,
    override_ip_ban boolean DEFAULT false NOT NULL
);


--
-- Name: user_bans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_bans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_bans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_bans_id_seq OWNED BY public.user_bans.id;


--
-- Name: user_fingerprints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_fingerprints (
    id integer NOT NULL,
    fingerprint character varying NOT NULL,
    uses integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: user_fingerprints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_fingerprints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_fingerprints_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_fingerprints_id_seq OWNED BY public.user_fingerprints.id;


--
-- Name: user_ips; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_ips (
    id integer NOT NULL,
    ip inet NOT NULL,
    uses integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: user_ips_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_ips_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_ips_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_ips_id_seq OWNED BY public.user_ips.id;


--
-- Name: user_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_links (
    id integer NOT NULL,
    aasm_state character varying NOT NULL,
    uri character varying NOT NULL,
    hostname character varying,
    path character varying,
    verification_code character varying NOT NULL,
    public boolean DEFAULT true NOT NULL,
    next_check_at timestamp without time zone,
    contacted_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL,
    verified_by_user_id integer,
    contacted_by_user_id integer,
    tag_id integer
);


--
-- Name: user_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_links_id_seq OWNED BY public.user_links.id;


--
-- Name: user_name_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_name_changes (
    id integer NOT NULL,
    user_id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_name_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_name_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_name_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_name_changes_id_seq OWNED BY public.user_name_changes.id;


--
-- Name: user_statistics; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_statistics (
    id integer NOT NULL,
    user_id integer NOT NULL,
    day integer DEFAULT 0 NOT NULL,
    uploads integer DEFAULT 0 NOT NULL,
    votes_cast integer DEFAULT 0 NOT NULL,
    comments_posted integer DEFAULT 0 NOT NULL,
    metadata_updates integer DEFAULT 0 NOT NULL,
    images_favourited integer DEFAULT 0 NOT NULL,
    forum_posts integer DEFAULT 0 NOT NULL
);


--
-- Name: user_statistics_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_statistics_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_statistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_statistics_id_seq OWNED BY public.user_statistics.id;


--
-- Name: user_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_tokens (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    created_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_tokens_id_seq OWNED BY public.user_tokens.id;


--
-- Name: user_whitelists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_whitelists (
    id integer NOT NULL,
    reason character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    user_id integer NOT NULL
);


--
-- Name: user_whitelists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_whitelists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_whitelists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_whitelists_id_seq OWNED BY public.user_whitelists.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email public.citext DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip inet,
    last_sign_in_ip inet,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deleted_at timestamp without time zone,
    authentication_token character varying NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    role character varying DEFAULT 'user'::character varying NOT NULL,
    description character varying,
    avatar character varying,
    spoiler_type character varying DEFAULT 'static'::character varying NOT NULL,
    theme character varying DEFAULT 'default'::character varying NOT NULL,
    images_per_page integer DEFAULT 15 NOT NULL,
    show_large_thumbnails boolean DEFAULT true NOT NULL,
    show_sidebar_and_watched_images boolean DEFAULT true NOT NULL,
    fancy_tag_field_on_upload boolean DEFAULT true NOT NULL,
    fancy_tag_field_on_edit boolean DEFAULT true NOT NULL,
    fancy_tag_field_in_settings boolean DEFAULT true NOT NULL,
    autorefresh_by_default boolean DEFAULT false NOT NULL,
    anonymous_by_default boolean DEFAULT false NOT NULL,
    scale_large_images boolean DEFAULT true NOT NULL,
    comments_newest_first boolean DEFAULT true NOT NULL,
    comments_always_jump_to_last boolean DEFAULT false NOT NULL,
    comments_per_page integer DEFAULT 20 NOT NULL,
    watch_on_reply boolean DEFAULT true NOT NULL,
    watch_on_new_topic boolean DEFAULT true NOT NULL,
    watch_on_upload boolean DEFAULT true NOT NULL,
    messages_newest_first boolean DEFAULT false NOT NULL,
    serve_webm boolean DEFAULT false NOT NULL,
    no_spoilered_in_watched boolean DEFAULT false NOT NULL,
    watched_images_query_str character varying DEFAULT ''::character varying NOT NULL,
    watched_images_exclude_str character varying DEFAULT ''::character varying NOT NULL,
    forum_posts_count integer DEFAULT 0 NOT NULL,
    topic_count integer DEFAULT 0 NOT NULL,
    recent_filter_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    unread_notification_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    watched_tag_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    deleted_by_user_id integer,
    current_filter_id integer,
    failed_attempts integer,
    unlock_token character varying,
    locked_at timestamp without time zone,
    uploads_count integer DEFAULT 0 NOT NULL,
    votes_cast_count integer DEFAULT 0 NOT NULL,
    comments_posted_count integer DEFAULT 0 NOT NULL,
    metadata_updates_count integer DEFAULT 0 NOT NULL,
    images_favourited_count integer DEFAULT 0 NOT NULL,
    last_donation_at timestamp without time zone,
    scratchpad text,
    use_centered_layout boolean DEFAULT false NOT NULL,
    secondary_role character varying,
    hide_default_role boolean DEFAULT false NOT NULL,
    personal_title character varying,
    show_hidden_items boolean DEFAULT false NOT NULL,
    hide_vote_counts boolean DEFAULT false NOT NULL,
    hide_advertisements boolean DEFAULT false NOT NULL,
    encrypted_otp_secret character varying,
    encrypted_otp_secret_iv character varying,
    encrypted_otp_secret_salt character varying,
    consumed_timestep integer,
    otp_required_for_login boolean,
    otp_backup_codes character varying[],
    last_renamed_at timestamp without time zone DEFAULT '1970-01-01 00:00:00'::timestamp without time zone NOT NULL,
    forced_filter_id bigint,
    confirmed_at timestamp(0) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: users_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_roles (
    user_id integer NOT NULL,
    role_id integer NOT NULL
);


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id integer NOT NULL,
    item_type character varying NOT NULL,
    item_id integer NOT NULL,
    event character varying NOT NULL,
    whodunnit character varying,
    object text,
    created_at timestamp without time zone
);


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: vpns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vpns (
    ip inet NOT NULL
);


--
-- Name: adverts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adverts ALTER COLUMN id SET DEFAULT nextval('public.adverts_id_seq'::regclass);


--
-- Name: badge_awards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_awards ALTER COLUMN id SET DEFAULT nextval('public.badge_awards_id_seq'::regclass);


--
-- Name: badges id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges ALTER COLUMN id SET DEFAULT nextval('public.badges_id_seq'::regclass);


--
-- Name: channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels ALTER COLUMN id SET DEFAULT nextval('public.channels_id_seq'::regclass);


--
-- Name: comments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);


--
-- Name: commission_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_items ALTER COLUMN id SET DEFAULT nextval('public.commission_items_id_seq'::regclass);


--
-- Name: commissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commissions ALTER COLUMN id SET DEFAULT nextval('public.commissions_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: dnp_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dnp_entries ALTER COLUMN id SET DEFAULT nextval('public.dnp_entries_id_seq'::regclass);


--
-- Name: donations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations ALTER COLUMN id SET DEFAULT nextval('public.donations_id_seq'::regclass);


--
-- Name: duplicate_reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_reports ALTER COLUMN id SET DEFAULT nextval('public.duplicate_reports_id_seq'::regclass);


--
-- Name: filters id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filters ALTER COLUMN id SET DEFAULT nextval('public.filters_id_seq'::regclass);


--
-- Name: fingerprint_bans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fingerprint_bans ALTER COLUMN id SET DEFAULT nextval('public.fingerprint_bans_id_seq'::regclass);


--
-- Name: forums id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forums ALTER COLUMN id SET DEFAULT nextval('public.forums_id_seq'::regclass);


--
-- Name: galleries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.galleries ALTER COLUMN id SET DEFAULT nextval('public.galleries_id_seq'::regclass);


--
-- Name: gallery_interactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gallery_interactions ALTER COLUMN id SET DEFAULT nextval('public.gallery_interactions_id_seq'::regclass);


--
-- Name: image_features id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_features ALTER COLUMN id SET DEFAULT nextval('public.image_features_id_seq'::regclass);


--
-- Name: image_intensities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_intensities ALTER COLUMN id SET DEFAULT nextval('public.image_intensities_id_seq'::regclass);


--
-- Name: image_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_sources ALTER COLUMN id SET DEFAULT nextval('public.image_sources_id_seq'::regclass);


--
-- Name: images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images ALTER COLUMN id SET DEFAULT nextval('public.images_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: mod_notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mod_notes ALTER COLUMN id SET DEFAULT nextval('public.mod_notes_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: poll_options id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options ALTER COLUMN id SET DEFAULT nextval('public.poll_options_id_seq'::regclass);


--
-- Name: poll_votes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes ALTER COLUMN id SET DEFAULT nextval('public.poll_votes_id_seq'::regclass);


--
-- Name: polls id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls ALTER COLUMN id SET DEFAULT nextval('public.polls_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: reports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports ALTER COLUMN id SET DEFAULT nextval('public.reports_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: site_notices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_notices ALTER COLUMN id SET DEFAULT nextval('public.site_notices_id_seq'::regclass);


--
-- Name: source_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_changes ALTER COLUMN id SET DEFAULT nextval('public.source_changes_id_seq'::regclass);


--
-- Name: static_page_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.static_page_versions ALTER COLUMN id SET DEFAULT nextval('public.static_page_versions_id_seq'::regclass);


--
-- Name: static_pages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.static_pages ALTER COLUMN id SET DEFAULT nextval('public.static_pages_id_seq'::regclass);


--
-- Name: subnet_bans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subnet_bans ALTER COLUMN id SET DEFAULT nextval('public.subnet_bans_id_seq'::regclass);


--
-- Name: tag_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_changes ALTER COLUMN id SET DEFAULT nextval('public.tag_changes_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: topics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics ALTER COLUMN id SET DEFAULT nextval('public.topics_id_seq'::regclass);


--
-- Name: unread_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unread_notifications ALTER COLUMN id SET DEFAULT nextval('public.unread_notifications_id_seq'::regclass);


--
-- Name: user_bans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bans ALTER COLUMN id SET DEFAULT nextval('public.user_bans_id_seq'::regclass);


--
-- Name: user_fingerprints id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fingerprints ALTER COLUMN id SET DEFAULT nextval('public.user_fingerprints_id_seq'::regclass);


--
-- Name: user_ips id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ips ALTER COLUMN id SET DEFAULT nextval('public.user_ips_id_seq'::regclass);


--
-- Name: user_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_links ALTER COLUMN id SET DEFAULT nextval('public.user_links_id_seq'::regclass);


--
-- Name: user_name_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_changes ALTER COLUMN id SET DEFAULT nextval('public.user_name_changes_id_seq'::regclass);


--
-- Name: user_statistics id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statistics ALTER COLUMN id SET DEFAULT nextval('public.user_statistics_id_seq'::regclass);


--
-- Name: user_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tokens ALTER COLUMN id SET DEFAULT nextval('public.user_tokens_id_seq'::regclass);


--
-- Name: user_whitelists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_whitelists ALTER COLUMN id SET DEFAULT nextval('public.user_whitelists_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: adverts adverts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.adverts
    ADD CONSTRAINT adverts_pkey PRIMARY KEY (id);


--
-- Name: badge_awards badge_awards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_awards
    ADD CONSTRAINT badge_awards_pkey PRIMARY KEY (id);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);


--
-- Name: channels channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: commission_items commission_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_items
    ADD CONSTRAINT commission_items_pkey PRIMARY KEY (id);


--
-- Name: commissions commissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT commissions_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: dnp_entries dnp_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dnp_entries
    ADD CONSTRAINT dnp_entries_pkey PRIMARY KEY (id);


--
-- Name: donations donations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_pkey PRIMARY KEY (id);


--
-- Name: duplicate_reports duplicate_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_reports
    ADD CONSTRAINT duplicate_reports_pkey PRIMARY KEY (id);


--
-- Name: filters filters_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filters
    ADD CONSTRAINT filters_pkey PRIMARY KEY (id);


--
-- Name: fingerprint_bans fingerprint_bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fingerprint_bans
    ADD CONSTRAINT fingerprint_bans_pkey PRIMARY KEY (id);


--
-- Name: forums forums_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forums
    ADD CONSTRAINT forums_pkey PRIMARY KEY (id);


--
-- Name: galleries galleries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.galleries
    ADD CONSTRAINT galleries_pkey PRIMARY KEY (id);


--
-- Name: gallery_interactions gallery_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gallery_interactions
    ADD CONSTRAINT gallery_interactions_pkey PRIMARY KEY (id);


--
-- Name: image_features image_features_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_features
    ADD CONSTRAINT image_features_pkey PRIMARY KEY (id);


--
-- Name: image_intensities image_intensities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_intensities
    ADD CONSTRAINT image_intensities_pkey PRIMARY KEY (id);


--
-- Name: image_sources image_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_sources
    ADD CONSTRAINT image_sources_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: mod_notes mod_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mod_notes
    ADD CONSTRAINT mod_notes_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: poll_options poll_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT poll_options_pkey PRIMARY KEY (id);


--
-- Name: poll_votes poll_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT poll_votes_pkey PRIMARY KEY (id);


--
-- Name: polls polls_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT polls_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: site_notices site_notices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_notices
    ADD CONSTRAINT site_notices_pkey PRIMARY KEY (id);


--
-- Name: source_changes source_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_changes
    ADD CONSTRAINT source_changes_pkey PRIMARY KEY (id);


--
-- Name: static_page_versions static_page_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.static_page_versions
    ADD CONSTRAINT static_page_versions_pkey PRIMARY KEY (id);


--
-- Name: static_pages static_pages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.static_pages
    ADD CONSTRAINT static_pages_pkey PRIMARY KEY (id);


--
-- Name: subnet_bans subnet_bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subnet_bans
    ADD CONSTRAINT subnet_bans_pkey PRIMARY KEY (id);


--
-- Name: tag_changes tag_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_changes
    ADD CONSTRAINT tag_changes_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: topics topics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT topics_pkey PRIMARY KEY (id);


--
-- Name: unread_notifications unread_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unread_notifications
    ADD CONSTRAINT unread_notifications_pkey PRIMARY KEY (id);


--
-- Name: user_bans user_bans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bans
    ADD CONSTRAINT user_bans_pkey PRIMARY KEY (id);


--
-- Name: user_fingerprints user_fingerprints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fingerprints
    ADD CONSTRAINT user_fingerprints_pkey PRIMARY KEY (id);


--
-- Name: user_ips user_ips_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ips
    ADD CONSTRAINT user_ips_pkey PRIMARY KEY (id);


--
-- Name: user_links user_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_links
    ADD CONSTRAINT user_links_pkey PRIMARY KEY (id);


--
-- Name: user_name_changes user_name_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_changes
    ADD CONSTRAINT user_name_changes_pkey PRIMARY KEY (id);


--
-- Name: user_statistics user_statistics_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statistics
    ADD CONSTRAINT user_statistics_pkey PRIMARY KEY (id);


--
-- Name: user_tokens user_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tokens
    ADD CONSTRAINT user_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_whitelists user_whitelists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_whitelists
    ADD CONSTRAINT user_whitelists_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: image_intensities_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX image_intensities_index ON public.image_intensities USING btree (nw, ne, sw, se);


--
-- Name: image_sources_image_id_source_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX image_sources_image_id_source_index ON public.image_sources USING btree (image_id, source);


--
-- Name: index_adverts_on_restrictions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adverts_on_restrictions ON public.adverts USING btree (restrictions);


--
-- Name: index_adverts_on_start_date_and_finish_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adverts_on_start_date_and_finish_date ON public.adverts USING btree (start_date, finish_date);


--
-- Name: index_badge_awards_on_awarded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_badge_awards_on_awarded_by_id ON public.badge_awards USING btree (awarded_by_id);


--
-- Name: index_badge_awards_on_badge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_badge_awards_on_badge_id ON public.badge_awards USING btree (badge_id);


--
-- Name: index_badge_awards_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_badge_awards_on_user_id ON public.badge_awards USING btree (user_id);


--
-- Name: index_channel_subscriptions_on_channel_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_channel_subscriptions_on_channel_id_and_user_id ON public.channel_subscriptions USING btree (channel_id, user_id);


--
-- Name: index_channel_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channel_subscriptions_on_user_id ON public.channel_subscriptions USING btree (user_id);


--
-- Name: index_channels_on_associated_artist_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channels_on_associated_artist_tag_id ON public.channels USING btree (associated_artist_tag_id);


--
-- Name: index_channels_on_is_live; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channels_on_is_live ON public.channels USING btree (is_live);


--
-- Name: index_channels_on_last_fetched_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channels_on_last_fetched_at ON public.channels USING btree (last_fetched_at);


--
-- Name: index_channels_on_next_check_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channels_on_next_check_at ON public.channels USING btree (next_check_at);


--
-- Name: index_comments_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_created_at ON public.comments USING btree (created_at);


--
-- Name: index_comments_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_deleted_by_id ON public.comments USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_comments_on_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_image_id ON public.comments USING btree (image_id);


--
-- Name: index_comments_on_image_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_image_id_and_created_at ON public.comments USING btree (image_id, created_at);


--
-- Name: index_comments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comments_on_user_id ON public.comments USING btree (user_id);


--
-- Name: index_commission_items_on_commission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commission_items_on_commission_id ON public.commission_items USING btree (commission_id);


--
-- Name: index_commission_items_on_example_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commission_items_on_example_image_id ON public.commission_items USING btree (example_image_id);


--
-- Name: index_commission_items_on_item_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commission_items_on_item_type ON public.commission_items USING btree (item_type);


--
-- Name: index_commissions_on_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commissions_on_open ON public.commissions USING btree (open);


--
-- Name: index_commissions_on_sheet_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commissions_on_sheet_image_id ON public.commissions USING btree (sheet_image_id);


--
-- Name: index_commissions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_commissions_on_user_id ON public.commissions USING btree (user_id);


--
-- Name: index_conversations_on_created_at_and_from_hidden; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_created_at_and_from_hidden ON public.conversations USING btree (created_at, from_hidden);


--
-- Name: index_conversations_on_from_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_from_id ON public.conversations USING btree (from_id);


--
-- Name: index_conversations_on_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_to_id ON public.conversations USING btree (to_id);


--
-- Name: index_dnp_entries_on_aasm_state_filtered; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dnp_entries_on_aasm_state_filtered ON public.dnp_entries USING btree (aasm_state) WHERE ((aasm_state)::text = ANY (ARRAY[('requested'::character varying)::text, ('claimed'::character varying)::text, ('rescinded'::character varying)::text, ('acknowledged'::character varying)::text]));


--
-- Name: index_dnp_entries_on_requesting_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dnp_entries_on_requesting_user_id ON public.dnp_entries USING btree (requesting_user_id);


--
-- Name: index_dnp_entries_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_dnp_entries_on_tag_id ON public.dnp_entries USING btree (tag_id);


--
-- Name: index_donations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_donations_on_user_id ON public.donations USING btree (user_id);


--
-- Name: index_duplicate_reports_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_duplicate_reports_on_created_at ON public.duplicate_reports USING btree (created_at);


--
-- Name: index_duplicate_reports_on_duplicate_of_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_duplicate_reports_on_duplicate_of_image_id ON public.duplicate_reports USING btree (duplicate_of_image_id);


--
-- Name: index_duplicate_reports_on_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_duplicate_reports_on_image_id ON public.duplicate_reports USING btree (image_id);


--
-- Name: index_duplicate_reports_on_modifier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_duplicate_reports_on_modifier_id ON public.duplicate_reports USING btree (modifier_id);


--
-- Name: index_duplicate_reports_on_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_duplicate_reports_on_state ON public.duplicate_reports USING btree (state);


--
-- Name: index_duplicate_reports_on_state_filtered; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_duplicate_reports_on_state_filtered ON public.duplicate_reports USING btree (state) WHERE ((state)::text = ANY (ARRAY[('open'::character varying)::text, ('claimed'::character varying)::text]));


--
-- Name: index_duplicate_reports_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_duplicate_reports_on_user_id ON public.duplicate_reports USING btree (user_id);


--
-- Name: index_filters_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_on_name ON public.filters USING btree (name);


--
-- Name: index_filters_on_system; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_on_system ON public.filters USING btree (system) WHERE (system = true);


--
-- Name: index_filters_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_filters_on_user_id ON public.filters USING btree (user_id);


--
-- Name: index_fingerprint_bans_on_banning_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fingerprint_bans_on_banning_user_id ON public.fingerprint_bans USING btree (banning_user_id);


--
-- Name: index_fingerprint_bans_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fingerprint_bans_on_created_at ON public.fingerprint_bans USING btree (created_at);


--
-- Name: index_fingerprint_bans_on_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fingerprint_bans_on_fingerprint ON public.fingerprint_bans USING btree (fingerprint);


--
-- Name: index_forum_subscriptions_on_forum_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_forum_subscriptions_on_forum_id_and_user_id ON public.forum_subscriptions USING btree (forum_id, user_id);


--
-- Name: index_forum_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forum_subscriptions_on_user_id ON public.forum_subscriptions USING btree (user_id);


--
-- Name: index_forums_on_last_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forums_on_last_post_id ON public.forums USING btree (last_post_id);


--
-- Name: index_forums_on_last_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_forums_on_last_topic_id ON public.forums USING btree (last_topic_id);


--
-- Name: index_forums_on_short_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_forums_on_short_name ON public.forums USING btree (short_name);


--
-- Name: index_galleries_on_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_galleries_on_creator_id ON public.galleries USING btree (creator_id);


--
-- Name: index_galleries_on_thumbnail_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_galleries_on_thumbnail_id ON public.galleries USING btree (thumbnail_id);


--
-- Name: index_gallery_interactions_on_gallery_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gallery_interactions_on_gallery_id ON public.gallery_interactions USING btree (gallery_id);


--
-- Name: index_gallery_interactions_on_gallery_id_and_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gallery_interactions_on_gallery_id_and_image_id ON public.gallery_interactions USING btree (gallery_id, image_id);


--
-- Name: index_gallery_interactions_on_gallery_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gallery_interactions_on_gallery_id_and_position ON public.gallery_interactions USING btree (gallery_id, "position");


--
-- Name: index_gallery_interactions_on_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gallery_interactions_on_image_id ON public.gallery_interactions USING btree (image_id);


--
-- Name: index_gallery_interactions_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gallery_interactions_on_position ON public.gallery_interactions USING btree ("position");


--
-- Name: index_gallery_subscriptions_on_gallery_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gallery_subscriptions_on_gallery_id_and_user_id ON public.gallery_subscriptions USING btree (gallery_id, user_id);


--
-- Name: index_gallery_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_gallery_subscriptions_on_user_id ON public.gallery_subscriptions USING btree (user_id);


--
-- Name: index_image_faves_on_image_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_image_faves_on_image_id_and_user_id ON public.image_faves USING btree (image_id, user_id);


--
-- Name: index_image_faves_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_faves_on_user_id ON public.image_faves USING btree (user_id);


--
-- Name: index_image_features_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_features_on_created_at ON public.image_features USING btree (created_at);


--
-- Name: index_image_features_on_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_features_on_image_id ON public.image_features USING btree (image_id);


--
-- Name: index_image_features_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_features_on_user_id ON public.image_features USING btree (user_id);


--
-- Name: index_image_hides_on_image_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_image_hides_on_image_id_and_user_id ON public.image_hides USING btree (image_id, user_id);


--
-- Name: index_image_hides_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_hides_on_user_id ON public.image_hides USING btree (user_id);


--
-- Name: index_image_intensities_on_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_image_intensities_on_image_id ON public.image_intensities USING btree (image_id);


--
-- Name: index_image_subscriptions_on_image_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_image_subscriptions_on_image_id_and_user_id ON public.image_subscriptions USING btree (image_id, user_id);


--
-- Name: index_image_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_subscriptions_on_user_id ON public.image_subscriptions USING btree (user_id);


--
-- Name: index_image_taggings_on_image_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_image_taggings_on_image_id_and_tag_id ON public.image_taggings USING btree (image_id, tag_id);


--
-- Name: index_image_taggings_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_taggings_on_tag_id ON public.image_taggings USING btree (tag_id);


--
-- Name: index_image_votes_on_image_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_image_votes_on_image_id_and_user_id ON public.image_votes USING btree (image_id, user_id);


--
-- Name: index_image_votes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_image_votes_on_user_id ON public.image_votes USING btree (user_id);


--
-- Name: index_images_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_created_at ON public.images USING btree (created_at);


--
-- Name: index_images_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_deleted_by_id ON public.images USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_images_on_duplicate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_duplicate_id ON public.images USING btree (duplicate_id) WHERE (duplicate_id IS NOT NULL);


--
-- Name: index_images_on_featured_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_featured_on ON public.images USING btree (featured_on);


--
-- Name: index_images_on_image_orig_sha512_hash; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_image_orig_sha512_hash ON public.images USING btree (image_orig_sha512_hash);


--
-- Name: index_images_on_tag_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_tag_ids ON public.images USING gin (tag_ids);


--
-- Name: index_images_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_updated_at ON public.images USING btree (updated_at);


--
-- Name: index_images_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_images_on_user_id ON public.images USING btree (user_id);


--
-- Name: index_messages_on_conversation_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_conversation_id_and_created_at ON public.messages USING btree (conversation_id, created_at);


--
-- Name: index_messages_on_from_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_from_id ON public.messages USING btree (from_id);


--
-- Name: index_mod_notes_on_moderator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mod_notes_on_moderator_id ON public.mod_notes USING btree (moderator_id);


--
-- Name: index_mod_notes_on_notable_type_and_notable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mod_notes_on_notable_type_and_notable_id ON public.mod_notes USING btree (notable_type, notable_id);


--
-- Name: index_notifications_on_actor_id_and_actor_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifications_on_actor_id_and_actor_type ON public.notifications USING btree (actor_id, actor_type);


--
-- Name: index_poll_options_on_poll_id_and_label; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_poll_options_on_poll_id_and_label ON public.poll_options USING btree (poll_id, label);


--
-- Name: index_poll_votes_on_poll_option_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_poll_votes_on_poll_option_id_and_user_id ON public.poll_votes USING btree (poll_option_id, user_id);


--
-- Name: index_poll_votes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_poll_votes_on_user_id ON public.poll_votes USING btree (user_id);


--
-- Name: index_polls_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_polls_on_deleted_by_id ON public.polls USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_polls_on_topic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_polls_on_topic_id ON public.polls USING btree (topic_id);


--
-- Name: index_posts_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_deleted_by_id ON public.posts USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_posts_on_topic_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_topic_id_and_created_at ON public.posts USING btree (topic_id, created_at);


--
-- Name: index_posts_on_topic_id_and_topic_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_topic_id_and_topic_position ON public.posts USING btree (topic_id, topic_position);


--
-- Name: index_posts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_user_id ON public.posts USING btree (user_id);


--
-- Name: index_reports_on_admin_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_admin_id ON public.reports USING btree (admin_id);


--
-- Name: index_reports_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_created_at ON public.reports USING btree (created_at);


--
-- Name: index_reports_on_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_open ON public.reports USING btree (open);


--
-- Name: index_reports_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reports_on_user_id ON public.reports USING btree (user_id);


--
-- Name: index_roles_on_name_and_resource_type_and_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_roles_on_name_and_resource_type_and_resource_id ON public.roles USING btree (name, resource_type, resource_id);


--
-- Name: index_site_notices_on_start_date_and_finish_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_site_notices_on_start_date_and_finish_date ON public.site_notices USING btree (start_date, finish_date);


--
-- Name: index_site_notices_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_site_notices_on_user_id ON public.site_notices USING btree (user_id);


--
-- Name: index_source_changes_on_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_changes_on_image_id ON public.source_changes USING btree (image_id);


--
-- Name: index_source_changes_on_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_changes_on_ip ON public.source_changes USING btree (ip);


--
-- Name: index_source_changes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_changes_on_user_id ON public.source_changes USING btree (user_id);


--
-- Name: index_static_page_versions_on_static_page_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_static_page_versions_on_static_page_id ON public.static_page_versions USING btree (static_page_id);


--
-- Name: index_static_page_versions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_static_page_versions_on_user_id ON public.static_page_versions USING btree (user_id);


--
-- Name: index_static_pages_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_static_pages_on_slug ON public.static_pages USING btree (slug);


--
-- Name: index_static_pages_on_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_static_pages_on_title ON public.static_pages USING btree (title);


--
-- Name: index_subnet_bans_on_banning_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subnet_bans_on_banning_user_id ON public.subnet_bans USING btree (banning_user_id);


--
-- Name: index_subnet_bans_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subnet_bans_on_created_at ON public.subnet_bans USING btree (created_at);


--
-- Name: index_subnet_bans_on_specification; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_subnet_bans_on_specification ON public.subnet_bans USING gist (specification inet_ops);


--
-- Name: index_tag_changes_on_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_changes_on_fingerprint ON public.tag_changes USING btree (fingerprint);


--
-- Name: index_tag_changes_on_image_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_changes_on_image_id ON public.tag_changes USING btree (image_id);


--
-- Name: index_tag_changes_on_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_changes_on_ip ON public.tag_changes USING gist (ip inet_ops);


--
-- Name: index_tag_changes_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_changes_on_tag_id ON public.tag_changes USING btree (tag_id);


--
-- Name: index_tag_changes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tag_changes_on_user_id ON public.tag_changes USING btree (user_id);


--
-- Name: index_tags_implied_tags_on_implied_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_implied_tags_on_implied_tag_id ON public.tags_implied_tags USING btree (implied_tag_id);


--
-- Name: index_tags_implied_tags_on_tag_id_and_implied_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_implied_tags_on_tag_id_and_implied_tag_id ON public.tags_implied_tags USING btree (tag_id, implied_tag_id);


--
-- Name: index_tags_on_aliased_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tags_on_aliased_tag_id ON public.tags USING btree (aliased_tag_id);


--
-- Name: index_tags_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_name ON public.tags USING btree (name);


--
-- Name: index_tags_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tags_on_slug ON public.tags USING btree (slug);


--
-- Name: index_topic_subscriptions_on_topic_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topic_subscriptions_on_topic_id_and_user_id ON public.topic_subscriptions USING btree (topic_id, user_id);


--
-- Name: index_topic_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topic_subscriptions_on_user_id ON public.topic_subscriptions USING btree (user_id);


--
-- Name: index_topics_on_deleted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_deleted_by_id ON public.topics USING btree (deleted_by_id) WHERE (deleted_by_id IS NOT NULL);


--
-- Name: index_topics_on_forum_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_forum_id ON public.topics USING btree (forum_id);


--
-- Name: index_topics_on_forum_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_topics_on_forum_id_and_slug ON public.topics USING btree (forum_id, slug);


--
-- Name: index_topics_on_hidden_from_users; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_hidden_from_users ON public.topics USING btree (hidden_from_users);


--
-- Name: index_topics_on_last_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_last_post_id ON public.topics USING btree (last_post_id);


--
-- Name: index_topics_on_last_replied_to_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_last_replied_to_at ON public.topics USING btree (last_replied_to_at);


--
-- Name: index_topics_on_locked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_locked_by_id ON public.topics USING btree (locked_by_id) WHERE (locked_by_id IS NOT NULL);


--
-- Name: index_topics_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_slug ON public.topics USING btree (slug);


--
-- Name: index_topics_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_topics_on_user_id ON public.topics USING btree (user_id);


--
-- Name: index_unread_notifications_on_notification_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unread_notifications_on_notification_id_and_user_id ON public.unread_notifications USING btree (notification_id, user_id);


--
-- Name: index_unread_notifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_unread_notifications_on_user_id ON public.unread_notifications USING btree (user_id);


--
-- Name: index_user_bans_on_banning_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_bans_on_banning_user_id ON public.user_bans USING btree (banning_user_id);


--
-- Name: index_user_bans_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_bans_on_created_at ON public.user_bans USING btree (created_at DESC);


--
-- Name: index_user_bans_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_bans_on_user_id ON public.user_bans USING btree (user_id);


--
-- Name: index_user_fingerprints_on_fingerprint_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_fingerprints_on_fingerprint_and_user_id ON public.user_fingerprints USING btree (fingerprint, user_id);


--
-- Name: index_user_fingerprints_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_fingerprints_on_user_id ON public.user_fingerprints USING btree (user_id);


--
-- Name: index_user_ips_on_ip_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_ips_on_ip_and_user_id ON public.user_ips USING btree (ip, user_id);


--
-- Name: index_user_ips_on_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_ips_on_updated_at ON public.user_ips USING btree (updated_at);


--
-- Name: index_user_ips_on_user_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_ips_on_user_id_and_updated_at ON public.user_ips USING btree (user_id, updated_at DESC);


--
-- Name: index_user_links_on_aasm_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_links_on_aasm_state ON public.user_links USING btree (aasm_state);


--
-- Name: index_user_links_on_contacted_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_links_on_contacted_by_user_id ON public.user_links USING btree (contacted_by_user_id);


--
-- Name: index_user_links_on_next_check_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_links_on_next_check_at ON public.user_links USING btree (next_check_at);


--
-- Name: index_user_links_on_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_links_on_tag_id ON public.user_links USING btree (tag_id);


--
-- Name: index_user_links_on_uri_tag_id_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_links_on_uri_tag_id_user_id ON public.user_links USING btree (uri, tag_id, user_id) WHERE ((aasm_state)::text <> 'rejected'::text);


--
-- Name: index_user_links_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_links_on_user_id ON public.user_links USING btree (user_id);


--
-- Name: index_user_links_on_verified_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_links_on_verified_by_user_id ON public.user_links USING btree (verified_by_user_id);


--
-- Name: index_user_name_changes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_name_changes_on_user_id ON public.user_name_changes USING btree (user_id);


--
-- Name: index_user_statistics_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_statistics_on_user_id ON public.user_statistics USING btree (user_id);


--
-- Name: index_user_statistics_on_user_id_and_day; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_statistics_on_user_id_and_day ON public.user_statistics USING btree (user_id, day);


--
-- Name: index_user_whitelists_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_whitelists_on_user_id ON public.user_whitelists USING btree (user_id);


--
-- Name: index_users_on_authentication_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_authentication_token ON public.users USING btree (authentication_token);


--
-- Name: index_users_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_created_at ON public.users USING btree (created_at);


--
-- Name: index_users_on_current_filter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_current_filter_id ON public.users USING btree (current_filter_id);


--
-- Name: index_users_on_deleted_by_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_deleted_by_user_id ON public.users USING btree (deleted_by_user_id) WHERE (deleted_by_user_id IS NOT NULL);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_name ON public.users USING btree (name);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_role ON public.users USING btree (role) WHERE ((role)::text <> 'user'::text);


--
-- Name: index_users_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_slug ON public.users USING btree (slug);


--
-- Name: index_users_on_watched_tag_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_watched_tag_ids ON public.users USING gin (watched_tag_ids);


--
-- Name: index_users_roles_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_roles_on_role_id ON public.users_roles USING btree (role_id);


--
-- Name: index_users_roles_on_user_id_and_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_roles_on_user_id_and_role_id ON public.users_roles USING btree (user_id, role_id);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: index_vpns_on_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vpns_on_ip ON public.vpns USING gist (ip inet_ops);


--
-- Name: intensities_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX intensities_index ON public.images USING btree (se_intensity, sw_intensity, ne_intensity, nw_intensity, average_intensity);


--
-- Name: user_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_tokens_context_token_index ON public.user_tokens USING btree (context, token);


--
-- Name: user_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_tokens_user_id_index ON public.user_tokens USING btree (user_id);


--
-- Name: channels fk_rails_021c624081; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT fk_rails_021c624081 FOREIGN KEY (associated_artist_tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: comments fk_rails_03de2dc08c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_03de2dc08c FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: badge_awards fk_rails_0434c93bfb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_awards
    ADD CONSTRAINT fk_rails_0434c93bfb FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: image_faves fk_rails_0a4bb301d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_faves
    ADD CONSTRAINT fk_rails_0a4bb301d6 FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tag_changes fk_rails_0e6c53f1b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_changes
    ADD CONSTRAINT fk_rails_0e6c53f1b9 FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: image_taggings fk_rails_0f89cd23a9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_taggings
    ADD CONSTRAINT fk_rails_0f89cd23a9 FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: source_changes fk_rails_10271ec4d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_changes
    ADD CONSTRAINT fk_rails_10271ec4d0 FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: image_subscriptions fk_rails_15f6724e1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_subscriptions
    ADD CONSTRAINT fk_rails_15f6724e1c FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: images fk_rails_19cd822056; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT fk_rails_19cd822056 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: commissions fk_rails_1cc89d251d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT fk_rails_1cc89d251d FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tag_changes fk_rails_1d7b844de4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_changes
    ADD CONSTRAINT fk_rails_1d7b844de4 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: badge_awards fk_rails_2bbfd9ee45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_awards
    ADD CONSTRAINT fk_rails_2bbfd9ee45 FOREIGN KEY (awarded_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: messages fk_rails_2bcf7eed31; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_2bcf7eed31 FOREIGN KEY (from_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: polls fk_rails_2bf9149369; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT fk_rails_2bf9149369 FOREIGN KEY (deleted_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: image_hides fk_rails_335978518a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_hides
    ADD CONSTRAINT fk_rails_335978518a FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: comments fk_rails_33bcaea6cd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_33bcaea6cd FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_ips fk_rails_34294629f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ips
    ADD CONSTRAINT fk_rails_34294629f5 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel_subscriptions fk_rails_3447ee7f65; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_subscriptions
    ADD CONSTRAINT fk_rails_3447ee7f65 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: commissions fk_rails_3dabda470b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commissions
    ADD CONSTRAINT fk_rails_3dabda470b FOREIGN KEY (sheet_image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: comments fk_rails_3f25c5a043; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT fk_rails_3f25c5a043 FOREIGN KEY (deleted_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: unread_notifications fk_rails_429c8d75ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unread_notifications
    ADD CONSTRAINT fk_rails_429c8d75ab FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: dnp_entries fk_rails_473a736b4a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dnp_entries
    ADD CONSTRAINT fk_rails_473a736b4a FOREIGN KEY (requesting_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: users_roles fk_rails_4a41696df6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_roles
    ADD CONSTRAINT fk_rails_4a41696df6 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tags fk_rails_4b494c6c9a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT fk_rails_4b494c6c9a FOREIGN KEY (aliased_tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: conversations fk_rails_4bac0f7b3f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_4bac0f7b3f FOREIGN KEY (to_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: images fk_rails_4beeabc29a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT fk_rails_4beeabc29a FOREIGN KEY (duplicate_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: mod_notes fk_rails_52f31eb1ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mod_notes
    ADD CONSTRAINT fk_rails_52f31eb1ff FOREIGN KEY (moderator_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: donations fk_rails_5470822a00; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT fk_rails_5470822a00 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: commission_items fk_rails_56d368749a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_items
    ADD CONSTRAINT fk_rails_56d368749a FOREIGN KEY (example_image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: posts fk_rails_5736a68073; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_5736a68073 FOREIGN KEY (deleted_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: site_notices fk_rails_57d8d7ea57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_notices
    ADD CONSTRAINT fk_rails_57d8d7ea57 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: channel_subscriptions fk_rails_58f2e8e2d4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_subscriptions
    ADD CONSTRAINT fk_rails_58f2e8e2d4 FOREIGN KEY (channel_id) REFERENCES public.channels(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: duplicate_reports fk_rails_5b4e8fb78c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_reports
    ADD CONSTRAINT fk_rails_5b4e8fb78c FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: posts fk_rails_5b5ddfd518; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_5b5ddfd518 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: duplicate_reports fk_rails_5cf6ede006; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_reports
    ADD CONSTRAINT fk_rails_5cf6ede006 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: commission_items fk_rails_62d0ec516b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_items
    ADD CONSTRAINT fk_rails_62d0ec516b FOREIGN KEY (commission_id) REFERENCES public.commissions(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: images fk_rails_643b16ae74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT fk_rails_643b16ae74 FOREIGN KEY (deleted_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: topics fk_rails_687ee3cd61; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT fk_rails_687ee3cd61 FOREIGN KEY (deleted_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: gallery_interactions fk_rails_6af162285f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gallery_interactions
    ADD CONSTRAINT fk_rails_6af162285f FOREIGN KEY (gallery_id) REFERENCES public.galleries(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: galleries fk_rails_6c0cba6a45; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.galleries
    ADD CONSTRAINT fk_rails_6c0cba6a45 FOREIGN KEY (creator_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: gallery_subscriptions fk_rails_6e2d2beaf4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gallery_subscriptions
    ADD CONSTRAINT fk_rails_6e2d2beaf4 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: posts fk_rails_70d0b6486a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_70d0b6486a FOREIGN KEY (topic_id) REFERENCES public.topics(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_fingerprints fk_rails_725f1a9b85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fingerprints
    ADD CONSTRAINT fk_rails_725f1a9b85 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: topic_subscriptions fk_rails_72d9624105; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_subscriptions
    ADD CONSTRAINT fk_rails_72d9624105 FOREIGN KEY (topic_id) REFERENCES public.topics(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: duplicate_reports fk_rails_732a84d198; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_reports
    ADD CONSTRAINT fk_rails_732a84d198 FOREIGN KEY (duplicate_of_image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: image_taggings fk_rails_74cc21a055; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_taggings
    ADD CONSTRAINT fk_rails_74cc21a055 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: galleries fk_rails_792181eb40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.galleries
    ADD CONSTRAINT fk_rails_792181eb40 FOREIGN KEY (thumbnail_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: image_hides fk_rails_7a10a4b0f1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_hides
    ADD CONSTRAINT fk_rails_7a10a4b0f1 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: topics fk_rails_7b812cfb44; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT fk_rails_7b812cfb44 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: image_votes fk_rails_8086a2c07e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_votes
    ADD CONSTRAINT fk_rails_8086a2c07e FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_subscriptions fk_rails_8268bd8830; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_subscriptions
    ADD CONSTRAINT fk_rails_8268bd8830 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_name_changes fk_rails_828a40cab1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_name_changes
    ADD CONSTRAINT fk_rails_828a40cab1 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tag_changes fk_rails_82fc2dd958; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tag_changes
    ADD CONSTRAINT fk_rails_82fc2dd958 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: poll_votes fk_rails_848ece0184; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_848ece0184 FOREIGN KEY (poll_option_id) REFERENCES public.poll_options(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forum_subscriptions fk_rails_8508ff98b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forum_subscriptions
    ADD CONSTRAINT fk_rails_8508ff98b6 FOREIGN KEY (forum_id) REFERENCES public.forums(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: polls fk_rails_861a79e923; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.polls
    ADD CONSTRAINT fk_rails_861a79e923 FOREIGN KEY (topic_id) REFERENCES public.topics(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: source_changes fk_rails_8d8cb9cb3b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_changes
    ADD CONSTRAINT fk_rails_8d8cb9cb3b FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: topics fk_rails_8fdcbf6aed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT fk_rails_8fdcbf6aed FOREIGN KEY (last_post_id) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: image_features fk_rails_90c2421c89; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_features
    ADD CONSTRAINT fk_rails_90c2421c89 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: unread_notifications fk_rails_97681c85bb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unread_notifications
    ADD CONSTRAINT fk_rails_97681c85bb FOREIGN KEY (notification_id) REFERENCES public.notifications(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_links fk_rails_9939489c5c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_links
    ADD CONSTRAINT fk_rails_9939489c5c FOREIGN KEY (verified_by_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: fingerprint_bans fk_rails_9a0218c560; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fingerprint_bans
    ADD CONSTRAINT fk_rails_9a0218c560 FOREIGN KEY (banning_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: users fk_rails_9efba9a459; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_9efba9a459 FOREIGN KEY (deleted_by_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: user_statistics fk_rails_a4ae2a454b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_statistics
    ADD CONSTRAINT fk_rails_a4ae2a454b FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: image_subscriptions fk_rails_a4ee3b390b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_subscriptions
    ADD CONSTRAINT fk_rails_a4ee3b390b FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: forums fk_rails_a63558903d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forums
    ADD CONSTRAINT fk_rails_a63558903d FOREIGN KEY (last_post_id) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: poll_options fk_rails_aa85becb42; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_options
    ADD CONSTRAINT fk_rails_aa85becb42 FOREIGN KEY (poll_id) REFERENCES public.polls(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_links fk_rails_ab45cd8fd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_links
    ADD CONSTRAINT fk_rails_ab45cd8fd7 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: topics fk_rails_ab6fa5b2e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT fk_rails_ab6fa5b2e7 FOREIGN KEY (locked_by_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: topic_subscriptions fk_rails_b0d5d379ae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topic_subscriptions
    ADD CONSTRAINT fk_rails_b0d5d379ae FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: reports fk_rails_b138baacff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_b138baacff FOREIGN KEY (admin_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: user_bans fk_rails_b27db52384; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bans
    ADD CONSTRAINT fk_rails_b27db52384 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: static_page_versions fk_rails_b3d9f91a2b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.static_page_versions
    ADD CONSTRAINT fk_rails_b3d9f91a2b FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: image_features fk_rails_b5fb903247; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_features
    ADD CONSTRAINT fk_rails_b5fb903247 FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: poll_votes fk_rails_b64de9b025; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.poll_votes
    ADD CONSTRAINT fk_rails_b64de9b025 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: tags_implied_tags fk_rails_b70078b5dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags_implied_tags
    ADD CONSTRAINT fk_rails_b70078b5dd FOREIGN KEY (implied_tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: image_intensities fk_rails_b861f027a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_intensities
    ADD CONSTRAINT fk_rails_b861f027a7 FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: badge_awards fk_rails_b95340cf70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badge_awards
    ADD CONSTRAINT fk_rails_b95340cf70 FOREIGN KEY (badge_id) REFERENCES public.badges(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: gallery_interactions fk_rails_bb5ebe2a77; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gallery_interactions
    ADD CONSTRAINT fk_rails_bb5ebe2a77 FOREIGN KEY (image_id) REFERENCES public.images(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: image_faves fk_rails_bebe1c640a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_faves
    ADD CONSTRAINT fk_rails_bebe1c640a FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: static_page_versions fk_rails_bfb173af6a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.static_page_versions
    ADD CONSTRAINT fk_rails_bfb173af6a FOREIGN KEY (static_page_id) REFERENCES public.static_pages(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: image_votes fk_rails_c6d2f46f70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_votes
    ADD CONSTRAINT fk_rails_c6d2f46f70 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: reports fk_rails_c7699d537d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT fk_rails_c7699d537d FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: conversations fk_rails_d0f47f4937; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_d0f47f4937 FOREIGN KEY (from_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: duplicate_reports fk_rails_d209e0f2ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.duplicate_reports
    ADD CONSTRAINT fk_rails_d209e0f2ed FOREIGN KEY (modifier_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: users fk_rails_d2b4c2768f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_d2b4c2768f FOREIGN KEY (current_filter_id) REFERENCES public.filters(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: user_bans fk_rails_d4cf1d1b70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_bans
    ADD CONSTRAINT fk_rails_d4cf1d1b70 FOREIGN KEY (banning_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: subnet_bans fk_rails_d8a07ba049; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subnet_bans
    ADD CONSTRAINT fk_rails_d8a07ba049 FOREIGN KEY (banning_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: dnp_entries fk_rails_df26188cea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dnp_entries
    ADD CONSTRAINT fk_rails_df26188cea FOREIGN KEY (modifying_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: tags_implied_tags fk_rails_e55707c39a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags_implied_tags
    ADD CONSTRAINT fk_rails_e55707c39a FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_links fk_rails_e6cf0175d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_links
    ADD CONSTRAINT fk_rails_e6cf0175d0 FOREIGN KEY (contacted_by_user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: forums fk_rails_e8afa7749e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.forums
    ADD CONSTRAINT fk_rails_e8afa7749e FOREIGN KEY (last_topic_id) REFERENCES public.topics(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: topics fk_rails_eac66eb971; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.topics
    ADD CONSTRAINT fk_rails_eac66eb971 FOREIGN KEY (forum_id) REFERENCES public.forums(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: users_roles fk_rails_eb7b4658f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_roles
    ADD CONSTRAINT fk_rails_eb7b4658f8 FOREIGN KEY (role_id) REFERENCES public.roles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_whitelists fk_rails_eda0eaebbb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_whitelists
    ADD CONSTRAINT fk_rails_eda0eaebbb FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: dnp_entries fk_rails_f428aa5665; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dnp_entries
    ADD CONSTRAINT fk_rails_f428aa5665 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: filters fk_rails_f53aed9bb6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.filters
    ADD CONSTRAINT fk_rails_f53aed9bb6 FOREIGN KEY (user_id) REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_links fk_rails_f64b4291c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_links
    ADD CONSTRAINT fk_rails_f64b4291c0 FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: gallery_subscriptions fk_rails_fa77f3cebe; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gallery_subscriptions
    ADD CONSTRAINT fk_rails_fa77f3cebe FOREIGN KEY (gallery_id) REFERENCES public.galleries(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: image_sources image_sources_image_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.image_sources
    ADD CONSTRAINT image_sources_image_id_fkey FOREIGN KEY (image_id) REFERENCES public.images(id);


--
-- Name: user_tokens user_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_tokens
    ADD CONSTRAINT user_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_forced_filter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_forced_filter_id_fkey FOREIGN KEY (forced_filter_id) REFERENCES public.filters(id);


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20200503002523);
INSERT INTO public."schema_migrations" (version) VALUES (20200607000511);
INSERT INTO public."schema_migrations" (version) VALUES (20200617111116);
INSERT INTO public."schema_migrations" (version) VALUES (20200617113333);
INSERT INTO public."schema_migrations" (version) VALUES (20200708160910);
