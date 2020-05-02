/**
 * Settings.
 */

import { $, $$ } from './utils/dom';
import store from './utils/store';

export function setupSettings() {

  if (!$('#js-setting-table')) return;

  const localCheckboxes = $$('[data-tab="local"] input[type="checkbox"]');
  const themeSelect = $('#user_theme');
  const styleSheet = $('head link[rel="stylesheet"]');

  // Local settings
  localCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', () => {
      store.set(checkbox.id.replace('user_', ''), checkbox.checked);
    });
  });

  // Theme preview
  themeSelect && themeSelect.addEventListener('change', () => {
    styleSheet.href = themeSelect.options[themeSelect.selectedIndex].dataset.themePath;
  });

}
