export const numericProperty = Symbol('numeric');
export const literalProperty = Symbol('literal');
export const dateProperty = Symbol('date');
export const tagProperty = Symbol('tag');

const booleanPropertyValues = ['true', 'false'];

export type PropertyTypeOrValues = symbol | string[];

const imageSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['animated', booleanPropertyValues],
  ['anonymous', booleanPropertyValues],
  ['aspect_ratio', numericProperty],
  ['body_type_tag_count', numericProperty],
  ['deleted', booleanPropertyValues],
  ['deleted_by_user', literalProperty],
  ['deleted_by_user_id', numericProperty],
  ['deletion_reason', literalProperty],
  ['downvoted_by', literalProperty],
  ['downvoted_by_id', numericProperty],
  ['character_tag_count', numericProperty],
  ['comment_count', numericProperty],
  ['content_fanmade_tag_count', numericProperty],
  ['content_official_tag_count', numericProperty],
  ['created_at', dateProperty],
  ['description', literalProperty],
  ['downvotes', numericProperty],
  ['duplicate_id', numericProperty],
  ['duration', numericProperty],
  ['error_tag_count', numericProperty],
  ['faved_by', literalProperty],
  ['faved_by_id', numericProperty],
  ['faves', numericProperty],
  ['file_name', literalProperty],
  ['fingerprint', literalProperty],
  ['first_seen_at', dateProperty],
  ['height', numericProperty],
  ['hidden_by', literalProperty],
  ['hidden_by_id', numericProperty],
  ['id', numericProperty],
  ['ip', literalProperty],
  ['mime_type', literalProperty],
  ['my', ['comments', 'faves', 'hidden', 'subs', 'uploads', 'upvotes', 'watched']],
  ['oc_tag_count', numericProperty],
  ['orig_sha512_hash', literalProperty],
  ['orig_size', numericProperty],
  ['original_format', literalProperty],
  ['pixels', numericProperty],
  ['processed', booleanPropertyValues],
  ['rating_tag_count', numericProperty],
  ['score', numericProperty],
  ['sha512_hash', literalProperty],
  ['size', numericProperty],
  ['source_count', numericProperty],
  ['source_url', literalProperty],
  ['species_tag_count', numericProperty],
  ['spoiler_tag_count', numericProperty],
  ['tag_count', numericProperty],
  ['thumbnails_generated', booleanPropertyValues],
  ['true_uploader', literalProperty],
  ['true_uploader_id', numericProperty],
  ['updated_at', dateProperty],
  ['uploader', literalProperty],
  ['uploader_id', numericProperty],
  ['upvoted_by', literalProperty],
  ['upvoted_by_id', numericProperty],
  ['upvotes', numericProperty],
  ['width', numericProperty],
  ['wilson_score', numericProperty],
]);

const tagSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['alias_of', tagProperty],
  ['aliased', booleanPropertyValues],
  ['aliases', tagProperty],
  ['analyzed_name', literalProperty],
  ['category', literalProperty],
  ['description', literalProperty],
  ['id', numericProperty],
  ['images', numericProperty],
  ['implied_by', tagProperty],
  ['implies', tagProperty],
  ['name', literalProperty],
  ['name_in_namespace', literalProperty],
  ['namespace', literalProperty],
  ['short_description', literalProperty],
  ['slug', literalProperty],
]);

const commentSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['author', literalProperty],
  ['body', literalProperty],
  ['created_at', dateProperty],
  ['id', numericProperty],
  ['image_id', literalProperty],
  ['my', ['comments']],
  ['user_id', literalProperty],
]);

const forumSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['author', literalProperty],
  ['body', literalProperty],
  ['created_at', dateProperty],
  ['id', numericProperty],
  ['my', ['posts']],
  ['subject', literalProperty],
  ['topic_id', literalProperty],
  ['topic_position', numericProperty],
  ['updated_at', dateProperty],
  ['user_id', literalProperty],
  ['forum', literalProperty],
]);

const filterSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['creator', literalProperty],
  ['created_at', dateProperty],
  ['description', literalProperty],
  ['hidden_count', numericProperty],
  ['id', numericProperty],
  ['my', ['filters']],
  ['name', literalProperty],
  ['public', booleanPropertyValues],
  ['spoilered_count', numericProperty],
  ['system', booleanPropertyValues],
  ['user_id', numericProperty],
]);

const reportSearchProperties = new Map<string, PropertyTypeOrValues>([
  ['admin', literalProperty],
  ['admin_id', numericProperty],
  ['created_at', dateProperty],
  ['fingerprint', literalProperty],
  ['id', literalProperty],
  ['image_id', numericProperty],
  ['ip', literalProperty],
  ['open', booleanPropertyValues],
  ['reason', literalProperty],
  ['reportable_id', numericProperty],
  ['reportable_type', ['Comment', 'Commission', 'Conversation', 'Gallery', 'Image', 'Post', 'User']],
  ['state', ['open', 'in_progress', 'closed']],
  ['user', literalProperty],
  ['user_id', numericProperty],
]);

const rangeOperators = ['gt', 'gte', 'lt', 'lte'];

export const propertyTypeOperators = new Map<symbol, string[]>([
  [numericProperty, rangeOperators],
  [dateProperty, rangeOperators],
]);

export const searchTypeToPropertiesMap = new Map<string, Map<string, PropertyTypeOrValues>>([
  ['cq', commentSearchProperties],
  ['fq', filterSearchProperties],
  ['pq', forumSearchProperties],
  ['rq', reportSearchProperties],
  ['tq', tagSearchProperties],
  ['q', imageSearchProperties],
]);

// Properties described in this set should only be displayed to the staff members.
export const moderationPropertiesSet = new Set<string>([
  'anonymous',
  'deleted',
  'deleted_by_user',
  'deleted_by_user_id',
  'deletion_reason',
  'downvoted_by',
  'downvoted_by_id',
  'fingerprint',
  'hidden_by',
  'hidden_by_id',
  'ip',
  'true_uploader',
  'true_uploader_id',
  'upvoted_by',
  'upvoted_by_id',
]);
