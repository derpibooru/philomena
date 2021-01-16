import { clearEl } from './dom';
import store from './store';

function showVideoThumb(img) {
  const size = img.dataset.size;
  const uris = JSON.parse(img.dataset.uris);
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

  img.querySelector('.js-spoiler-info-overlay').classList.add('hidden');

  return true;
}

function showThumb(img) {
  const size = img.dataset.size;
  const uris = JSON.parse(img.dataset.uris);
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
  if (uris[size].indexOf('.webm') !== -1) {
    const overlay = img.querySelector('.js-spoiler-info-overlay');
    overlay.classList.remove('hidden');
    overlay.innerHTML = 'WebM';
  }
  else {
    img.querySelector('.js-spoiler-info-overlay').classList.add('hidden');
  }

  return true;
}

function showBlock(img) {
  img.querySelector('.image-filtered').classList.add('hidden');
  const imageShowClasses = img.querySelector('.image-show').classList;
  imageShowClasses.remove('hidden');
  imageShowClasses.add('spoiler-pending');
}

function hideVideoThumb(img, spoilerUri, reason) {
  const vidEl = img.querySelector('video');
  if (!vidEl) return;

  const imgEl = img.querySelector('img');
  const imgOverlay = img.querySelector('.js-spoiler-info-overlay');
  if (!imgEl) return;

  imgEl.classList.remove('hidden');
  imgEl.src = spoilerUri;
  imgOverlay.innerHTML = reason;
  imgOverlay.classList.remove('hidden');

  clearEl(vidEl);
  vidEl.classList.add('hidden');
  vidEl.pause();
}

function hideThumb(img, spoilerUri, reason) {
  const picEl = img.querySelector('picture');
  if (!picEl) return hideVideoThumb(img, spoilerUri, reason);

  const imgEl = picEl.querySelector('img');
  const imgOverlay = img.querySelector('.js-spoiler-info-overlay');

  if (!imgEl || imgEl.src.indexOf(spoilerUri) !== -1) return;

  imgEl.srcset = '';
  imgEl.src = spoilerUri;
  imgOverlay.innerHTML = reason;
  imgOverlay.classList.remove('hidden');
}

function spoilerThumb(img, spoilerUri, reason) {
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

function spoilerBlock(img, spoilerUri, reason) {
  const imgEl = img.querySelector('.image-filtered img');
  const imgReason = img.querySelector('.filter-explanation');

  if (!imgEl) return;

  imgEl.src = spoilerUri;
  imgReason.innerHTML = reason;

  img.querySelector('.image-show').classList.add('hidden');
  img.querySelector('.image-filtered').classList.remove('hidden');
}

export { showThumb, showBlock, spoilerThumb, spoilerBlock, hideThumb };
