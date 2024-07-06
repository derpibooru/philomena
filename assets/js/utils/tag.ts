import { escapeHtml } from './dom';
import { getTag } from '../booru';
import { AstMatcher } from '../query/types';

export interface TagData {
  id: number;
  name: string;
  images: number;
  spoiler_image_uri: string | null;
  fetchedAt: null | number;
}

function unique<Item>(array: Item[]): Item[] {
  return array.filter((a, b, c) => c.indexOf(a) === b);
}

function sortTags(hidden: boolean, a: TagData, b: TagData): number {
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

export function getHiddenTags(): TagData[] {
  return unique(window.booru.hiddenTagList)
    .map(tagId => getTag(tagId))
    .sort(sortTags.bind(null, true));
}

export function getSpoileredTags(): TagData[] {
  if (window.booru.spoilerType === 'off') return [];

  return unique(window.booru.spoileredTagList)
    .filter(tagId => window.booru.ignoredTagList.indexOf(tagId) === -1)
    .map(tagId => getTag(tagId))
    .sort(sortTags.bind(null, false));
}

export function imageHitsTags(img: HTMLElement, matchTags: TagData[]): TagData[] {
  const imageTagsString = img.dataset.imageTags;
  if (typeof imageTagsString === 'undefined') {
    return [];
  }
  const imageTags = JSON.parse(imageTagsString);
  return matchTags.filter(t => imageTags.indexOf(t.id) !== -1);
}

export function imageHitsComplex(img: HTMLElement, matchComplex: AstMatcher) {
  return matchComplex(img);
}

export function displayTags(tags: TagData[]): string {
  const mainTag = tags[0];
  const otherTags = tags.slice(1);
  let list = escapeHtml(mainTag.name);
  let extras;

  if (otherTags.length > 0) {
    extras = otherTags.map(tag => escapeHtml(tag.name)).join(', ');
    list += `<span title="${extras}">, ${extras}</span>`;
  }

  return list;
}
