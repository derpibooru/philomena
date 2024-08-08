/**
 * Settings.
 */

import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$ } from './utils/dom';
import store from './utils/store';

export function setupSettings() {
  if (!$('#js-setting-table')) return;

  const localCheckboxes = $$<HTMLInputElement>('[data-tab="local"] input[type="checkbox"]');
  const themeSelect = $<HTMLSelectElement>('#user_theme');
  const styleSheet = assertNotNull($<HTMLLinkElement>('head link[rel="stylesheet"]'));

  // Local settings
  localCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', () => {
      store.set(checkbox.id.replace('user_', ''), checkbox.checked);
    });
  });

  // Theme preview
  if (themeSelect) {
    themeSelect.addEventListener('change', () => {
      styleSheet.href = assertNotUndefined(themeSelect.options[themeSelect.selectedIndex].dataset.themePath);
    });
  }
}
