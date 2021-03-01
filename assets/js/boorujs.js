/**
 * BoorUJS
 *
 * Apply event-based actions through data-* attributes. The attributes are structured like so: [data-event-action]
 */

import { $, $$ } from './utils/dom';
import { fetchHtml, handleError } from './utils/requests';
import { showBlock } from './utils/image';
import { addTag } from './tagsinput';

// Event types and any qualifying conditions - return true to not run action
const types = {
  click(event) { return event.button !== 0; /* Left-click only */ },

  change() { /* No qualifier */ },

  fetchcomplete() { /* No qualifier */ },
};

const actions = {
  hide(data) { selectorCb(data.base, data.value, el => el.classList.add('hidden')); },

  tabHide(data) { selectorCbChildren(data.base, data.value, el => el.classList.add('hidden')); },

  show(data) { selectorCb(data.base, data.value, el => el.classList.remove('hidden')); },

  toggle(data) { selectorCb(data.base, data.value, el => el.classList.toggle('hidden')); },

  submit(data) { selectorCb(data.base, data.value, el => el.submit()); },

  disable(data) { selectorCb(data.base, data.value, el => el.disabled = true); },

  copy(data) { document.querySelector(data.value).select();
    document.execCommand('copy'); },

  inputvalue(data) { document.querySelector(data.value).value = data.el.dataset.setValue; },

  selectvalue(data) { document.querySelector(data.value).value = data.el.querySelector(':checked').dataset.setValue; },

  checkall(data) { $$(`${data.value} input[type=checkbox]`).forEach(c => { c.checked = !c.checked; }) },

  focus(data) { document.querySelector(data.value).focus(); },

  preventdefault() { /* The existence of this entry is enough */ },

  addtag(data) {
    addTag(document.querySelector(data.el.closest('[data-target]').dataset.target), data.el.dataset.tagName);
  },

  tab(data) {
    const block = data.el.parentNode.parentNode,
      newTab = $(`.block__tab[data-tab="${data.value}"]`),
      loadTab = data.el.dataset.loadTab;

    // Switch tab
    const selectedTab = block.querySelector('.selected');
    if (selectedTab) {
      selectedTab.classList.remove('selected');
    }
    data.el.classList.add('selected');

    // Switch contents
    this.tabHide({ base: block, value: '.block__tab' });
    this.show({ base: block, value: `.block__tab[data-tab="${data.value}"]` });

    // If the tab has a 'data-load-tab' attribute, load and insert the content
    if (loadTab && !newTab.dataset.loaded) {
      fetchHtml(loadTab)
        .then(handleError)
        .then(response => response.text())
        .then(response => newTab.innerHTML = response)
        .then(() => newTab.dataset.loaded = true)
        .catch(() => newTab.textContent = 'Error!');
    }

  },

  unfilter(data) { showBlock(data.el.closest('.image-show-container')); },

};

// Use this function to apply a callback to elements matching the selectors
function selectorCb(base = document, selector, cb) {
  [].forEach.call(base.querySelectorAll(selector), cb);
}

function selectorCbChildren(base = document, selector, cb) {
  const sel = $$(selector, base);

  for (const el of base.children) {
    if (!sel.includes(el)) continue;

    cb(el);
  }
}

function matchAttributes(event) {
  if (!types[event.type](event)) {
    for (const action in actions) {

      const attr = `data-${event.type}-${action.toLowerCase()}`,
        el = event.target && event.target.closest(`[${attr}]`),
        value = el && el.getAttribute(attr);

      if (el) {
        // Return true if you don't want to preventDefault
        actions[action]({ attr, el, value }) || event.preventDefault();
      }

    }
  }
}

function registerEvents() {
  for (const type in types) document.addEventListener(type, matchAttributes);
}

export { registerEvents };
