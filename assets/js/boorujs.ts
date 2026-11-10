/**
 * BoorUJS
 *
 * Apply event-based actions through data-* attributes. The attributes are structured like so: [data-event-action]
 */

import { assertNotUndefined, assertType } from './utils/assert';
import { $, $$ } from './utils/dom';
import { fetchHtml, handleError } from './utils/requests';
import { showBlock } from './utils/image';
import { addTag } from './tagsinput';

declare global {
  interface FetchcompleteEvent extends CustomEvent<Response> {
    target: HTMLElement;
  }

  interface GlobalEventHandlersEventMap {
    fetchcomplete: FetchcompleteEvent;
  }
}

type EventType = 'click' | 'change' | 'fetchcomplete';

interface ActionData {
  el: HTMLElement;
  value: string;
  base?: ParentNode;
}

type EventQualifier = (event: Event) => boolean;
type Action = (data: ActionData) => void;

// Event types and any qualifying conditions - return true to not run action
const types: Record<EventType, EventQualifier> = {
  click(event) {
    return assertType(event, MouseEvent).button !== 0; /* Left-click only */
  },
  change() {
    /* No qualifier */
    return false;
  },
  fetchcomplete() {
    /* No qualifier */
    return false;
  },
};

const actions: Record<string, Action> = {
  hide(data) {
    selectorCb(data.base, data.value, el => el.classList.add('hidden'));
  },
  show(data) {
    selectorCb(data.base, data.value, el => el.classList.remove('hidden'));
  },
  toggle(data) {
    selectorCb(data.base, data.value, el => el.classList.toggle('hidden'));
  },
  submit(data) {
    selectorCb(data.base, data.value, el => {
      if (el instanceof HTMLFormElement) {
        el.submit();
      }
    });
  },
  disable(data) {
    selectorCb(data.base, data.value, el => {
      if (el instanceof HTMLButtonElement || el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) {
        el.disabled = true;
      }
    });
  },
  focus(data) {
    const target = $<HTMLElement>(data.value);
    if (target) {
      target.focus();
    }
  },
  unfilter(data) {
    const container = data.el.closest<HTMLDivElement>('.image-show-container');
    if (container) {
      showBlock(container);
    }
  },
  tabHide(data) {
    selectorCbChildren(data.base, data.value, el => el.classList.add('hidden'));
  },
  preventdefault() {
    /* The existence of this entry is enough */
  },

  copy(data) {
    const target = $<HTMLInputElement | HTMLTextAreaElement>(data.value);
    if (target) {
      target.select();
      document.execCommand('copy');
    }
  },

  inputvalue(data) {
    const target = $<HTMLInputElement | HTMLTextAreaElement>(data.value);
    const setValue = data.el.dataset.setValue;
    if (target && setValue !== undefined) {
      target.value = setValue;
    }
  },

  selectvalue(data) {
    const target = $<HTMLSelectElement | HTMLInputElement>(data.value);
    const checked = $<HTMLInputElement>(':checked', data.el);
    const setValue = checked?.dataset.setValue;

    if (target && setValue !== undefined) {
      target.value = setValue;
    }
  },

  checkall(data) {
    $$<HTMLInputElement>(`${data.value} input[type=checkbox]`).forEach(c => {
      c.checked = !c.checked;
    });
  },

  addtag(data) {
    const targetContainer = data.el.closest<HTMLElement>('[data-target]');
    const tagName = data.el.dataset.tagName;

    if (targetContainer && tagName && targetContainer.dataset.target) {
      const target = $<HTMLInputElement | HTMLTextAreaElement>(targetContainer.dataset.target);

      if (target) {
        addTag(target, tagName);
      }
    }
  },

  hideParent(data) {
    const base = data.el.closest<HTMLElement>(data.value);
    if (base) {
      base.classList.add('hidden');
    }
  },

  tab: switchTab,
};

function switchTab(data: ActionData & { noPushState?: boolean }) {
  const block = data.el.parentNode?.parentNode;
  if (!(block instanceof HTMLElement)) return;

  const newTab = $<HTMLElement>(`.block__tab[data-tab="${data.value}"]`, block);
  const loadTab = data.el.dataset.loadTab;

  // Switch tab
  const selectedTab = $<HTMLElement>('.selected', block);
  if (selectedTab) {
    selectedTab.classList.remove('selected');
  }
  data.el.classList.add('selected');

  // Switch contents
  actions.tabHide({ ...data, base: block, value: '.block__tab' });
  actions.show({ ...data, base: block, value: `.block__tab[data-tab="${data.value}"]` });

  if (!data.noPushState && block.dataset.tabPersistInQueryParams === 'true') {
    // Save navigation state in the URL query params
    const url = new URL(window.location.href);
    url.searchParams.set('tab', data.value);
    window.history.pushState({}, '', url);
  }

  // If the tab has a 'data-load-tab' attribute, load and insert the content
  if (loadTab && newTab && !newTab.dataset.loaded) {
    fetchHtml(loadTab)
      .then(handleError)
      .then(response => response.text())
      .then(response => (newTab.innerHTML = response))
      .then(() => (newTab.dataset.loaded = 'true'))
      .catch(() => (newTab.textContent = 'Error!'));
  }
}

// Use this function to apply a callback to elements matching the selectors
function selectorCb(base: ParentNode = document, selector: string, cb: (el: Element) => void) {
  $$(selector, base).forEach(cb);
}

function selectorCbChildren(base: ParentNode = document, selector: string, cb: (el: Element) => void) {
  const sel = $$(selector, base);

  for (const el of base.children) {
    if (!sel.includes(el)) continue;

    cb(el);
  }
}

function matchAttributes(event: Event) {
  const eventType = event.type as EventType;
  if (!types[eventType] || !types[eventType](event)) {
    for (const action in actions) {
      const attr = `data-${event.type}-${action.toLowerCase()}`;
      const target = event.target;
      const el = target instanceof HTMLElement ? target.closest<HTMLElement>(`[${attr}]`) : null;
      const value = el?.getAttribute(attr) || '';

      if (el && value) {
        actions[action]({ el, value });
        event.preventDefault();
      }
    }
  }
}

export function registerEvents() {
  for (const type in types) {
    document.addEventListener(type, matchAttributes);
  }

  window.addEventListener('popstate', () => {
    const url = new URL(window.location.href);
    const tab = url.searchParams.get('tab');
    const tabs = $$<HTMLElement>(`[data-click-tab]`);
    const explicitTab = tab && tabs.find(btn => btn.dataset.clickTab === tab);
    const tabBtn = explicitTab || tabs.find(btn => btn.dataset.hasOwnProperty('tabDefault'));
    if (tabBtn) {
      switchTab({
        el: tabBtn,
        value: assertNotUndefined(tabBtn.dataset.clickTab),
        // We don't need to push a new state on back/forward navigation, only switch the tab
        noPushState: true,
      });
    }
  });
}
