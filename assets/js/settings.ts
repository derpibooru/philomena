/**
 * Settings.
 */

import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$ } from './utils/dom';
import store from './utils/store';

export function setupSettings() {
  if (!$('#js-setting-table')) return;

  const localCheckboxes = $$<HTMLInputElement>('[data-tab="local"] input[type="checkbox"]');
  const themeSelect = assertNotNull($<HTMLSelectElement>('#user_theme_name'));
  const themeColorSelect = assertNotNull($<HTMLSelectElement>('#user_theme_color'));
  const themePaths: Record<string, string> = JSON.parse(
    assertNotUndefined(assertNotNull($<HTMLDivElement>('#js-theme-paths')).dataset.themePaths),
  );
  const styleSheet = assertNotNull($<HTMLLinkElement>('#js-theme-stylesheet'));

  // Local settings
  localCheckboxes.forEach(checkbox => {
    checkbox.addEventListener('change', () => {
      store.set(checkbox.id.replace('user_', ''), checkbox.checked);
    });
  });

  // Theme preview
  const themePreviewCallback = () => {
    const themeName = assertNotUndefined(themeSelect.options[themeSelect.selectedIndex].value);
    const themeColor = assertNotUndefined(themeColorSelect.options[themeColorSelect.selectedIndex].value);

    styleSheet.href = themePaths[`${themeName}-${themeColor}`];
  };

  themeSelect.addEventListener('change', themePreviewCallback);
  themeColorSelect.addEventListener('change', themePreviewCallback);
}
