import { $, $$, clearEl, removeEl, insertBefore } from './utils/dom';

function pollOptionCreator() {
  const addPollOptionButton = $('.js-poll-add-option');

  if (!addPollOptionButton) {
    return;
  }

  const form = addPollOptionButton.closest('form');
  const maxOptionCount = parseInt($('.js-max-option-count', form).innerHTML, 10);
  addPollOptionButton.addEventListener('click', e => {
    e.preventDefault();

    let existingOptionCount = $$('.js-poll-option', form).length;
    if (existingOptionCount < maxOptionCount) {
      // The element right before the add button will always be the last field, make a copy
      const prevFieldCopy = addPollOptionButton.previousElementSibling.cloneNode(true);
      // Clear its value and increment the N in "Option N" in the placeholder attribute
      clearEl($$('.js-option-id', prevFieldCopy));
      const input = $('.js-option-label', prevFieldCopy);
      input.value = '';
      input.setAttribute('placeholder', input.getAttribute('placeholder').replace(/\d+$/, m => parseInt(m, 10) + 1));
      // Insert copy before the button
      insertBefore(addPollOptionButton, prevFieldCopy);
      existingOptionCount++;
    }

    // Remove the button if we reached the max number of options
    if (existingOptionCount >= maxOptionCount) {
      removeEl(addPollOptionButton);
    }
  });
}

export { pollOptionCreator };
