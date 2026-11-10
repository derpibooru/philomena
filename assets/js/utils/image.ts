import { assertNotNull } from './assert';
import { $, clearEl } from './dom';
import store from './store';

function getSpoilerOverlay(img: HTMLDivElement): HTMLElement {
  // This always exists in markup, regardless of the image type and state
  return assertNotNull($<HTMLElement>('.js-spoiler-info-overlay', img));
}

function getFilterExplanation(img: HTMLDivElement): HTMLElement {
  // This always exists in markup, regardless of the image type and state
  return assertNotNull($<HTMLElement>('.filter-explanation', img));
}

function showVideoThumb(img: HTMLDivElement, size: string, uris: Record<string, string>) {
  const thumbUri = uris[size];

  const vidEl = $<HTMLVideoElement>('video', img);
  if (!vidEl) return false;

  const imgEl = $<HTMLImageElement>('img', img);
  if (!imgEl || imgEl.classList.contains('hidden')) return false;

  imgEl.classList.add('hidden');

  vidEl.innerHTML = `
    <source src="${thumbUri}" type="video/webm"/>
    <source src="${thumbUri.replace(/webm$/, 'mp4')}" type="video/mp4"/>
  `;
  vidEl.classList.remove('hidden');
  vidEl.play();

  getSpoilerOverlay(img).classList.add('hidden');

  return true;
}

export function showThumb(img: HTMLDivElement) {
  const size = img.dataset.size;
  const urisString = img.dataset.uris;
  if (!size || !urisString) return false;

  const uris: Record<string, string> = JSON.parse(urisString);
  const thumbUri = uris[size].replace(/webm$/, 'gif');

  const picEl = $<HTMLPictureElement>('picture', img);
  if (!picEl) return showVideoThumb(img, size, uris);

  const imgEl = $<HTMLImageElement>('img', picEl);
  if (!imgEl || imgEl.src.indexOf(thumbUri) !== -1) return false;

  if (store.get('serve_hidpi') && !thumbUri.endsWith('.gif')) {
    // Check whether the HiDPI option is enabled, and make an exception for GIFs due to their size
    const x2Size = size === 'medium' ? uris.large : uris.medium;
    // use even larger thumb if normal size is medium already
    imgEl.srcset = `${thumbUri} 1x, ${x2Size} 2x`;
  }

  imgEl.src = thumbUri;
  const overlay = getSpoilerOverlay(img);

  if (uris[size].indexOf('.webm') !== -1) {
    overlay.classList.remove('hidden');
    overlay.innerHTML = 'WebM';
  } else {
    overlay.classList.add('hidden');
  }

  return true;
}

export function showBlock(img: HTMLDivElement) {
  $<HTMLElement>('.image-filtered', img)?.classList.add('hidden');
  const imageShowClasses = $<HTMLElement>('.image-show', img)?.classList;

  if (imageShowClasses) {
    imageShowClasses.remove('hidden');
    imageShowClasses.add('spoiler-pending');

    const vidEl = $<HTMLVideoElement>('video', img);
    if (vidEl) {
      vidEl.play();
    }
  }
}

function hideVideoThumb(img: HTMLDivElement, spoilerUri: string, reason: string) {
  const vidEl = $<HTMLVideoElement>('video', img);
  if (!vidEl) return;

  const imgEl = $<HTMLImageElement>('img', img);
  const imgOverlay = getSpoilerOverlay(img);
  if (!imgEl) return;

  imgEl.classList.remove('hidden');
  imgEl.src = spoilerUri;

  imgOverlay.innerHTML = reason;
  imgOverlay.classList.remove('hidden');

  clearEl(vidEl);
  vidEl.classList.add('hidden');
  vidEl.pause();
}

export function hideThumb(img: HTMLDivElement, spoilerUri: string, reason: string) {
  const picEl = $<HTMLPictureElement>('picture', img);
  if (!picEl) return hideVideoThumb(img, spoilerUri, reason);

  const imgEl = $<HTMLImageElement>('img', picEl);
  const imgOverlay = getSpoilerOverlay(img);

  if (!imgEl || imgEl.src.indexOf(spoilerUri) !== -1) return;

  imgEl.srcset = '';
  imgEl.src = spoilerUri;

  imgOverlay.innerHTML = reason;
  imgOverlay.classList.remove('hidden');
}

export function spoilerThumb(img: HTMLDivElement, spoilerUri: string, reason: string) {
  hideThumb(img, spoilerUri, reason);

  switch (window.booru.spoilerType) {
    case 'click':
      img.addEventListener('click', event => {
        if (showThumb(img)) event.preventDefault();
      });
      img.addEventListener('mouseleave', () => hideThumb(img, spoilerUri, reason));
      break;
    case 'hover':
      img.addEventListener('mouseenter', () => showThumb(img));
      img.addEventListener('mouseleave', () => hideThumb(img, spoilerUri, reason));
      break;
    default:
      break;
  }
}

export function spoilerBlock(img: HTMLDivElement, spoilerUri: string, reason: string) {
  const imgFiltered = $<HTMLElement>('.image-filtered', img);
  const imgEl = imgFiltered ? $<HTMLImageElement>('img', imgFiltered) : null;
  if (!imgEl) return;

  const imgReason = getFilterExplanation(img);
  const imageShow = $<HTMLElement>('.image-show', img);

  imgEl.src = spoilerUri;
  imgReason.innerHTML = reason;

  imageShow?.classList.add('hidden');
  if (imgFiltered) imgFiltered.classList.remove('hidden');
}
