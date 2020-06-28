// This is a manifest file that'll be compiled into including all the files listed below.
// Add new JavaScript/Coffee code in separate files in this directory and they'll automatically
// be included in the compiled file accessible from http://example.com/assets/application.js
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//

// Third-party code, polyfills
import './vendor/promise.polyfill';
import './vendor/fetch.polyfill';
import './vendor/closest.polyfill';
import './vendor/customevent.polyfill';
import './vendor/es6.polyfill';

// Our code
import './ujs';
import './when-ready';

import '../css/themes/default.scss';
import '../css/themes/dark.scss';
import '../css/themes/red.scss';
