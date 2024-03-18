import { makeUserMatcher } from '../user';

describe('User field parsing', () => {
  beforeEach(() => {
    /* eslint-disable camelcase */
    window.booru.interactions = [
      {image_id: 0, user_id: 0, interaction_type: 'faved', value: null},
      {image_id: 0, user_id: 0, interaction_type: 'voted', value: 'up'},
      {image_id: 1, user_id: 0, interaction_type: 'voted', value: 'down'},
      {image_id: 2, user_id: 0, interaction_type: 'hidden', value: null},
    ];
    /* eslint-enable camelcase */
  });

  it('should parse my:faves', () => {
    const matcher = makeUserMatcher('faves');

    expect(matcher('', 'my', 0)).toBe(true);
    expect(matcher('', 'my', 1)).toBe(false);
    expect(matcher('', 'my', 2)).toBe(false);
  });

  it('should parse my:upvotes', () => {
    const matcher = makeUserMatcher('upvotes');

    expect(matcher('', 'my', 0)).toBe(true);
    expect(matcher('', 'my', 1)).toBe(false);
    expect(matcher('', 'my', 2)).toBe(false);
  });

  it('should parse my:downvotes', () => {
    const matcher = makeUserMatcher('downvotes');

    expect(matcher('', 'my', 0)).toBe(false);
    expect(matcher('', 'my', 1)).toBe(true);
    expect(matcher('', 'my', 2)).toBe(false);
  });

  it('should not parse other my: fields', () => {
    const hiddenMatcher = makeUserMatcher('hidden');
    const watchedMatcher = makeUserMatcher('watched');

    expect(hiddenMatcher('', 'my', 0)).toBe(false);
    expect(hiddenMatcher('', 'my', 1)).toBe(false);
    expect(hiddenMatcher('', 'my', 2)).toBe(false);
    expect(watchedMatcher('', 'my', 0)).toBe(false);
    expect(watchedMatcher('', 'my', 1)).toBe(false);
    expect(watchedMatcher('', 'my', 2)).toBe(false);
  });
});
