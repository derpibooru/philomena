import '@testing-library/jest-dom';

const blankFilter = {
  leftOperand: null,
  negate: false,
  op: null,
  rightOperand: null,
};

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
  hiddenFilter: blankFilter,
  spoileredFilter: blankFilter,
  tagsVersion: 5
};
