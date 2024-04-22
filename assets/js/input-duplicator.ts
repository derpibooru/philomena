import { assertNotNull } from './utils/assert';
import { $, $$, disableEl, enableEl, removeEl } from './utils/dom';
import { delegate, leftClick } from './utils/events';

export interface InputDuplicatorOptions {
  addButtonSelector: string;
  fieldSelector: string;
  maxInputCountSelector: string;
  removeButtonSelector: string;
}

export function inputDuplicatorCreator({
  addButtonSelector,
  fieldSelector,
  maxInputCountSelector,
  removeButtonSelector
}: InputDuplicatorOptions) {
  const addButton = $<HTMLButtonElement>(addButtonSelector);
  if (!addButton) {
    return;
  }

  const form = assertNotNull(addButton.closest('form'));
  const fieldRemover = (event: MouseEvent, target: HTMLElement) => {
    event.preventDefault();

    // Prevent removing the final field element to not "brick" the form
    const existingFields = $$(fieldSelector, form);
    if (existingFields.length <= 1) {
      return;
    }

    removeEl(assertNotNull(target.closest<HTMLElement>(fieldSelector)));
    enableEl(addButton);
  };

  delegate(form, 'click', {
    [removeButtonSelector]: leftClick(fieldRemover)
  });


  const maxOptionCountElement = assertNotNull($(maxInputCountSelector, form));
  const maxOptionCount = parseInt(maxOptionCountElement.innerHTML, 10);

  addButton.addEventListener('click', e => {
    e.preventDefault();

    const existingFields = $$<HTMLElement>(fieldSelector, form);
    let existingFieldsLength = existingFields.length;

    if (existingFieldsLength < maxOptionCount) {
      // The last element matched by the `fieldSelector` will be the last field, make a copy
      const prevField = existingFields[existingFieldsLength - 1];
      const prevFieldCopy = prevField.cloneNode(true) as HTMLElement;

      $$<HTMLInputElement>('input', prevFieldCopy).forEach(prevFieldCopyInput => {
        // Reset new input's value
        prevFieldCopyInput.value = '';
        prevFieldCopyInput.removeAttribute('value');

        // Increment sequential attributes of the input
        prevFieldCopyInput.setAttribute('name', prevFieldCopyInput.name.replace(/\d+/g, `${existingFieldsLength}`));
        prevFieldCopyInput.setAttribute('id', prevFieldCopyInput.id.replace(/\d+/g, `${existingFieldsLength}`));
      });

      prevField.insertAdjacentElement('afterend', prevFieldCopy);

      existingFieldsLength++;
    }

    // Remove the button if we reached the max number of options
    if (existingFieldsLength >= maxOptionCount) {
      disableEl(addButton);
    }
  });
}
