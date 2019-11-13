import { $ } from './utils/dom';
import parseSearch from './match_query';
import store from './utils/store';

/* Store a tag locally, marking the retrieval time */
function persistTag(tagData) {
  tagData.fetchedAt = new Date().getTime() / 1000;
  store.set(`bor_tags_${tagData.id}`, tagData);
}

function isStale(tag) {
  const now = new Date().getTime() / 1000;
  return tag.fetchedAt === null || tag.fetchedAt < (now - 604800);
}

function clearTags() {
  Object.keys(localStorage).forEach(key => {
    if (key.substring(0, 9) === 'bor_tags_') {
      store.remove(key);
    }
  });
}

/* Returns a single tag, or a dummy tag object if we don't know about it yet */
function getTag(tagId) {
  const stored = store.get(`bor_tags_${tagId}`);

  if (stored) {
    return stored;
  }

  return {
    id: tagId,
    name: '(unknown tag)',
    images: 0,
    spoiler_image_uri: null,
  };
}

/* Fetches lots of tags in batches and stores them locally */
function fetchAndPersistTags(tagIds) {
  const chunk = 40;
  for (let i = 0; i < tagIds.length; i += chunk) {
    const ids = tagIds.slice(i, i + chunk);

    /*fetch(`${window.booru.apiEndpoint}tags/fetch_many.json?ids[]=${ids.join('&ids[]=')}`)
      .then(response => response.json())
      .then(data => data.tags.forEach(tag => persistTag(tag)));*/
  }
}

/* Figure out which tags in the list we don't know about */
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
  const tags = window.booru.spoileredTagList
    .concat(window.booru.hiddenTagList)
    .filter((a, b, c) => c.indexOf(a) === b);

  verifyTagsVersion(window.booru.tagsVersion);
  fetchNewOrStaleTags(tags);
}

function unmarshal(data) {
  try { return JSON.parse(data); }
  catch (_) { return data; }
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
  this.hiddenTag = '/tagblocked.svg';
  this.tagsVersion = 5;
}

window.booru = new BooruOnRails();

export { getTag, loadBooruData };
