/**
 * Fetch and display preview images for various image upload forms.
 */

import { fetchJson, handleError } from './utils/requests';
import { $, $$, clearEl, hideEl, makeEl, showEl } from './utils/dom';
import { addTag } from './tagsinput';

const MATROSKA_MAGIC = 0x1a45dfa3;

function scrapeUrl(url) {
  return fetchJson('POST', '/images/scrape', { url })
    .then(handleError)
    .then(response => response.json());
}

function elementForEmbeddedImage({ camo_url, type }) {
  // The upload was fetched from the scraper and is a path name
  if (typeof camo_url === 'string') {
    return makeEl('img', { className: 'scraper-preview--image', src: camo_url });
  }

  // The upload was fetched from a file input and is an ArrayBuffer
  const objectUrl = URL.createObjectURL(new Blob([camo_url], { type }));
  const tagName = new DataView(camo_url).getUint32(0) === MATROSKA_MAGIC ? 'video' : 'img';
  return makeEl(tagName, { className: 'scraper-preview--image', src: objectUrl });
}

function setupImageUpload() {
  const imgPreviews = $('#js-image-upload-previews');
  if (!imgPreviews) return;

  const form = imgPreviews.closest('form');
  const [fileField, remoteUrl, scraperError] = $$('.js-scraper', form);
  const descrEl = $('.js-image-descr-input', form);
  const tagsEl = $('.js-image-tags-input', form);
  const sourceEl = $$('.js-source-url', form).find(input => input.value === '');
  const fetchButton = $('#js-scraper-preview');
  if (!fetchButton) return;

  function showImages(images) {
    clearEl(imgPreviews);

    images.forEach((image, index) => {
      const img = elementForEmbeddedImage(image);
      const imgWrap = makeEl('span', { className: 'scraper-preview--image-wrapper' });
      imgWrap.appendChild(img);

      const label = makeEl('label', { className: 'scraper-preview--label' });
      const radio = makeEl('input', {
        type: 'radio',
        className: 'scraper-preview--input',
      });
      if (image.url) {
        radio.name = 'scraper_cache';
        radio.value = image.url;
      }
      if (index === 0) {
        radio.checked = true;
      }
      label.appendChild(radio);
      label.appendChild(imgWrap);
      imgPreviews.appendChild(label);
    });
  }
  function showError() {
    clearEl(imgPreviews);
    showEl(scraperError);
    enableFetch();
  }
  function hideError()    { hideEl(scraperError); }
  function disableFetch() { fetchButton.setAttribute('disabled', ''); }
  function enableFetch()  { fetchButton.removeAttribute('disabled'); }

  const reader = new FileReader();

  reader.addEventListener('load', event => {
    showImages([{
      camo_url: event.target.result,
      type: fileField.files[0].type
    }]);

    // Clear any currently cached data, because the file field
    // has higher priority than the scraper:
    remoteUrl.value = '';
    disableFetch();
    hideError();
  });

  // Watch for files added to the form
  fileField.addEventListener('change', () => { fileField.files.length && reader.readAsArrayBuffer(fileField.files[0]); });

  // Watch for [Fetch] clicks
  fetchButton.addEventListener('click', () => {
    if (!remoteUrl.value) return;

    disableFetch();

    scrapeUrl(remoteUrl.value).then(data => {
      if (data === null) {
        scraperError.innerText = 'No image found at that address.';
        showError();
        return;
      }
      else if (data.errors && data.errors.length > 0) {
        scraperError.innerText = data.errors.join(' ');
        showError();
        return;
      }

      hideError();

      // Set source
      if (sourceEl) sourceEl.value = sourceEl.value || data.source_url || '';
      // Set description
      if (descrEl) descrEl.value = descrEl.value || data.description || '';
      // Add author
      if (tagsEl && data.author_name) addTag(tagsEl, `artist:${data.author_name.toLowerCase()}`);
      // Clear selected file, if any
      fileField.value = '';
      showImages(data.images);

      enableFetch();
    }).catch(showError);
  });

  // Fetch on "enter" in url field
  remoteUrl.addEventListener('keydown', event => {
    if (event.keyCode === 13) { // Hit enter
      fetchButton.click();
    }
  });

  // Enable/disable the fetch button based on content in the image scraper. Fetching with no URL makes no sense.
  remoteUrl.addEventListener('input', () => {
    if (remoteUrl.value.length > 0) {
      enableFetch();
    }
    else {
      disableFetch();
    }
  });

  if (remoteUrl.value.length > 0) {
    enableFetch();
  }
  else {
    disableFetch();
  }

  // Catch unintentional navigation away from the page

  function beforeUnload(event) {
    // Chrome requires returnValue to be set
    event.preventDefault();
    event.returnValue = '';
  }

  function registerBeforeUnload() {
    window.addEventListener('beforeunload', beforeUnload);
  }

  function unregisterBeforeUnload() {
    window.removeEventListener('beforeunload', beforeUnload);
  }

  fileField.addEventListener('change', registerBeforeUnload);
  fetchButton.addEventListener('click', registerBeforeUnload);
  form.addEventListener('submit', unregisterBeforeUnload);
}

export { setupImageUpload };
