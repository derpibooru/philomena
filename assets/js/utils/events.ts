// DOM events

import '../../types/ujs';

export interface PhilomenaAvailableEventsMap {
  dragstart: DragEvent;
  dragover: DragEvent;
  dragenter: DragEvent;
  dragleave: DragEvent;
  dragend: DragEvent;
  drop: DragEvent;
  click: MouseEvent;
  submit: Event;
  reset: Event;
  fetchcomplete: FetchcompleteEvent;
}

export interface PhilomenaEventElement {
  addEventListener<K extends keyof PhilomenaAvailableEventsMap>(
    type: K,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    listener: (this: Document | HTMLElement, ev: PhilomenaAvailableEventsMap[K]) => any,
    options?: boolean | AddEventListenerOptions | undefined,
  ): void;
}

export function fire<El extends Element, D>(el: El, event: string, detail: D) {
  el.dispatchEvent(new CustomEvent<D>(event, { detail, bubbles: true, cancelable: true }));
}

export function on<K extends keyof PhilomenaAvailableEventsMap>(
  node: PhilomenaEventElement,
  event: K,
  selector: string,
  func: (e: PhilomenaAvailableEventsMap[K], target: Element) => boolean,
) {
  delegate(node, event, { [selector]: func });
}

export function leftClick<E extends MouseEvent, Target extends EventTarget>(func: (e: E, t: Target) => void) {
  return (event: E, target: Target) => {
    if (event.button === 0) return func(event, target);
  };
}

export function oncePersistedPageShown(func: (e: PageTransitionEvent) => void) {
  const controller = new AbortController();

  window.addEventListener(
    'pageshow',
    (e: PageTransitionEvent) => {
      if (!e.persisted) {
        return;
      }

      controller.abort();
      func(e);
    },
    { signal: controller.signal },
  );
}

export function delegate<K extends keyof PhilomenaAvailableEventsMap, Target extends Element>(
  node: PhilomenaEventElement,
  event: K,
  selectors: Record<string, (e: PhilomenaAvailableEventsMap[K], target: Target) => void | boolean>,
) {
  node.addEventListener(event, e => {
    for (const selector in selectors) {
      const evtTarget = e.target as EventTarget | Target | null;
      if (evtTarget && 'closest' in evtTarget && typeof evtTarget.closest === 'function') {
        const target = evtTarget.closest(selector) as Target;
        if (target && selectors[selector](e, target) === false) break;
      }
    }
  });
}
