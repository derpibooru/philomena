// This is the main application file. Its job is to import any modules that modify global state, and run
// all other functions when the DOM is ready using the `whenReady` utility function.
//
// Import new files and add their exported setup function to the functions array below.

import './ujs';

import { whenReady } from './utils/dom';

import { listenAutocomplete } from './autocomplete';
import { loadBooruData } from './booru';
import { registerEvents } from './boorujs';
import { setupBurgerMenu } from './burger';
import { bindCaptchaLinks } from './captcha';
import { setupComments } from './comment';
import { setupDupeReports } from './duplicate-reports';
import { setSesCookie } from './fp';
import { setupGalleryEditing } from './galleries';
import { initImagesClientside } from './imagesclientside';
import { bindImageTarget } from './image-expansion';
import { setupEvents } from './misc';
import { setupNotifications } from './notifications';
import { setupPreviews } from './preview';
import { setupQuickTag } from './quick-tag';
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
import { setupGameProgress } from './game';

whenReady(
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
  setupGameProgress,
);

// When developing CSS, include the relevant CSS you're working on here
// in order to enable HMR (live reload) on it.
// Would typically be either the theme file, or any additional file
// you later intend to put in the <link> tag.
//
// For example, if you'd like to work on the dark blue theme,
// import the following:
//
// import '../css/application.css';
// import '../css/themes/dark-blue.css';
