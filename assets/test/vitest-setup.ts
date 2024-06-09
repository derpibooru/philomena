import { matchNone } from '../js/query/boolean';
import '@testing-library/jest-dom/vitest';
import { URL } from 'node:url';
import { Blob } from 'node:buffer';
import { fireEvent } from '@testing-library/dom';

window.booru = {
  // eslint-disable-next-line @typescript-eslint/no-empty-function
  timeAgo: () => {},
  csrfToken: 'mockCsrfToken',
  hiddenTag: '/mock-tagblocked.svg',
  hiddenTagList: [],
  hideStaffTools: 'true',
  ignoredTagList: [],
  imagesWithDownvotingDisabled: [],
  spoilerType: 'off',
  spoileredTagList: [],
  userCanEditFilter: false,
  userIsSignedIn: false,
  watchedTagList: [],
  hiddenFilter: matchNone(),
  spoileredFilter: matchNone(),
  interactions: [],
  tagsVersion: 5
};

// https://github.com/jsdom/jsdom/issues/1721#issuecomment-1484202038
// jsdom URL and Blob are missing most of the implementation
// Use the node version of these types instead
Object.assign(globalThis, { URL, Blob });

// Prevents an error when calling `form.submit()` directly in
// the code that is being tested
HTMLFormElement.prototype.submit = function() {
  fireEvent.submit(this);
};
