/**
 * StaffHider
 *
 * Hide staff elements if enabled in the settings.
 */

import store from './utils/store';

/**
 * Preview the hiding of staff tools in the local settings.
 */
export function hideStaffTools() {
  store.watchAll(updatedKey => {
    if (updatedKey !== 'hide_staff_tools') {
      return;
    }

    // This is the data attribute CSS is relying upon to hide the staff tools.
    // Its initial state will be set by the server to prevent staff tools from appearing on every page load.
    document.body.dataset.hideStaffTools = store.get(updatedKey) === true ? 'true' : 'false';
  });
}
