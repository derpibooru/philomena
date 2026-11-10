import { fireEvent } from '@testing-library/dom';
import { $ } from '../utils/dom';
import type { BooruObject } from '../booru';
import type { AstMatcher } from '../query/types';

vi.mock('../utils/requests', () => ({
  fetchJson: vi.fn(),
}));

import { fetchJson } from '../utils/requests';
import { setupInteractions, displayInteractionSet } from '../interactions';

type InteractionLike = Parameters<typeof displayInteractionSet>[0][number];

function setWindowBooru({ signedIn = true, interactions = [], disabled = [] as string[] } = {}) {
  window.booru = {
    csrfToken: 't',
    timeAgo: () => {},
    spoilerType: 'off',
    imagesWithDownvotingDisabled: disabled,
    watchedTagList: [],
    spoileredTagList: [],
    ignoredTagList: [],
    hiddenTagList: [],
    userRole: 'user',
    userIsSignedIn: signedIn,
    userCanEditFilter: false,
    hiddenFilter: (() => false) as AstMatcher,
    spoileredFilter: (() => false) as AstMatcher,
    interactions: interactions as BooruObject['interactions'],
    hideStaffTools: false,
    fancyTagUpload: false,
    fancyTagEdit: false,
  } as BooruObject;
}

function setupDom({ withList = false } = {}) {
  document.body.innerHTML = `
  <input class="js-interaction-cache" value='{}'>
  ${withList ? '<div id="imagelist-container"></div>' : ''}
  <div class="image" data-image-id="42">
    <a class="interaction--upvote" data-image-id="42"><i></i></a>
    <a class="interaction--downvote" data-image-id="42"><i></i></a>
    <a class="interaction--fave" data-image-id="42"><i></i></a>
    <a class="interaction--hide" data-image-id="42"><i></i></a>
    <span class="score" data-image-id="42"></span>
    <span class="favorites" data-image-id="42"></span>
    <span class="upvotes" data-image-id="42"></span>
    <span class="downvotes" data-image-id="42"></span>
  </div>`;
}

function mockFetchJsonScore(score: Partial<{ score: number; faves: number; upvotes: number; downvotes: number }>) {
  vi.mocked(fetchJson).mockResolvedValue({
    ok: true,
    json: async () => ({ score: 1, faves: 2, upvotes: 3, downvotes: 4, ...score }),
  } as unknown as Response);
}

