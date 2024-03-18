import '@testing-library/jest-dom';
import { matchNone } from '../js/query/boolean';

window.booru = {
  csrfToken: 'mockCsrfToken',
  hiddenTag: '/mock-tagblocked.svg',
  hiddenTagList: [],
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
