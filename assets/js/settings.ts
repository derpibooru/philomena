/**
 * Settings.
 */

import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$ } from './utils/dom';
import store from './utils/store';

function setupThemeSettings() {
  const themeSelect = $<HTMLSelectElement>('#user_theme_name');
  if (!themeSelect) return;

  const themeColorSelect = assertNotNull($<HTMLSelectElement>('#user_theme_color'));
  const themePaths: Record<string, string> = JSON.parse(
    assertNotUndefined(assertNotNull($<HTMLDivElement>('#js-theme-paths')).dataset.themePaths),
  );
  const styleSheet = assertNotNull($<HTMLLinkElement>('#js-theme-stylesheet'));

  // Theme preview
  const themePreviewCallback = () => {
    const themeName = assertNotUndefined(themeSelect.options[themeSelect.selectedIndex].value);
    const themeColor = assertNotUndefined(themeColorSelect.options[themeColorSelect.selectedIndex].value);

    styleSheet.href = themePaths[`${themeName}-${themeColor}`];
  };

  themeSelect.addEventListener('change', themePreviewCallback);
  themeColorSelect.addEventListener('change', themePreviewCallback);
}

function hideIf(element: HTMLElement, condition: boolean) {
  if (condition) {
    element.classList.add('hidden');
  } else {
    element.classList.remove('hidden');
  }
}

function setupAutocompleteSettings() {
  const autocompleteSettings = assertNotNull($<HTMLElement>('.autocomplete-settings'));

  // Don't show search history settings if autocomplete is entirely disabled.
  assertNotNull($('#user_enable_search_ac')).addEventListener('change', event => {
    hideIf(autocompleteSettings, !(event.target as HTMLInputElement).checked);
  });

  const autocompleteSearchHistorySettings = assertNotNull($<HTMLElement>('.autocomplete-search-history-settings'));

  assertNotNull($('#user_autocomplete_search_history_hidden')).addEventListener('change', event => {
    hideIf(autocompleteSearchHistorySettings, (event.target as HTMLInputElement).checked);
  });
}

export function setupSettings() {
  if (!$('#js-setting-table')) return;

  // Local settings
  for (const input of $$<HTMLInputElement>('[data-tab="local"] input')) {
    input.addEventListener('change', () => {
      const newValue = input.type === 'checkbox' ? input.checked : input.value;

      store.set(input.id.replace('user_', ''), newValue);
    });
  }

  setupThemeSettings();
  setupAutocompleteSettings();
}
