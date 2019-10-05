/**
 * Tags Dropdown
 */

import { showEl, hideEl } from './utils/dom';

function addTag(tagId, list) {
  list.push(tagId);
}

function removeTag(tagId, list) {
  list.splice(list.indexOf(tagId), 1);
}

function createTagDropdown(tag) {
  const { userIsSignedIn, userCanEditFilter, watchedTagList, spoileredTagList, hiddenTagList } = window.booru;
  const [ unwatch, watch, unspoiler, spoiler, unhide, hide, signIn, filter ] = [].slice.call(tag.querySelectorAll('.tag__dropdown__link'));
  const [ unwatched, watched, spoilered, hidden ] = [].slice.call(tag.querySelectorAll('.tag__state'));
  const tagId = parseInt(tag.dataset.tagId, 10);

  const actions = {
    unwatch()   { hideEl(unwatch, watched);     showEl(watch, unwatched);     removeTag(tagId, watchedTagList);   },
    watch()     { hideEl(watch, unwatched);     showEl(unwatch, watched);     addTag(tagId, watchedTagList);      },

    unspoiler() { hideEl(unspoiler, spoilered); showEl(spoiler);              removeTag(tagId, spoileredTagList); },
    spoiler()   { hideEl(spoiler);              showEl(unspoiler, spoilered); addTag(tagId, spoileredTagList);    },

    unhide()    { hideEl(unhide, hidden);       showEl(hide);                 removeTag(tagId, hiddenTagList);    },
    hide()      { hideEl(hide);                 showEl(unhide, hidden);       addTag(tagId, hiddenTagList);       },
  };

  const tagIsWatched   = watchedTagList.includes(tagId);
  const tagIsSpoilered = spoileredTagList.includes(tagId);
  const tagIsHidden    = hiddenTagList.includes(tagId);

  const watchedLink    = tagIsWatched   ? unwatch   : watch;
  const spoilerLink    = tagIsSpoilered ? unspoiler : spoiler;
  const hiddenLink     = tagIsHidden    ? unhide    : hide;

  // State symbols (-, S, H, +)
  if (tagIsWatched)      showEl(watched);
  if (tagIsSpoilered)    showEl(spoilered);
  if (tagIsHidden)       showEl(hidden);
  if (!tagIsWatched)     showEl(unwatched);

  // Dropdown links
  if (userIsSignedIn)    showEl(watchedLink);
  if (userCanEditFilter) showEl(spoilerLink);
  if (userCanEditFilter) showEl(hiddenLink);
  if (!userIsSignedIn)   showEl(signIn);
  if (userIsSignedIn &&
     !userCanEditFilter) showEl(filter);

  tag.addEventListener('fetchcomplete', event => actions[event.target.dataset.tagAction]());
}

function initTagDropdown() {
  [].forEach.call(document.querySelectorAll('.tag.dropdown'), createTagDropdown);
}

export { initTagDropdown };
