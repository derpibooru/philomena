/**
 * DOM events
 */

export function fire(el, event, detail) {
  el.dispatchEvent(new CustomEvent(event, { detail, bubbles: true, cancelable: true }));
}

export function on(node, event, selector, func) {
  delegate(node, event, { [selector]: func });
}

export function delegate(node, event, selectors) {
  node.addEventListener(event, e => {
    for (const selector in selectors) {
      const target = e.target.closest(selector);
      if (target && selectors[selector](e, target) === false) break;
    }
  });
}
