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

  var validationChecks = {image: false, tags: false, captcha: true}; //TODO tags and captcha check
  const uploadButton = $('.js-upload-submit');
	const { mimesAllowed } = uploadButton.dataset;
	
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
    
    validationChecks['image'] = true;
    updateValidation();
  }
  function showError() {
    clearEl(imgPreviews);
    showEl(scraperError);
    enableFetch();
    
    validationChecks['image'] = false;
    updateValidation();
  }
  function hideError()    { hideEl(scraperError); }
  function disableFetch() { fetchButton.setAttribute('disabled', ''); }
  function enableFetch()  { fetchButton.removeAttribute('disabled'); }

	function disableUpload() { uploadButton.setAttribute('disabled', ''); }
	function enableUpload()  { uploadButton.removeAttribute('disabled'); }

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
    validationChecks['image'] = true;
    updateValidation();
  });
  
  function updateValidation() {
    disableUpload();
    //for((key,value) in validationChecks) {
    for(const value in validationChecks) {
    	if (value == false) {
  			return;
  		}
		}
		enableUpload();
    return;
  }
  
  // Watch for files added to the form
  fileField.addEventListener('change', () => {
    if (fileField.files.length <= 0) {
    	clearEl(imgPreviews);
    	validationChecks['image'] = false;
    	updateValidation();
      return; 
    }
    
    var file = fileField.files[0];
    
    if (!formats.includes(file.type)) {
      fileField.value = '';
      //clearEl($('#js-image-upload-previews'));
      clearEl(imgPreviews);
      validationChecks['image'] = false;
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
        //fileField[0].value = '';
        validationChecks['image'] = false;
    		updateValidation();
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
