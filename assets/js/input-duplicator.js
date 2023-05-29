import { $, $$, disableEl, enableEl, removeEl } from './utils/dom';
import { delegate, leftClick } from './utils/events';

/**
 * @typedef InputDuplicatorOptions
 * @property {string} addButtonSelector
 * @property {string} fieldSelector
 * @property {string} maxInputCountSelector
 * @property {string} removeButtonSelector
 */

/**
 * @param {InputDuplicatorOptions} options
 */
function inputDuplicatorCreator({
  addButtonSelector,
  fieldSelector,
  maxInputCountSelector,
  removeButtonSelector
}) {
  const addButton = $(addButtonSelector);
  if (!addButton) {
    return;
  }

  const form = addButton.closest('form');
  const fieldRemover = (event, target) => {
    event.preventDefault();

    // Prevent removing the final field element to not "brick" the form
    const existingFields = $$(fieldSelector, form);
    if (existingFields.length <= 1) {
      return;
    }

    removeEl(target.closest(fieldSelector));
    enableEl(addButton);
  };

  delegate(document, 'click', {
    [removeButtonSelector]: leftClick(fieldRemover)
  });


  const maxOptionCount = parseInt($(maxInputCountSelector, form).innerHTML, 10);
  addButton.addEventListener('click', e => {
    e.preventDefault();

    const existingFields = $$(fieldSelector, form);
    let existingFieldsLength = existingFields.length;
    if (existingFieldsLength < maxOptionCount) {
      // The last element matched by the `fieldSelector` will be the last field, make a copy
      const prevField = existingFields[existingFieldsLength - 1];
      const prevFieldCopy = prevField.cloneNode(true);
      const prevFieldCopyInputs = $$('input', prevFieldCopy);
      prevFieldCopyInputs.forEach(prevFieldCopyInput => {
        // Reset new input's value
        prevFieldCopyInput.value = '';
        prevFieldCopyInput.removeAttribute('value');
        // Increment sequential attributes of the input
        ['name', 'id'].forEach(attr => {
          prevFieldCopyInput.setAttribute(attr, prevFieldCopyInput[attr].replace(/\d+/g, `${existingFieldsLength}`));
        });
      });

      // Insert copy before the last field's next sibling, or if none, at the end of its parent
      if (prevField.nextElementSibling) {
        prevField.parentNode.insertBefore(prevFieldCopy, prevField.nextElementSibling);
      }
      else {
        prevField.parentNode.appendChild(prevFieldCopy);
      }
      existingFieldsLength++;
    }

    // Remove the button if we reached the max number of options
    if (existingFieldsLength >= maxOptionCount) {
      disableEl(addButton);
    }
  });
}

export { inputDuplicatorCreator };
