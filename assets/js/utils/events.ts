// DOM events

export function fire<El extends Element, D>(el: El, event: string, detail: D) {
  el.dispatchEvent(new CustomEvent<D>(event, { detail, bubbles: true, cancelable: true }));
}

export function on<K extends keyof GlobalEventHandlersEventMap>(node: GlobalEventHandlers, event: K, selector: string, func: ((e: GlobalEventHandlersEventMap[K], target: Element) => boolean)) {
  delegate(node, event, { [selector]: func });
}

export function leftClick<E extends MouseEvent, Target extends EventTarget>(func: (e: E, t: Target) => void) {
  return (event: E, target: Target) => { if (event.button === 0) return func(event, target); };
}

export function delegate<K extends keyof GlobalEventHandlersEventMap>(node: GlobalEventHandlers, event: K, selectors: Record<string, ((e: GlobalEventHandlersEventMap[K], target: Element) => boolean)>) {
  node.addEventListener(event, e => {
    for (const selector in selectors) {
      const evtTarget = e.target as EventTarget | Element | null;
      if (evtTarget && 'closest' in evtTarget && typeof evtTarget.closest === 'function') {
        const target = evtTarget.closest(selector);
        if (target && selectors[selector](e, target) === false) break;
      }
    }
  });
}
