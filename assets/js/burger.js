/**
 * Hamburger menu.
 */

function switchClasses(element, oldClass, newClass) {
  element.classList.remove(oldClass);
  element.classList.add(newClass);
}

function open(burger, content, body, root) {
  switchClasses(content, 'close', 'open');
  switchClasses(burger, 'close', 'open');

  root.classList.add('no-overflow-x');
  body.classList.add('no-overflow');
}

function close(burger, content, body, root) {
  switchClasses(content, 'open', 'close');
  switchClasses(burger, 'open', 'close');

  /* the CSS animation closing the menu finishes in 300ms */
  setTimeout(() => {
    root.classList.remove('no-overflow-x');
    body.classList.remove('no-overflow');
  }, 300);
}

function copyArtistLinksTo(burger) {
  const copy = links => {
    burger.appendChild(document.createElement('hr'));

    [].slice.call(links).forEach(link => {
      const burgerLink = link.cloneNode(true);

      burgerLink.className = '';
      burger.appendChild(burgerLink);
    });
  };

  const linksContainers = document.querySelectorAll('.js-burger-links');

  [].slice.call(linksContainers).forEach(container => copy(container.children));
}

function setupBurgerMenu() {
  const burger = document.getElementById('burger');
  const toggle = document.getElementById('js-burger-toggle');
  const content = document.getElementById('container');
  const body = document.body;
  const root = document.documentElement;

  copyArtistLinksTo(burger);

  toggle.addEventListener('click', event => {
    event.stopPropagation();
    event.preventDefault();

    if (content.classList.contains('open')) {
      close(burger, content, body, root);
    }
    else {
      open(burger, content, body, root);
    }
  });
  content.addEventListener('click', () => {
    if (content.classList.contains('open')) {
      close(burger, content, body, root);
    }
  });
}

export { setupBurgerMenu };
