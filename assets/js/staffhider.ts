/**
 * StaffHider
 *
 * Hide staff elements if enabled in the settings.
 */

import { $$, hideEl } from './utils/dom';

export function hideStaffTools() {
  if (window.booru.hideStaffTools === 'true') {
    $$<HTMLElement>('.js-staff-action').forEach(el => hideEl(el));
  }
}
