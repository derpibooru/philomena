// DOM Utils

/**
 * Get the first matching element
 */
export function $<E extends Element = Element>(selector: string, context: Pick<Document, 'querySelector'> = document): E | null {
  return context.querySelector<E>(selector);
}

/**
 * Get every matching element as an array
 */
export function $$<E extends Element = Element>(selector: string, context: Pick<Document, 'querySelectorAll'> = document): E[] {
  const elements = context.querySelectorAll<E>(selector);

  return [...elements];
}

export function showEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  ([] as E[]).concat(...elements).forEach(el => el.classList.remove('hidden'));
}

export function hideEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  ([] as E[]).concat(...elements).forEach(el => el.classList.add('hidden'));
}

export function toggleEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  ([] as E[]).concat(...elements).forEach(el => el.classList.toggle('hidden'));
}

export function clearEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  ([] as E[]).concat(...elements).forEach(el => {
    while (el.firstChild) el.removeChild(el.firstChild);
  });
}

export function removeEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  ([] as E[]).concat(...elements).forEach(el => el.parentNode?.removeChild(el));
}

export function makeEl<Tag extends keyof HTMLElementTagNameMap>(tag: Tag, attr?: Partial<HTMLElementTagNameMap[Tag]>): HTMLElementTagNameMap[Tag] {
  const el = document.createElement(tag);
  if (attr) {
    for (const prop in attr) {
      const newValue = attr[prop];
      if (typeof newValue !== 'undefined') {
        el[prop] = newValue as Exclude<typeof newValue, undefined>;
      }
    }
  }
  return el;
}

export function insertBefore(existingElement: HTMLElement, newElement: HTMLElement) {
  existingElement.parentNode?.insertBefore(newElement, existingElement);
}

export function onLeftClick(callback: (e: MouseEvent) => boolean | void, context: Pick<GlobalEventHandlers, 'addEventListener' | 'removeEventListener'> = document): VoidFunction {
  const handler: typeof callback = event => {
    if (event.button === 0) callback(event);
  };
  context.addEventListener('click', handler);

  return () => context.removeEventListener('click', handler);
}

/**
 * Execute a function when the DOM is ready
 */
export function whenReady(callback: VoidFunction): void {
  if (document.readyState !== 'loading') {
    callback();
  }
  else {
    document.addEventListener('DOMContentLoaded', callback);
  }
}

export function escapeHtml(html: string): string {
  return html.replace(/&/g, '&amp;')
    .replace(/>/g, '&gt;')
    .replace(/</g, '&lt;')
    .replace(/"/g, '&quot;');
}

export function escapeCss(css: string): string {
  return css.replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"');
}

export function findFirstTextNode<N extends Node>(of: Node): N {
  return Array.prototype.filter.call(of.childNodes, el => el.nodeType === Node.TEXT_NODE)[0];
}
