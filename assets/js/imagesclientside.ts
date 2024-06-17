/**
 * Client-side image filtering/spoilering.
 */

import { assertNotUndefined } from './utils/assert';
import { $$, escapeHtml } from './utils/dom';
import { setupInteractions } from './interactions';
import { showThumb, showBlock, spoilerThumb, spoilerBlock, hideThumb } from './utils/image';
import { TagData, getHiddenTags, getSpoileredTags, imageHitsTags, imageHitsComplex, displayTags } from './utils/tag';
import { AstMatcher } from './query/types';

type CallbackType = 'tags' | 'complex';
type RunCallback = (img: HTMLDivElement, tags: TagData[], type: CallbackType) => void;

function run(
  img: HTMLDivElement,
  tags: TagData[],
  complex: AstMatcher,
  runCallback: RunCallback
): boolean {
  const hit = (() => {
    // Check tags array first to provide more precise filter explanations
    const hitTags = imageHitsTags(img, tags);
    if (hitTags.length !== 0) {
      runCallback(img, hitTags, 'tags');
      return true;
    }

    // No tags matched, try complex filter AST
    const hitComplex = imageHitsComplex(img, complex);
    if (hitComplex) {
      runCallback(img, hitTags, 'complex');
      return true;
    }

    // Nothing matched at all, image can be shown
    return false;
  })();

  if (hit) {
    // Disallow negative interaction on image which is not visible
    window.booru.imagesWithDownvotingDisabled.push(assertNotUndefined(img.dataset.imageId));
  }

  return hit;
}

function bannerImage(tagsHit: TagData[]) {
  if (tagsHit.length > 0) {
    return tagsHit[0].spoiler_image_uri || window.booru.hiddenTag;
  }

  return window.booru.hiddenTag;
}

// TODO: this approach is not suitable for translations because it depends on
// markup embedded in the page adjacent to this text

/* eslint-disable indent */

function hideThumbTyped(img: HTMLDivElement, tagsHit: TagData[], type: CallbackType) {
  const bannerText = type === 'tags' ? `[HIDDEN] ${displayTags(tagsHit)}`
                                     : '[HIDDEN] <i>(Complex Filter)</i>';
  hideThumb(img, bannerImage(tagsHit), bannerText);
}

function spoilerThumbTyped(img: HTMLDivElement, tagsHit: TagData[], type: CallbackType) {
  const bannerText = type === 'tags' ? displayTags(tagsHit)
                                     : '<i>(Complex Filter)</i>';
  spoilerThumb(img, bannerImage(tagsHit), bannerText);
}

function hideBlockTyped(img: HTMLDivElement, tagsHit: TagData[], type: CallbackType) {
  const bannerText = type === 'tags' ? `This image is tagged <code>${escapeHtml(tagsHit[0].name)}</code>, which is hidden by `
                                     : 'This image was hidden by a complex tag expression in ';
  spoilerBlock(img, bannerImage(tagsHit), bannerText);
}

function spoilerBlockTyped(img: HTMLDivElement, tagsHit: TagData[], type: CallbackType) {
  const bannerText = type === 'tags' ? `This image is tagged <code>${escapeHtml(tagsHit[0].name)}</code>, which is spoilered by `
                                     : 'This image was spoilered by a complex tag expression in ';
  spoilerBlock(img, bannerImage(tagsHit), bannerText);
}

/* eslint-enable indent */

export function filterNode(node: Pick<Document, 'querySelectorAll'>) {
  const hiddenTags = getHiddenTags(), spoileredTags = getSpoileredTags();
  const { hiddenFilter, spoileredFilter } = window.booru;

  // Image thumb boxes with vote and fave buttons on them
  $$<HTMLDivElement>('.image-container', node)
    .filter(img => !run(img, hiddenTags,    hiddenFilter,    hideThumbTyped))
    .filter(img => !run(img, spoileredTags, spoileredFilter, spoilerThumbTyped))
    .forEach(img => showThumb(img));

  // Individual image pages and images in posts/comments
  $$<HTMLDivElement>('.image-show-container', node)
    .filter(img => !run(img, hiddenTags,    hiddenFilter,    hideBlockTyped))
    .filter(img => !run(img, spoileredTags, spoileredFilter, spoilerBlockTyped))
    .forEach(img => showBlock(img));
}

export function initImagesClientside() {
  window.booru.imagesWithDownvotingDisabled = [];
  // This fills the imagesWithDownvotingDisabled array
  filterNode(document);
  // Once the array is populated, we can initialize interactions
  setupInteractions();
}
