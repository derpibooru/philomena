import { $ } from './utils/dom';
import { parseSearch } from './match_query';
import store from './utils/store';

/**
 * Store a tag locally, marking the retrieval time
 * @param {TagData} tagData
 */
function persistTag(tagData) {
  /**
   * @type {TagData}
   */
  const persistData = {
    ...tagData,
    fetchedAt: new Date().getTime() / 1000,
  };
  store.set(`bor_tags_${tagData.id}`, persistData);
}

/**
 * @param {TagData} tag
 * @return {boolean}
 */
function isStale(tag) {
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

/**
 * @param {unknown} value
 * @returns {value is TagData}
 */
function isValidStoredTag(value) {
  if (value !== null && 'id' in value && 'name' in value && 'images' in value && 'spoiler_image_uri' in value) {
    return (
      typeof value.id === 'number' &&
      typeof value.name === 'string' &&
      typeof value.images === 'number' &&
      (value.spoiler_image_uri === null || typeof value.spoiler_image_uri === 'string') &&
      (value.fetchedAt === null || typeof value.fetchedAt === 'number')
    );
  }

  return false;
}

/**
 * Returns a single tag, or a dummy tag object if we don't know about it yet
 * @param {number} tagId
 * @returns {TagData}
 */
function getTag(tagId) {
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
 * @param {number[]} tagIds
 */
function fetchAndPersistTags(tagIds) {
  if (!tagIds.length) return;

  const ids = tagIds.slice(0, 40);
  const remaining = tagIds.slice(41);

  fetch(`/fetch/tags?ids[]=${ids.join('&ids[]=')}`)
    .then(response => response.json())
    .then(data => data.tags.forEach(tag => persistTag(tag)))
    .then(() => fetchAndPersistTags(remaining));
}

/**
 * Figure out which tags in the list we don't know about
 * @param {number[]} tagIds
 */
function fetchNewOrStaleTags(tagIds) {
  const fetchIds = [];

  tagIds.forEach(t => {
    const stored = store.get(`bor_tags_${t}`);
    if (!stored || isStale(stored)) {
      fetchIds.push(t);
    }
  });

  fetchAndPersistTags(fetchIds);
}

function verifyTagsVersion(latest) {
  if (store.get('bor_tags_version') !== latest) {
    clearTags();
    store.set('bor_tags_version', latest);
  }
}

function initializeFilters() {
  const tags = window.booru.spoileredTagList.concat(window.booru.hiddenTagList).filter((a, b, c) => c.indexOf(a) === b);

  verifyTagsVersion(window.booru.tagsVersion);
  fetchNewOrStaleTags(tags);
}

function unmarshal(data) {
  try {
    return JSON.parse(data);
  } catch {
    return data;
  }
}

function loadBooruData() {
  const booruData = document.querySelector('.js-datastore').dataset;

  // Assign all elements to booru because lazy
  for (const prop in booruData) {
    window.booru[prop] = unmarshal(booruData[prop]);
  }

  window.booru.hiddenFilter = parseSearch(window.booru.hiddenFilter);
  window.booru.spoileredFilter = parseSearch(window.booru.spoileredFilter);

  // Fetch tag metadata and set up filtering
  initializeFilters();

  // CSRF
  window.booru.csrfToken = $('meta[name="csrf-token"]').content;
}

function BooruOnRails() {
  this.apiEndpoint = '/api/v2/';
  this.hiddenTag = '/images/tagblocked.svg';
  this.tagsVersion = 6;
}

window.booru = new BooruOnRails();

export { getTag, loadBooruData };
