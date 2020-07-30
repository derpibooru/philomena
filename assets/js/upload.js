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
  if (!fetchButton) return;

  //TODO remove tags field from validationChecks, possibly captcha field too
  const validationChecks = {image: false, tags: true, captcha: true}; //TODO tags and captcha check
  const uploadButton = $('.js-upload-submit');
  const mimesAllowed = uploadButton.dataset.mimesAllowed.split(',');
  //TODO add file size and image height/width in a similar way, for avatar upload

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

    validationChecks.image = true;
    updateValidation();
  }
  function showError() {
    clearEl(imgPreviews);
    showEl(scraperError);
    enableFetch();

    validationChecks.image = false;
    updateValidation();
  }
  function hideError()    { hideEl(scraperError); }

  function showImageError(text) {
    clearEl(imgPreviews);

    const newSpan = document.createElement('SPAN');
    newSpan.className = 'help-block';
    newSpan.innerHTML = text;
    fileField.parentElement.appendChild(newSpan);

    validationChecks.image = false;
    updateValidation();
  }

  function hideImageErrors() {
    const parent = fileField.parentElement;
    let toRemove = fileField.nextSibling;
    while (toRemove !== null) {
      parent.removeChild(toRemove);
      toRemove = fileField.nextSibling;
    }
  }

  function disableFetch() { fetchButton.setAttribute('disabled', ''); }
  function enableFetch()  { fetchButton.removeAttribute('disabled'); }

  function disableUpload() { uploadButton.setAttribute('disabled', ''); }
  function enableUpload()  { uploadButton.removeAttribute('disabled'); }

  const reader = new FileReader();

  reader.addEventListener('load', event => {
    const image = new Image();
    image.src = event.target.result;

    //TODO alter showImages() so that it can take in Image objects,
    //     so that an image object isn't loaded twice
    showImages([{
      camo_url: event.target.result,
    }]);

    hideError();

    function imageLoadCallback(imageValid) {
      if (imageValid === true) {
        // Clear any currently cached data, because the file field
        // has higher priority than the scraper:
        remoteUrl.value = '';
        disableFetch();
        hideImageErrors();
        validationChecks.image = true;
      }
      else {
        fileField.value = '';
        clearEl(imgPreviews);
        validationChecks.image = false;
      }
      updateValidation();
    }

    image.onload = function() {
      let error = false;

      if (this.height <= 0 || this.height > 32767) {
        showImageError('Height must be between 1 and 32767');
        error = true;
      }
      if (this.width <= 0 || this.width > 32767) {
        showImageError('Width must be between 1 and 32767');
        error = true;
      }

      imageLoadCallback(!error);

      return true;
    };
  });

  function updateValidation() {
    disableUpload();

    for (const key in validationChecks) {
      if (validationChecks[key] === false) {
        return;
      }
    }

    enableUpload();
    return;
  }

  // Watch for files added to the form
  fileField.addEventListener('change', () => {
    let error = false;
    let file;

    hideImageErrors();

    if (fileField.files.length <= 0) {
      showImageError('Image can\'t be size 0');
      error = true;
    }

    if (error === false) {
      file = fileField.files[0];

      if (!mimesAllowed.includes(file.type)) {
        showImageError('Invalid mime type');
        error = true;
      }

      if (file.size > 26214400) {
        showImageError('File size must be less than 26.2144MB');
        error = true;
      }

      if (file.name.length > 255) {
        showImageError('File name must be less than 255 characters');
        error = true;
      }
    }

    if (error === true) {
      fileField.value = '';
      clearEl(imgPreviews);
      validationChecks.image = false;
      updateValidation();
      return;
    }

    reader.readAsDataURL(file);
  });

  // Watch for [Fetch] clicks
  fetchButton.addEventListener('click', () => {
    if (!remoteUrl.value) return;

    disableFetch();

    scrapeUrl(remoteUrl.value).then(data => {
      if (data === null) {
        scraperError.innerText = 'No image found at that address.';
        showError();
        clearEl(imgPreviews);
        fileField.value = '';
        validationChecks.image = false;
        updateValidation();
        return;
      }
      else if (data.errors && data.errors.length > 0) {
        scraperError.innerText = data.errors.join(' ');
        showError();
        clearEl(imgPreviews);
        fileField.value = '';
        validationChecks.image = false;
        updateValidation();
        return;
      }

      hideError();
      hideImageErrors();

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
  disableUpload();
}

export { setupImageUpload };
