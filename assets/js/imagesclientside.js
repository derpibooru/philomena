/**
 * Client-side image filtering/spoilering.
 */

import { $$, escapeHtml } from './utils/dom';
import { setupInteractions } from './interactions';
import { showThumb, showBlock, spoilerThumb, spoilerBlock, hideThumb } from './utils/image';
import { getHiddenTags, getSpoileredTags, imageHitsTags, imageHitsComplex, displayTags } from './utils/tag';

function runFilter(img, test, runCallback) {
  if (!test || test.length === 0) return false;

  runCallback(img, test);

  // I don't like this.
  window.booru.imagesWithDownvotingDisabled.push(img.dataset.imageId);

  return true;
}

// ---

function filterThumbSimple(img, tagsHit)  { hideThumb(img, tagsHit[0].spoiler_image_uri || window.booru.hiddenTag, `[HIDDEN] ${displayTags(tagsHit)}`); }
function spoilerThumbSimple(img, tagsHit) { spoilerThumb(img, tagsHit[0].spoiler_image_uri || window.booru.hiddenTag, displayTags(tagsHit)); }
function filterThumbComplex(img)          { hideThumb(img, window.booru.hiddenTag, '[HIDDEN] <i>(Complex Filter)</i>'); }
function spoilerThumbComplex(img)         { spoilerThumb(img, window.booru.hiddenTag, '<i>(Complex Filter)</i>'); }

function filterBlockSimple(img, tagsHit)  { spoilerBlock(img, tagsHit[0].spoiler_image_uri || window.booru.hiddenTag, `This image is tagged <code>${escapeHtml(tagsHit[0].name)}</code>, which is hidden by `); }
function spoilerBlockSimple(img, tagsHit) { spoilerBlock(img, tagsHit[0].spoiler_image_uri || window.booru.hiddenTag, `This image is tagged <code>${escapeHtml(tagsHit[0].name)}</code>, which is spoilered by `); }
function filterBlockComplex(img)          { spoilerBlock(img, window.booru.hiddenTag, 'This image was hidden by a complex tag expression in '); }
function spoilerBlockComplex(img)         { spoilerBlock(img, window.booru.hiddenTag, 'This image was spoilered by a complex tag expression in '); }

// ---

function thumbTagFilter(tags, img)         { return runFilter(img, imageHitsTags(img, tags), filterThumbSimple); }
function thumbComplexFilter(complex, img)  { return runFilter(img, imageHitsComplex(img, complex), filterThumbComplex); }
function thumbTagSpoiler(tags, img)        { return runFilter(img, imageHitsTags(img, tags), spoilerThumbSimple); }
function thumbComplexSpoiler(complex, img) { return runFilter(img, imageHitsComplex(img, complex), spoilerThumbComplex); }

function blockTagFilter(tags, img)         { return runFilter(img, imageHitsTags(img, tags), filterBlockSimple); }
function blockComplexFilter(complex, img)  { return runFilter(img, imageHitsComplex(img, complex), filterBlockComplex); }
function blockTagSpoiler(tags, img)        { return runFilter(img, imageHitsTags(img, tags), spoilerBlockSimple); }
function blockComplexSpoiler(complex, img) { return runFilter(img, imageHitsComplex(img, complex), spoilerBlockComplex); }

// ---

function filterNode(node = document) {
  const hiddenTags = getHiddenTags(), spoileredTags = getSpoileredTags();
  const { hiddenFilter, spoileredFilter } = window.booru;

  // Image thumb boxes with vote and fave buttons on them
  $$('.image-container', node)
    .filter(img => !thumbTagFilter(hiddenTags, img))
    .filter(img => !thumbComplexFilter(hiddenFilter, img))
    .filter(img => !thumbTagSpoiler(spoileredTags, img))
    .filter(img => !thumbComplexSpoiler(spoileredFilter, img))
    .forEach(img => showThumb(img));

  // Individual image pages and images in posts/comments
  $$('.image-show-container', node)
    .filter(img => !blockTagFilter(hiddenTags, img))
    .filter(img => !blockComplexFilter(hiddenFilter, img))
    .filter(img => !blockTagSpoiler(spoileredTags, img))
    .filter(img => !blockComplexSpoiler(spoileredFilter, img))
    .forEach(img => showBlock(img));
}

function initImagesClientside() {
  window.booru.imagesWithDownvotingDisabled = [];
  // This fills the imagesWithDownvotingDisabled array
  filterNode(document);
  // Once the array is populated, we can initialize interactions
  setupInteractions();
}

export { initImagesClientside, filterNode };
