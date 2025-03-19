/**
 * Hamburger menu.
 */

import { $, $$ } from './utils/dom';
import { assertNotNull } from './utils/assert';

function switchClasses(element: HTMLElement, oldClass: string, newClass: string) {
  element.classList.remove(oldClass);
  element.classList.add(newClass);
}

function open(burger: HTMLElement, content: HTMLElement, body: HTMLElement, root: HTMLElement) {
  switchClasses(content, 'close', 'open');
  switchClasses(burger, 'close', 'open');

  root.classList.add('no-overflow-x');
  body.classList.add('no-overflow');
}

function close(burger: HTMLElement, content: HTMLElement, body: HTMLElement, root: HTMLElement) {
  switchClasses(content, 'open', 'close');
  switchClasses(burger, 'open', 'close');

  /* the CSS animation closing the menu finishes in 300ms */
  setTimeout(() => {
    root.classList.remove('no-overflow-x');
    body.classList.remove('no-overflow');
  }, 300);
}

function copyUserLinksTo(burger: HTMLElement) {
  const copy = (links: HTMLCollection) => {
    burger.appendChild(document.createElement('hr'));

    for (const link of links) {
      const burgerLink = link.cloneNode(true) as HTMLElement;
      burgerLink.className = '';
      burger.appendChild(burgerLink);
    }
  };

  $$<HTMLElement>('.js-burger-links').forEach(container => copy(container.children));
}

export function setupBurgerMenu() {
  // Burger menu should exist on all pages.
  const burger = assertNotNull($<HTMLElement>('#burger'));
  const toggle = assertNotNull($<HTMLElement>('#js-burger-toggle'));
  const content = assertNotNull($<HTMLElement>('#container'));
  const body = document.body;
  const root = document.documentElement;

  copyUserLinksTo(burger);

  document.addEventListener('click', event => {
    if (!(event.target instanceof Node)) {
      return;
    }

    if (toggle.contains(event.target)) {
      event.preventDefault();

      if (content.classList.contains('open')) {
        close(burger, content, body, root);
      } else {
        open(burger, content, body, root);
      }

      return;
    }

    if (content.contains(event.target)) {
      if (content.classList.contains('open')) {
        close(burger, content, body, root);
      }
    }
  });
}
