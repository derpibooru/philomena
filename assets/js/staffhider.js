/**
 * StaffHider
 *
 * Hide staff elements if enabled in the settings.
 */

import { $$ } from './utils/dom';

function hideStaffTools() {
  if (window.booru.hideStaffTools) {
    $$('.js-staff-action').forEach(el => {
      el.classList.add('hidden');
    });
  }
}

export { hideStaffTools };
