/**
 * Interactions.
 */

import { fetchJson } from './utils/requests';
import { $ } from './utils/dom';

const endpoints = {
  vote(imageId) { return `/images/${imageId}/vote` },
  fave(imageId) { return `/images/${imageId}/fave` },
  hide(imageId) { return `/images/${imageId}/hide` },
};

const spoilerDownvoteMsg =
  'Neigh! - Remove spoilered tags from your filters to downvote from thumbnails';

/* Quick helper function to less verbosely iterate a QSA */
function onImage(id, selector, cb) {
  [].forEach.call(
    document.querySelectorAll(`${selector}[data-image-id="${id}"]`), cb);
}

/* Since JS modifications to webpages, except form inputs, are not stored
 * in the browser navigation history, we store a cache of the changes in a
 * form to allow interactions to persist on navigation. */

function getCache() {
  const cacheEl = $('.js-interaction-cache');
  return Object.values(JSON.parse(cacheEl.value));
}

function modifyCache(callback) {
  const cacheEl = $('.js-interaction-cache');
  cacheEl.value = JSON.stringify(callback(JSON.parse(cacheEl.value)));
}

function cacheStatus(image_id, interaction_type, value) {
  modifyCache(cache => {
    cache[`${image_id}${interaction_type}`] = { image_id, interaction_type, value };
    return cache;
  });
}

function uncacheStatus(image_id, interaction_type) {
  modifyCache(cache => {
    delete cache[`${image_id}${interaction_type}`];
    return cache;
  });
}

function setScore(imageId, data) {
  onImage(imageId, '.score',
    el => el.textContent = data.score);
  onImage(imageId, '.favorites',
    el => el.textContent = data.faves);
  onImage(imageId, '.upvotes',
    el => el.textContent = data.upvotes);
  onImage(imageId, '.downvotes',
    el => el.textContent = data.downvotes);
}

/* These change the visual appearance of interaction links.
 * Their classes also effect their behavior due to event delegation. */

function showUpvoted(imageId) {
  cacheStatus(imageId, 'voted', 'up');
  onImage(imageId, '.interaction--upvote',
    el => el.classList.add('active'));
}

function showDownvoted(imageId) {
  cacheStatus(imageId, 'voted', 'down');
  onImage(imageId, '.interaction--downvote',
    el => el.classList.add('active'));
}

function showFaved(imageId) {
  cacheStatus(imageId, 'faved', '');
  onImage(imageId, '.interaction--fave',
    el => el.classList.add('active'));
}

function showHidden(imageId) {
  cacheStatus(imageId, 'hidden', '');
  onImage(imageId, '.interaction--hide',
    el => el.classList.add('active'));
}

function resetVoted(imageId) {
  uncacheStatus(imageId, 'voted');

  onImage(imageId, '.interaction--upvote',
    el => el.classList.remove('active'));

  onImage(imageId, '.interaction--downvote',
    el => el.classList.remove('active'));
}

function resetFaved(imageId) {
  uncacheStatus(imageId, 'faved');
  onImage(imageId, '.interaction--fave',
    el => el.classList.remove('active'));
}

function resetHidden(imageId) {
  uncacheStatus(imageId, 'hidden');
  onImage(imageId, '.interaction--hide',
    el => el.classList.remove('active'));
}

function interact(type, imageId, method, data = {}) {
  return fetchJson(method, endpoints[type](imageId), data)
    .then(res => res.json())
    .then(res => setScore(imageId, res));
}

function displayInteractionSet(interactions) {
  interactions.forEach(i => {
    switch (i.interaction_type) {
      case 'faved':
        showFaved(i.image_id);
        break;
      case 'hidden':
        showHidden(i.image_id);
        break;
      default:
        if (i.value === 'up') showUpvoted(i.image_id);
        if (i.value === 'down') showDownvoted(i.image_id);
    }
  });
}

function loadInteractions() {

  /* Set up the actual interactions */
  displayInteractionSet(window.booru.interactions);
  displayInteractionSet(getCache());

  /* Next part is only for image index pages
   * TODO: find a better way to do this */
  if (!document.getElementById('imagelist-container')) return;

  /* Users will blind downvote without this */
  window.booru.imagesWithDownvotingDisabled.forEach(i => {
    onImage(i, '.interaction--downvote', a => {

      // TODO Use a 'js-' class to target these instead
      const icon = a.querySelector('i') || a.querySelector('.oc-icon-small');

      icon.setAttribute('title', spoilerDownvoteMsg);
      a.classList.add('disabled');
      a.addEventListener('click', event => {
        event.stopPropagation();
        event.preventDefault();
      }, true);

    });
  });

}

const targets = {

  /* Active-state targets first */
  '.interaction--upvote.active'(imageId) {
    interact('vote', imageId, 'DELETE')
      .then(() => resetVoted(imageId));
  },
  '.interaction--downvote.active'(imageId) {
    interact('vote', imageId, 'DELETE')
      .then(() => resetVoted(imageId));
  },
  '.interaction--fave.active'(imageId) {
    interact('fave', imageId, 'DELETE')
      .then(() => resetFaved(imageId));
  },
  '.interaction--hide.active'(imageId) {
    interact('hide', imageId, 'DELETE')
      .then(() => resetHidden(imageId));
  },

  /* Inactive targets */
  '.interaction--upvote:not(.active)'(imageId) {
    interact('vote', imageId, 'POST', { up: true })
      .then(() => { resetVoted(imageId); showUpvoted(imageId); });
  },
  '.interaction--downvote:not(.active)'(imageId) {
    interact('vote', imageId, 'POST', { up: false })
      .then(() => { resetVoted(imageId); showDownvoted(imageId); });
  },
  '.interaction--fave:not(.active)'(imageId) {
    interact('fave', imageId, 'POST')
      .then(() => { resetVoted(imageId); showFaved(imageId); showUpvoted(imageId); });
  },
  '.interaction--hide:not(.active)'(imageId) {
    interact('hide', imageId, 'POST')
      .then(() => { showHidden(imageId); });
  },

};

function bindInteractions() {
  document.addEventListener('click', event => {

    if (event.button === 0) { // Is it a left-click?
      for (const target in targets) {
        /* Event delegation doesn't quite grab what we want here. */
        const link = event.target && event.target.closest(target);

        if (link) {
          event.preventDefault();
          targets[target](link.dataset.imageId);
        }
      }
    }

  });
}

function loggedOutInteractions() {
  [].forEach.call(document.querySelectorAll('.interaction--fave,.interaction--upvote,.interaction--downvote'),
    a => a.setAttribute('href', '/sessions/new'));
}

function setupInteractions() {
  if (window.booru.userIsSignedIn) {
    bindInteractions();
    loadInteractions();
  }
  else {
    loggedOutInteractions();
  }
}

export { setupInteractions, displayInteractionSet };
