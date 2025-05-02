/**
 * Tags Dropdown
 */

import { $$, showEl, makeEl, hideIf, $, setClassIf } from './utils/dom';
import { assertNotNull, assertNotUndefined } from './utils/assert';
import '../types/ujs';

type TagDropdownActionFunction = () => void;
type TagDropdownActionList = Record<string, TagDropdownActionFunction>;

interface TagState {
  name: string;
  decor: HTMLElement;
  tags: number[];
  enableElem: HTMLElement;
  disableElem: HTMLElement;
  authorized: boolean;
}

class Tag {
  elem: HTMLElement;
  id: number;

  constructor(elem: HTMLElement) {
    this.elem = elem;
    this.id = parseInt(assertNotUndefined(elem.dataset.tagId), 10);
  }

  refresh(state: TagState): void {
    const isEnabled = this.has(state);
    hideIf(!isEnabled, state.decor);
    setClassIf(isEnabled, this.elem, `tag--${state.name}`);

    if (state.authorized) {
      hideIf(isEnabled, state.enableElem);
      hideIf(!isEnabled, state.disableElem);
    }
  }

  has(state: TagState): boolean {
    return state.tags.includes(this.id);
  }

  add(state: TagState): void {
    state.tags.push(this.id);
  }

  remove(state: TagState): void {
    state.tags.splice(state.tags.indexOf(this.id), 1);
  }
}

function createTagDropdown(tagElem: HTMLSpanElement) {
  const tag: Tag = new Tag(tagElem);

  const { userIsSignedIn, userCanEditFilter } = window.booru;
  const [unwatch, watch, unspoiler, spoiler, unhide, hide, signIn, filter] = $$<HTMLElement>(
    '.tag__dropdown__link',
    tag.elem,
  );

  const icon = (className: string) => [makeEl('i', { className }), ' '];

  const states = {
    watched: {
      name: 'watched',
      authorized: userIsSignedIn,
      enableElem: watch,
      disableElem: unwatch,
      decor: makeEl('span', { title: 'Watched' }, icon('fa fa-bookmark')),
      tags: window.booru.watchedTagList,
    },
    spoilered: {
      name: 'spoilered',
      authorized: userCanEditFilter,
      enableElem: spoiler,
      disableElem: unspoiler,
      decor: makeEl('span', { title: 'Spoilered' }, icon('fa fa-eye-low-vision')),
      tags: window.booru.spoileredTagList,
    },
    hidden: {
      name: 'hidden',
      authorized: userCanEditFilter,
      enableElem: hide,
      disableElem: unhide,
      decor: makeEl('span', { title: 'Hidden' }, icon('fa fa-ban')),
      tags: window.booru.hiddenTagList,
    },
  } satisfies Record<string, TagState>;

  const statesList = Object.values(states);
  const stateElems = statesList.map(state => {
    state.decor.classList.add('tag__state', 'hidden');
    return state.decor;
  });

  // Attach the state markers to the tag element as hidden. We'll toggle their
  // visibility according to the tag's state during refresh.
  assertNotNull($<HTMLElement>('.tag__name', tag.elem)).before(...stateElems);

  const actions: TagDropdownActionList = {
    unwatch: () => tag.remove(states.watched),
    watch: () => tag.add(states.watched),

    unspoiler: () => tag.remove(states.spoilered),
    spoiler: () => tag.add(states.spoilered),

    unhide: () => tag.remove(states.hidden),
    hide: () => tag.add(states.hidden),
  };

  // Dropdown links
  if (!userIsSignedIn) showEl(signIn);
  if (userIsSignedIn && !userCanEditFilter) showEl(filter);

  const refresh = () => statesList.forEach(state => tag.refresh(state));

  tag.elem.addEventListener('fetchcomplete', event => {
    const act = assertNotUndefined(event.target.dataset.tagAction);
    actions[act]();
    refresh();
  });

  refresh();
}

export function initTagDropdown() {
  for (const tagSpan of $$<HTMLSpanElement>('.tag.dropdown')) {
    createTagDropdown(tagSpan);
  }
}
