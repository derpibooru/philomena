import { $ } from './utils/dom';
import { parseSearch } from './match-query';
import store from './utils/store';
import { AstMatcher } from './query/types';

export interface TagData {
  id: number;
  name: string;
  images: number;
  spoiler_image_uri: string | null;
  fetchedAt: null | number;
}

export type SpoilerType = 'click' | 'hover' | 'static' | 'off';

export type InteractionType = 'voted' | 'faved' | 'hidden';
export type InteractionValue = 'up' | 'down' | '' | null;

export interface Interaction {
  image_id: number;
  user_id: number;
  interaction_type: InteractionType;
  value: InteractionValue;
}

export type UserRole = 'admin' | 'moderator' | 'assistant' | 'user';

export interface BooruObject {
  /**
   * Automatic timestamp recalculation function for userscript use
   */
  timeAgo: (args: HTMLTimeElement[]) => void;
  /**
   * Anti-forgery token sent by the server
   */
  csrfToken: string;
  /**
   * One of the specified values, based on user setting
   */
  spoilerType: SpoilerType;
  /**
   * List of numeric image IDs as strings
   */
  imagesWithDownvotingDisabled: string[];
  /**
   * Array of watched tag IDs as numbers
   */
  watchedTagList: number[];
  /**
   * Array of spoilered tag IDs as numbers
   */
  spoileredTagList: number[];
  /**
   * Array of ignored tag IDs as numbers
   */
  ignoredTagList: number[];
  /**
   * Array of hidden tag IDs as numbers
   */
  hiddenTagList: number[];
  /**
   * Stores the role assigned to the user.
   */
  userRole: UserRole | undefined;
  userIsSignedIn: boolean;
  /**
   * Indicates if the current user has edit rights to the currently selected filter
   */
  userCanEditFilter: boolean;
  /**
   * AST matcher instance for filter hidden query
   *
   */
  hiddenFilter: AstMatcher;
  /**
   * AST matcher instance for filter spoilered query
   */
  spoileredFilter: AstMatcher;
  interactions: Interaction[];
  /**
   * Indicates whether sensitive staff-only info should be hidden or not.
   */
  hideStaffTools: boolean;
  /**
   * List of image IDs in the current gallery.
   */
  galleryImages?: number[];
  /**
   * Fancy tag setting for uploading images.
   */
  fancyTagUpload: boolean;
  /**
   * Fancy tag setting for editing images.
   */
  fancyTagEdit: boolean;
}

declare global {
  interface Window {
    booru: BooruObject;
  }
}

export const hiddenTagPath = '/images/tagblocked.svg';
export const tagsVersion = 6;

/**
 * Store a tag locally, marking the retrieval time
 */
function persistTag(tagData: TagData) {
  const persistData: TagData = {
    ...tagData,
    fetchedAt: new Date().getTime() / 1000,
  };
  store.set(`bor_tags_${tagData.id}`, persistData);
}

function isStale(tag: TagData): boolean {
  const now = new Date().getTime() / 1000;
  return tag.fetchedAt === null || tag.fetchedAt < now - 604800;
}

function clearTags() {
  Object.keys(localStorage).forEach(key => {
    if (key.substring(0, 9) === 'bor_tags_') {
      store.remove(key);
    }
  });
}

function isValidStoredTag(value: unknown): value is TagData {
  if (
    value !== null &&
    typeof value === 'object' &&
    'id' in value &&
    'name' in value &&
    'images' in value &&
    'spoiler_image_uri' in value
  ) {
    return (
      typeof value.id === 'number' &&
      typeof value.name === 'string' &&
      typeof value.images === 'number' &&
      (value.spoiler_image_uri === null || typeof value.spoiler_image_uri === 'string') &&
      'fetchedAt' in value &&
      (value.fetchedAt === null || typeof value.fetchedAt === 'number')
    );
  }

  return false;
}

/**
 * Returns a single tag, or a dummy tag object if we don't know about it yet
 */
export function getTag(tagId: number): TagData {
  const stored = store.get(`bor_tags_${tagId}`);

  if (isValidStoredTag(stored)) {
    return stored;
  }

  return {
    id: tagId,
    name: '(unknown tag)',
    images: 0,
    spoiler_image_uri: null,
    fetchedAt: null,
  };
}

/**
 * Fetches lots of tags in batches and stores them locally
 */
function fetchAndPersistTags(tagIds: number[]) {
  if (!tagIds.length) return;

  const ids = tagIds.slice(0, 40);
  const remaining = tagIds.slice(41);

  fetch(`/fetch/tags?ids[]=${ids.join('&ids[]=')}`)
    .then(response => response.json())
    .then((data: { tags: TagData[] }) => data.tags.forEach(tag => persistTag(tag)))
    .then(() => fetchAndPersistTags(remaining));
}

/**
 * Figure out which tags in the list we don't know about
 */
function fetchNewOrStaleTags(tagIds: number[]) {
  const fetchIds: number[] = [];

  tagIds.forEach(t => {
    const stored = store.get(`bor_tags_${t}`);
    if (!isValidStoredTag(stored) || isStale(stored)) {
      fetchIds.push(t);
    }
  });

  fetchAndPersistTags(fetchIds);
}

function verifyTagsVersion(latest: number) {
  if (store.get('bor_tags_version') !== latest) {
    clearTags();
    store.set('bor_tags_version', latest);
  }
}

function initializeFilters() {
  const tags = window.booru.spoileredTagList.concat(window.booru.hiddenTagList).filter((a, b, c) => c.indexOf(a) === b);

  verifyTagsVersion(tagsVersion);
  fetchNewOrStaleTags(tags);
}

function unmarshal(data: string): unknown {
  try {
    return JSON.parse(data);
  } catch {
    return data;
  }
}

export function loadBooruData() {
  const datastore = $<HTMLElement>('.js-datastore');

  if (!datastore) return;

  const booruData = datastore.dataset;

  // Assign all elements to booru because lazy
  for (const prop in booruData) {
    // Dynamic property assignment from dataset
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (window.booru as any)[prop] = unmarshal(booruData[prop] || '');
  }

  // When first logging in, this option is actually an empty string. Treat it as false.
  window.booru.hideStaffTools = Boolean(window.booru.hideStaffTools);

  // These are initially strings from the dataset, need to be parsed
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const hiddenFilterStr = window.booru.hiddenFilter as any as string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const spoileredFilterStr = window.booru.spoileredFilter as any as string;

  window.booru.hiddenFilter = parseSearch(hiddenFilterStr);
  window.booru.spoileredFilter = parseSearch(spoileredFilterStr);

  // Fetch tag metadata and set up filtering
  initializeFilters();

  // CSRF
  const csrfToken = $<HTMLMetaElement>('meta[name="csrf-token"]');
  if (csrfToken) {
    window.booru.csrfToken = csrfToken.getAttribute('content') || '';
  }
}

window.booru = {} as BooruObject;
