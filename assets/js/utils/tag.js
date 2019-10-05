import { escapeHtml } from './dom';
import { getTag } from '../booru';

function unique(array) {
  return array.filter((a, b, c) => c.indexOf(a) === b);
}

function sortTags(hidden, a, b) {
  // If both tags have a spoiler image, sort by images count desc (hidden) or asc (spoilered)
  if (a.spoiler_image_uri && b.spoiler_image_uri) {
    return hidden ? b.images - a.images : a.images - b.images;
  }
  // If neither has a spoiler image, sort by images count desc
  else if (!a.spoiler_image_uri && !b.spoiler_image_uri) {
    return b.images - a.images;
  }

  // Tag with spoiler image takes precedence
  return a.spoiler_image_uri ? -1 : 1;
}

function getHiddenTags() {
  return unique(window.booru.hiddenTagList)
    .map(tagId => getTag(tagId))
    .sort(sortTags.bind(null, true));
}

function getSpoileredTags() {
  if (window.booru.spoilerType === 'off') return [];

  return unique(window.booru.spoileredTagList)
    .filter(tagId => window.booru.ignoredTagList.indexOf(tagId) === -1)
    .map(tagId => getTag(tagId))
    .sort(sortTags.bind(null, false));
}

function imageHitsTags(img, matchTags) {
  const imageTags = JSON.parse(img.dataset.imageTags);
  return matchTags.filter(t => imageTags.indexOf(t.id) !== -1);
}

function imageHitsComplex(img, matchComplex) {
  return matchComplex.hitsImage(img);
}

function displayTags(tags) {
  const mainTag = tags[0], otherTags = tags.slice(1);
  let list = escapeHtml(mainTag.name), extras;

  if (otherTags.length > 0) {
    extras = otherTags.map(tag => escapeHtml(tag.name)).join(', ');
    list += `<span title="${extras}">, ${extras}</span>`;
  }

  return list;
}

export { getHiddenTags, getSpoileredTags, imageHitsTags, imageHitsComplex, displayTags };
