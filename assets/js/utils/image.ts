import { clearEl } from './dom';
import store from './store';

function showVideoThumb(img: HTMLDivElement) {
  const size = img.dataset.size;
  const urisString = img.dataset.uris;
  if (!size || !urisString) return;

  const uris = JSON.parse(urisString);
  const thumbUri = uris[size];

  const vidEl = img.querySelector('video');
  if (!vidEl) return false;

  const imgEl = img.querySelector('img');
  if (!imgEl || imgEl.classList.contains('hidden')) return false;

  imgEl.classList.add('hidden');

  vidEl.innerHTML = `
    <source src="${thumbUri}" type="video/webm"/>
    <source src="${thumbUri.replace(/webm$/, 'mp4')}" type="video/mp4"/>
  `;
  vidEl.classList.remove('hidden');
  vidEl.play();

  const overlay = img.querySelector('.js-spoiler-info-overlay');
  if (overlay) overlay.classList.add('hidden');

  return true;
}

export function showThumb(img: HTMLDivElement) {
  const size = img.dataset.size;
  const urisString = img.dataset.uris;
  if (!size || !urisString) return;

  const uris = JSON.parse(urisString);
  const thumbUri = uris[size].replace(/webm$/, 'gif');

  const picEl = img.querySelector('picture');
  if (!picEl) return showVideoThumb(img);

  const imgEl = picEl.querySelector('img');
  if (!imgEl || imgEl.src.indexOf(thumbUri) !== -1) return false;

  if (store.get('serve_hidpi') && !thumbUri.endsWith('.gif')) {
    // Check whether the HiDPI option is enabled, and make an exception for GIFs due to their size
    const x2Size = size === 'medium' ? uris.large : uris.medium;
    // use even larger thumb if normal size is medium already
    imgEl.srcset = `${thumbUri} 1x, ${x2Size} 2x`;
  }

  imgEl.src = thumbUri;
  const overlay = img.querySelector('.js-spoiler-info-overlay');
  if (!overlay) return;

  if (uris[size].indexOf('.webm') !== -1) {
    overlay.classList.remove('hidden');
    overlay.innerHTML = 'WebM';
  }
  else {
    overlay.classList.add('hidden');
  }

  return true;
}

export function showBlock(img: HTMLDivElement) {
  img.querySelector('.image-filtered')?.classList.add('hidden');
  const imageShowClasses = img.querySelector('.image-show')?.classList;
  if (imageShowClasses) {
    imageShowClasses.remove('hidden');
    imageShowClasses.add('spoiler-pending');
  }
}

function hideVideoThumb(img: HTMLDivElement, spoilerUri: string, reason: string) {
  const vidEl = img.querySelector('video');
  if (!vidEl) return;

  const imgEl = img.querySelector('img');
  const imgOverlay = img.querySelector('.js-spoiler-info-overlay');
  if (!imgEl) return;

  imgEl.classList.remove('hidden');
  imgEl.src = spoilerUri;
  if (imgOverlay) {
    imgOverlay.innerHTML = reason;
    imgOverlay.classList.remove('hidden');
  }

  clearEl(vidEl);
  vidEl.classList.add('hidden');
  vidEl.pause();
}

export function hideThumb(img: HTMLDivElement, spoilerUri: string, reason: string) {
  const picEl = img.querySelector('picture');
  if (!picEl) return hideVideoThumb(img, spoilerUri, reason);

  const imgEl = picEl.querySelector('img');
  const imgOverlay = img.querySelector('.js-spoiler-info-overlay');

  if (!imgEl || imgEl.src.indexOf(spoilerUri) !== -1) return;

  imgEl.srcset = '';
  imgEl.src = spoilerUri;
  if (imgOverlay) {
    imgOverlay.innerHTML = reason;
    imgOverlay.classList.remove('hidden');
  }
}

export function spoilerThumb(img: HTMLDivElement, spoilerUri: string, reason: string) {
  hideThumb(img, spoilerUri, reason);

  switch (window.booru.spoilerType) {
    case 'click':
      img.addEventListener('click', event => { if (showThumb(img)) event.preventDefault(); });
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
  const imgEl = img.querySelector<HTMLImageElement>('.image-filtered img');
  const imgReason = img.querySelector<HTMLElement>('.filter-explanation');

  if (!imgEl) return;

  imgEl.src = spoilerUri;
  if (imgReason) {
    imgReason.innerHTML = reason;
  }

  img.querySelector('.image-show')?.classList.add('hidden');
  img.querySelector('.image-filtered')?.classList.remove('hidden');
}
