/**
 * Functions to execute when the DOM is ready
 */

import { whenReady } from './utils/dom';

import { listenAutocomplete } from './autocomplete';
import { loadBooruData } from './booru';
import { registerEvents } from './boorujs';
import { setupBurgerMenu } from './burger';
import { bindCaptchaLinks } from './captcha';
import { setupComments } from './comment';
import { setupDupeReports } from './duplicate_reports';
import { setSesCookie } from './fp';
import { setupGalleryEditing } from './galleries';
import { initImagesClientside } from './imagesclientside';
import { bindImageTarget } from './image_expansion';
import { setupEvents } from './misc';
import { setupNotifications } from './notifications';
import { setupPreviews } from './preview';
import { setupQuickTag } from './quick-tag';
import { initializeListener } from './resizablemedia';
import { setupSettings } from './settings';
import { listenForKeys } from './shortcuts';
import { initTagDropdown } from './tags';
import { setupTagListener } from './tagsinput';
import { setupTagEvents } from './tagsmisc';
import { setupTimestamps } from './timeago';
import { setupImageUpload } from './upload';
import { setupSearch } from './search';
import { setupToolbar } from './markdowntoolbar';
import { hideStaffTools } from './staffhider';
import { pollOptionCreator } from './poll';
import { warnAboutPMs } from './pmwarning';
import { imageSourcesCreator } from './sources';

const functions = [
  loadBooruData,
  listenAutocomplete,
  registerEvents,
  setupBurgerMenu,
  bindCaptchaLinks,
  initImagesClientside,
  setupComments,
  setupDupeReports,
  setSesCookie,
  setupGalleryEditing,
  bindImageTarget,
  setupEvents,
  setupNotifications,
  setupPreviews,
  setupQuickTag,
  initializeListener,
  setupSettings,
  listenForKeys,
  initTagDropdown,
  setupTagListener,
  setupTagEvents,
  setupTimestamps,
  setupImageUpload,
  setupSearch,
  setupToolbar,
  hideStaffTools,
  pollOptionCreator,
  warnAboutPMs,
  imageSourcesCreator,
];

whenReady(() => {
  functions.forEach(fn => {
    try {
      fn();
    } catch (err: unknown) {
      console.log(`${fn.name} ran with errors.`);

      if (err instanceof Error) {
        console.log(`The error was:\n\n${err.message}`);
      }
    }
  });
});
