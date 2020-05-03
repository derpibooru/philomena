/**
 * Fetch and display preview images for various image upload forms.
 */

import { fetchJson, handleError } from './utils/requests';
import { $, $$, hideEl, showEl, makeEl, clearEl, removeEl } from './utils/dom';
import { delegate, leftClick } from './utils/events';
import { addTag } from './tagsinput';

function scrapeUrl(url) {
  return fetchJson('POST', '/images/scrape', { url })
    .then(handleError)
    .then(response => response.json());
}

function setupScraper() {
  const imgPreviews = $('#js-image-upload-previews');
  if (!imgPreviews) return;

  const form = imgPreviews.closest('form');
  const [ fileField, remoteUrl, scraperError ] = $$('.js-scraper', form);
  const [ sourceEl, tagsEl, descrEl ] = $$('.js-image-input', form);
  const fetchButton = $('#js-scraper-preview');
  if (!fetchButton) return;

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
    disableFetch();
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

  // Enable/disable the fetch button based on content in the image scraper. Fetching with no URL makes no sense.
  remoteUrl.addEventListener('input', () => {
    if(remoteUrl.value.length > 0) {
      enableFetch();
    } else {
      disableFetch();
    }
  });
}

function imageSourceRemover(_event, target) {
  removeEl(target.closest('.js-image-source'));
}

function setupSourceCreator() {
  const addImageSourceButton = $('.js-image-add-source');

  delegate(document, 'click', {
    '.js-source-remove': leftClick(imageSourceRemover)
  });

  if (!addImageSourceButton) {
    return;
  }

  const form = addImageSourceButton.closest('form');

  addImageSourceButton.addEventListener('click', e => {
    e.preventDefault();

    let existingOptionCount = $$('.js-image-source', form).length;

    if (existingOptionCount < 10) {
      // The element right before the add button will always be the last field, make a copy
      const prevFieldCopy = addImageSourceButton.previousElementSibling.cloneNode(true);
      const newHtml = prevFieldCopy.outerHTML.replace(/(\d+)/g, `${existingOptionCount}`);

      // Insert copy before the button
      addImageSourceButton.insertAdjacentHTML('beforebegin', newHtml);
    }
    else {
      removeEl(addImageSourceButton);
    }
  });
}

function setupImageUpload() {
  setupScraper();
  setupSourceCreator();
}

export { setupImageUpload };