describe('interactions', () => {
  beforeEach(() => {
    vi.mocked(fetchJson).mockReset();
    document.body.innerHTML = '';
  });

  it('initializes logged out interactions', () => {
    setWindowBooru({ signedIn: false });
    setupDom();

    setupInteractions();

    expect($('a.interaction--fave')!.getAttribute('href')).toBe('/sessions/new');
    expect($('a.interaction--upvote')!.getAttribute('href')).toBe('/sessions/new');
    expect($('a.interaction--downvote')!.getAttribute('href')).toBe('/sessions/new');
  });

  it('fires POST interact for inactive upvote and updates score/classes', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();
    mockFetchJsonScore({ score: 10, upvotes: 11 });

    setupInteractions();

    const upvote = $('a.interaction--upvote')!;
    fireEvent.click(upvote, { button: 0 });

    expect(fetchJson).toHaveBeenCalled();
    await new Promise(r => setTimeout(r, 0));
    expect($('.score')!.textContent).toBe('10');
    expect($('.upvotes')!.textContent).toBe('11');
    expect(upvote.classList.contains('active')).toBe(true);
  });

  it('fires POST interact for inactive downvote and updates classes', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();
    mockFetchJsonScore({ score: 9, downvotes: 1 });

    setupInteractions();

    const downvote = $('a.interaction--downvote')!;
    fireEvent.click(downvote, { button: 0 });

    expect(fetchJson).toHaveBeenCalled();
    await new Promise(r => setTimeout(r, 0));
    expect(downvote.classList.contains('active')).toBe(true);
  });

  it('does nothing when downvote restricted on inactive click', () => {
    setWindowBooru({ signedIn: true, disabled: ['42'] });
    setupDom({ withList: true });

    setupInteractions();

    const downvote = $('a.interaction--downvote')!;
    fireEvent.click(downvote, { button: 0 });

    expect(fetchJson).not.toHaveBeenCalled();
  });

  it('displayInteractionSet applies classes from server interactions and cache', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    // server interactions

    const serverInteractions: InteractionLike[] = [
      { image_id: 42, interaction_type: 'voted', value: 'up' } as unknown as InteractionLike,
      { image_id: '42', interaction_type: 'hidden' } as unknown as InteractionLike,
      { image_id: 42, interaction_type: 'faved' } as unknown as InteractionLike,
    ];

    displayInteractionSet(serverInteractions);

    // cached interactions (exercise code path; assertions separate below)
    const cache = $<HTMLInputElement>('.js-interaction-cache');

    if (cache) {
      cache.value = JSON.stringify({});
      cache.value = JSON.stringify({
        '42voted': { imageId: '42', interactionType: 'voted', value: 'down' },
      });
    }

    const cachedInteractions: InteractionLike[] = [
      { imageId: '42', interactionType: 'voted', value: 'down' } as unknown as InteractionLike,
    ];

    displayInteractionSet(cachedInteractions);

    expect($('.interaction--upvote')!.classList.contains('active')).toBe(true);
    expect($('.interaction--hide')!.classList.contains('active')).toBe(true);
    expect($('.interaction--fave')!.classList.contains('active')).toBe(true);
  });

  it('active-state click triggers DELETE and resets', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    // mark upvote active
    $('a.interaction--upvote')!.classList.add('active');

    mockFetchJsonScore({ score: 5, upvotes: 4 });

    setupInteractions();

    const upvote = $('a.interaction--upvote')!;
    fireEvent.click(upvote, { button: 0 });

    await new Promise(r => setTimeout(r, 0));
    expect(upvote.classList.contains('active')).toBe(false);
    expect($('.score')!.textContent).toBe('5');
    expect($('.upvotes')!.textContent).toBe('4');
  });

  it('fires POST interact for inactive fave and updates classes', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();
    mockFetchJsonScore({ faves: 99 });

    setupInteractions();

    const fave = $('a.interaction--fave')!;
    fireEvent.click(fave, { button: 0 });

    expect(fetchJson).toHaveBeenCalled();
    await new Promise(r => setTimeout(r, 0));
    expect(fave.classList.contains('active')).toBe(true);
    // fave click also shows upvoted per logic
    expect($('a.interaction--upvote')!.classList.contains('active')).toBe(true);
  });

  it('fires POST interact for inactive hide and updates classes', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();
    mockFetchJsonScore({});

    setupInteractions();

    const hide = $('a.interaction--hide')!;
    fireEvent.click(hide, { button: 0 });

    expect(fetchJson).toHaveBeenCalled();
    await new Promise(r => setTimeout(r, 0));
    expect(hide.classList.contains('active')).toBe(true);
  });

  it('active-state downvote triggers DELETE and resets', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    const downvote = $('a.interaction--downvote')!;
    downvote.classList.add('active');
    mockFetchJsonScore({ downvotes: 0 });

    setupInteractions();

    fireEvent.click(downvote, { button: 0 });
    await new Promise(r => setTimeout(r, 0));
    expect(downvote.classList.contains('active')).toBe(false);
  });

  it('ignores non-left clicks in bindInteractions', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    setupInteractions();

    const upvote = $('a.interaction--upvote')!;
    fireEvent.click(upvote, { button: 1 }); // middle click

    expect(fetchJson).not.toHaveBeenCalled();
  });

  it('loadInteractions sets title on anchor when no icon present', () => {
    setWindowBooru({ signedIn: true, interactions: [], disabled: ['42'] });
    setupDom({ withList: true });

    // Remove all children to hit the third fallback branch
    const downvote = $('a.interaction--downvote')!;
    downvote.innerHTML = '';

    setupInteractions();

    expect(downvote.classList.contains('disabled')).toBe(true);
    expect(downvote.getAttribute('title')).toMatch('Neigh!');
  });

  it('displayInteractionSet handles voted with no up/down value (no class changes)', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    const upvote = $('a.interaction--upvote')!;
    const downvote = $('a.interaction--downvote')!;

    // voted with empty value should not alter classes
    displayInteractionSet([{ image_id: '42', interaction_type: 'voted', value: '' } as unknown as InteractionLike]);

    expect(upvote.classList.contains('active')).toBe(false);
    expect(downvote.classList.contains('active')).toBe(false);
  });

  it('left-click on non-target does not trigger interactions', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    setupInteractions();

    const div = document.createElement('div');
    document.body.appendChild(div);
    fireEvent.click(div, { button: 0 });

    expect(fetchJson).not.toHaveBeenCalled();
  });

  it('displayInteractionSet applies downvoted class from server interaction', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    displayInteractionSet([{ image_id: '42', interaction_type: 'voted', value: 'down' } as unknown as InteractionLike]);

    expect($('.interaction--downvote')!.classList.contains('active')).toBe(true);
  });

  it('active-state fave triggers DELETE and resets', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    const fave = $('a.interaction--fave')!;
    fave.classList.add('active');
    mockFetchJsonScore({ faves: 0 });

    setupInteractions();

    fireEvent.click(fave, { button: 0 });
    await new Promise(r => setTimeout(r, 0));
    expect(fave.classList.contains('active')).toBe(false);
  });

  it('active-state hide triggers DELETE and resets', async () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    const hide = $('a.interaction--hide')!;
    hide.classList.add('active');
    mockFetchJsonScore({});

    setupInteractions();

    fireEvent.click(hide, { button: 0 });
    await new Promise(r => setTimeout(r, 0));
    expect(hide.classList.contains('active')).toBe(false);
  });

  it('displayInteractionSet applies hidden class from cache interaction', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    const hide = $('a.interaction--hide')!;
    expect(hide.classList.contains('active')).toBe(false);

    const cached: InteractionLike[] = [
      { imageId: '42', interactionType: 'hidden', value: '' } as unknown as InteractionLike,
    ];
    displayInteractionSet(cached);

    expect(hide.classList.contains('active')).toBe(true);
  });

  it('displayInteractionSet applies upvoted class from cache interaction', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    const up = $('a.interaction--upvote')!;
    expect(up.classList.contains('active')).toBe(false);

    const cached: InteractionLike[] = [
      { imageId: '42', interactionType: 'voted', value: 'up' } as unknown as InteractionLike,
    ];
    displayInteractionSet(cached);

    expect(up.classList.contains('active')).toBe(true);
  });

  it('active-state downvote with restriction does nothing (no DELETE, no reset)', () => {
    setWindowBooru({ signedIn: true, disabled: ['42'] });
    setupDom({ withList: true });

    const downvote = $('a.interaction--downvote')!;
    downvote.classList.add('active');

    setupInteractions();
    vi.mocked(fetchJson).mockClear();

    fireEvent.click(downvote, { button: 0 });

    expect(fetchJson).not.toHaveBeenCalled();
    expect(downvote.classList.contains('active')).toBe(true);
  });

  it('displayInteractionSet applies faved class from cache interaction', () => {
    setWindowBooru({ signedIn: true });
    setupDom();

    const fave = $('a.interaction--fave')!;
    expect(fave.classList.contains('active')).toBe(false);

    const cached: InteractionLike[] = [
      { imageId: '42', interactionType: 'faved', value: '' } as unknown as InteractionLike,
    ];
    displayInteractionSet(cached);

    expect(fave.classList.contains('active')).toBe(true);
  });
});
