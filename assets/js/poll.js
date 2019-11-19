import { $, $$, clearEl, removeEl, insertBefore } from './utils/dom';
import { delegate, leftClick } from './utils/events';

function pollOptionRemover(_event, target) {
  removeEl(target.closest('.js-poll-option'));
}

function pollOptionCreator() {
  const addPollOptionButton = $('.js-poll-add-option');

  delegate(document, 'click', {
    '.js-option-remove': leftClick(pollOptionRemover)
  });

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
      const newHtml = prevFieldCopy.outerHTML.replace(/(\d+)/g, `${existingOptionCount}`);

      // Insert copy before the button
      addPollOptionButton.insertAdjacentHTML("beforebegin", newHtml);
      existingOptionCount++;
    }

    // Remove the button if we reached the max number of options
    if (existingOptionCount >= maxOptionCount) {
      removeEl(addPollOptionButton);
    }
  });
}

export { pollOptionCreator };
