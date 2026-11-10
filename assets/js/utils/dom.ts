// DOM Utils

type PhilomenaInputElements = HTMLTextAreaElement | HTMLInputElement | HTMLButtonElement;

/**
 * Get the first matching element
 */
export function $<E extends Element = Element>(
  selector: string,
  context: Pick<Document, 'querySelector'> = document,
): E | null {
  return context.querySelector<E>(selector);
}

/**
 * Get every matching element as an array
 */
export function $$<E extends Element = Element>(
  selector: string,
  context: Pick<Document, 'querySelectorAll'> = document,
): E[] {
  const elements = context.querySelectorAll<E>(selector);

  return [...elements];
}

function concat<E>(elements: (E | ConcatArray<E>)[]): E[] {
  const empty: E[] = [];
  return empty.concat(...elements);
}

export function showEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  concat(elements).forEach(el => el.classList.remove('hidden'));
}

export function hideEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  concat(elements).forEach(el => el.classList.add('hidden'));
}

export function toggleEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  concat(elements).forEach(el => el.classList.toggle('hidden'));
}

export function clearEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  concat(elements).forEach(el => {
    while (el.firstChild) el.removeChild(el.firstChild);
  });
}

export function disableEl<E extends PhilomenaInputElements>(...elements: E[] | ConcatArray<E>[]) {
  concat(elements).forEach(el => {
    el.disabled = true;
  });
}

export function enableEl<E extends PhilomenaInputElements>(...elements: E[] | ConcatArray<E>[]) {
  concat(elements).forEach(el => {
    el.disabled = false;
  });
}

export function removeEl<E extends HTMLElement>(...elements: E[] | ConcatArray<E>[]) {
  concat(elements).forEach(el => el.parentNode?.removeChild(el));
}

export function makeEl<Tag extends keyof HTMLElementTagNameMap>(
  tag: Tag,
  attr?: Partial<HTMLElementTagNameMap[Tag]>,
  children: (HTMLElement | string)[] = [],
): HTMLElementTagNameMap[Tag] {
  const el = document.createElement(tag);
  if (attr) {
    for (const prop in attr) {
      const newValue = attr[prop];
      if (newValue) {
        el[prop] = newValue;
      }
    }
  }
  el.append(...children);
  return el;
}

export function onLeftClick(
  callback: (e: MouseEvent) => void,
  context: Pick<GlobalEventHandlers, 'addEventListener' | 'removeEventListener'> = document,
): VoidFunction {
  const handler: typeof callback = event => {
    if (event.button === 0) callback(event);
  };
  context.addEventListener('click', handler);

  return () => context.removeEventListener('click', handler);
}

/**
 * Execute one or more functions when the DOM is ready
 */
export function whenReady(...callbacks: VoidFunction[]): void {
  const handler = () => {
    for (const callback of callbacks) {
      try {
        callback();
      } catch (err: unknown) {
        console.log(`${callback.name} ran with errors.`);

        if (err instanceof Error) {
          console.log(`The error was:\n\n${err.message}`);
        }
      }
    }
  };

  if (document.readyState !== 'loading') {
    handler();
  } else {
    document.addEventListener('DOMContentLoaded', handler);
  }
}

export function escapeHtml(html: string): string {
  return html.replace(/&/g, '&amp;').replace(/>/g, '&gt;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
}

export function escapeCss(css: string): string {
  return css.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

export function findFirstTextNode<N extends Node>(of: Node): N {
  return Array.prototype.filter.call(of.childNodes, el => el.nodeType === Node.TEXT_NODE)[0];
}

export function hideIf(condition: boolean, element: HTMLElement) {
  return setClassIf(condition, element, 'hidden');
}

export function setClassIf(condition: boolean, element: HTMLElement, className: string) {
  if (condition) {
    element.classList.add(className);
  } else {
    element.classList.remove(className);
  }
}
