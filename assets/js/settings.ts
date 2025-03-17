/**
 * Settings.
 */

import { assertNotNull, assertNotUndefined } from './utils/assert';
import { $, $$, hideIf } from './utils/dom';
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

function setupAutocompleteSettings() {
  const autocompleteSettings = assertNotNull($<HTMLElement>('.autocomplete-settings'));
  const autocompleteSearchHistorySettings = assertNotNull($<HTMLElement>('.autocomplete-search-history-settings'));
  const enableSearchAutocomplete = assertNotNull($<HTMLInputElement>('#user_enable_search_ac'));
  const userSearchHistoryHidden = assertNotNull($<HTMLInputElement>('#user_autocomplete_search_history_hidden'));

  // Don't show search history settings if autocomplete is entirely disabled.
  enableSearchAutocomplete.addEventListener('change', () => {
    hideIf(!enableSearchAutocomplete.checked, autocompleteSettings);
  });

  userSearchHistoryHidden.addEventListener('change', () => {
    hideIf(userSearchHistoryHidden.checked, autocompleteSearchHistorySettings);
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
