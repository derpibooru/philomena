/**
 * DOM events
 */

export function fire(el, event, detail) {
  el.dispatchEvent(new CustomEvent(event, { detail, bubbles: true, cancelable: true }));
}

export function on(node, event, selector, func) {
  delegate(node, event, { [selector]: func });
}

export function leftClick(func) {
  return (event, target) => { if (event.button === 0) return func(event, target); };
}

export function delegate(node, event, selectors) {
  node.addEventListener(event, e => {
    for (const selector in selectors) {
      const target = e.target.closest(selector);
      if (target && selectors[selector](e, target) === false) break;
    }
  });
}

/**
 * Runs the provided `func` if it hasn't been called for at least `time` ms
 * @template {(...any[]) => any} T
 * @param {number} time
 * @param {T} func
 * @return {T}
 */
export function debounce(time, func) {
  let timerId = null;

  return function(...args) {
    // Cancels the setTimeout method execution
    timerId && clearTimeout(timerId);

    // Executes the func after delay time.
    timerId = setTimeout(() => func(...args), time);
  };
}
