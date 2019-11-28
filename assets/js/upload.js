/**
 * Fetch and display preview images for various image upload forms.
 */

import { fetchJson, handleError } from './utils/requests';
import { $, $$, hideEl, showEl, makeEl, clearEl } from './utils/dom';
import { addTag } from './tagsinput';

function scrapeUrl(url) {
  return fetchJson('POST', '/images/scrape', { url })
    .then(handleError)
    .then(response => response.json());
}

function setupImageUpload() {
  const imgPreviews = $('#js-image-upload-previews');
  if (!imgPreviews) return;

  const form = imgPreviews.closest('form');
  const [ fileField, remoteUrl, scraperError ] = $$('.js-scraper', form);
  const [ sourceEl, tagsEl, descrEl ] = $$('.js-image-input', form);
  const fetchButton = $('#js-scraper-preview');

  function showImages(images) {
    clearEl(imgPreviews);

    images.forEach((image, index) => {
      const img = makeEl('img', { className: 'scraper-preview--image' });
      img.src = image.camo_url;
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
    }]);

    // Clear any currently cached data, because the file field
    // has higher priority than the scraper:
    remoteUrl.value = '';
    hideError();
  });

  // Watch for files added to the form
  fileField.addEventListener('change', () => { fileField.files.length && reader.readAsDataURL(fileField.files[0]); });

  // Watch for [Fetch] clicks
  fetchButton.addEventListener('click', () => {
    if (!remoteUrl.value) return;

    disableFetch();

    scrapeUrl(remoteUrl.value).then(data => {
      if (data.errors && data.errors.length > 0) {
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
}

export { setupImageUpload };
