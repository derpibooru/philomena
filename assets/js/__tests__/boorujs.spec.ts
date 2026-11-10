import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent } from '@testing-library/dom';

// Mocks must be declared before importing the module under test
vi.mock('../utils/image', () => ({
  showBlock: vi.fn(),
}));

vi.mock('../utils/requests', () => ({
  fetchHtml: vi.fn(async () => new Response('Loaded content')),
  handleError: vi.fn(x => x),
}));

vi.mock('../tagsinput', () => ({
  addTag: vi.fn(),
}));

import { showBlock } from '../utils/image';
import { fetchHtml } from '../utils/requests';
import { addTag } from '../tagsinput';
import { registerEvents } from '../boorujs';
import { $, $$ } from '../utils/dom';

describe('boorujs', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    document.body.innerHTML = '';
  });

  describe('click actions', () => {
    beforeEach(() => {
      registerEvents();
    });

    it('ignores non-left clicks', () => {
      document.body.innerHTML = `
        <button data-click-hide=".target">Hide</button>
        <div class="target">Content</div>
      `;
      const button = $<HTMLButtonElement>('button')!;
      const target = $<HTMLDivElement>('.target')!;

      // Right click (button 2)
      fireEvent.click(button, { button: 2 });

      // Target should not be hidden because right-click was ignored
      expect(target.classList.contains('hidden')).toBe(false);
    });

    it('hides elements with data-click-hide', () => {
      document.body.innerHTML = `
        <button data-click-hide=".target">Hide</button>
        <div class="target">Content</div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const target = $<HTMLDivElement>('.target')!;

      fireEvent.click(button);

      expect(target.classList.contains('hidden')).toBe(true);
    });

    it('shows elements with data-click-show', () => {
      document.body.innerHTML = `
        <button data-click-show=".target">Show</button>
        <div class="target hidden">Content</div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const target = $<HTMLDivElement>('.target')!;

      fireEvent.click(button);

      expect(target.classList.contains('hidden')).toBe(false);
    });

    it('toggles elements with data-click-toggle', () => {
      document.body.innerHTML = `
        <button data-click-toggle=".target">Toggle</button>
        <div class="target">Content</div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const target = $<HTMLDivElement>('.target')!;

      fireEvent.click(button);
      expect(target.classList.contains('hidden')).toBe(true);

      fireEvent.click(button);
      expect(target.classList.contains('hidden')).toBe(false);
    });

    it('submits forms with data-click-submit', () => {
      document.body.innerHTML = `
        <button data-click-submit="#myform">Submit</button>
        <form id="myform"></form>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const form = $<HTMLFormElement>('form')!;
      let submitted = false;
      form.addEventListener('submit', () => {
        submitted = true;
      });

      fireEvent.click(button);

      expect(submitted).toBe(true);
    });

    it('does not submit non-form elements with data-click-submit', () => {
      document.body.innerHTML = `
        <button data-click-submit=".target">Submit</button>
        <div class="target"></div>
      `;

      const button = $<HTMLButtonElement>('button')!;

      // Should not throw error
      expect(() => fireEvent.click(button)).not.toThrow();
    });

    it('disables input elements with data-click-disable', () => {
      document.body.innerHTML = `
        <button data-click-disable=".target">Disable</button>
        <input class="target" type="text">
      `;

      const button = $<HTMLButtonElement>('[data-click-disable]')!;
      const target = $<HTMLInputElement>('.target')!;

      fireEvent.click(button);

      expect(target.disabled).toBe(true);
    });

    it('does not disable non-disableable elements with data-click-disable', () => {
      document.body.innerHTML = `
        <button data-click-disable=".target">Disable</button>
        <div class="target">Cannot disable</div>
      `;

      const button = $<HTMLButtonElement>('[data-click-disable]')!;

      // Should not throw error
      expect(() => fireEvent.click(button)).not.toThrow();
    });

    it('focuses elements with data-click-focus', () => {
      document.body.innerHTML = `
        <button data-click-focus="#target">Focus</button>
        <input id="target" type="text">
      `;

      const button = $<HTMLButtonElement>('button')!;
      const target = $<HTMLInputElement>('#target')!;

      fireEvent.click(button);

      expect(document.activeElement).toBe(target);
    });

    it('does not focus when element not found with data-click-focus', () => {
      document.body.innerHTML = `
        <button data-click-focus="#target">Focus</button>
      `;

      const button = $<HTMLButtonElement>('button')!;

      // Should not throw error
      expect(() => fireEvent.click(button)).not.toThrow();
    });

    it('hides parent element with data-click-hideparent', () => {
      document.body.innerHTML = `
        <div class="parent">
          <div class="child">
            <button data-click-hideparent=".parent">Hide Parent</button>
          </div>
        </div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const parent = $<HTMLDivElement>('.parent')!;

      fireEvent.click(button);

      expect(parent.classList.contains('hidden')).toBe(true);
    });

    it('does not hide when parent selector does not match with data-click-hideparent', () => {
      document.body.innerHTML = `
        <div class="wrapper">
          <button data-click-hideparent=".nonexistent">Hide Parent</button>
        </div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const wrapper = $<HTMLDivElement>('.wrapper')!;

      fireEvent.click(button);

      expect(wrapper.classList.contains('hidden')).toBe(false);
    });

    it('has preventdefault action', () => {
      // The preventdefault action exists and will cause preventDefault to be called
      // when an element has data-click-preventdefault attribute
      document.body.innerHTML = `
        <a href="/test" data-click-preventdefault="true">Link</a>
      `;

      const link = $<HTMLAnchorElement>('a')!;

      const ev = new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 });
      const prevented = link.dispatchEvent(ev);
      // dispatchEvent returns false if preventDefault was called on a cancelable event
      expect(prevented).toBe(false);
      expect(ev.defaultPrevented).toBe(true);
    });

    it('sets input value with data-click-inputvalue and data-set-value', () => {
      document.body.innerHTML = `
        <button data-click-inputvalue="#input" data-set-value="new value">Set</button>
        <input id="input" type="text" value="old value">
      `;

      const button = $<HTMLButtonElement>('button')!;
      const input = $<HTMLInputElement>('#input')!;

      fireEvent.click(button);

      expect(input.value).toBe('new value');
    });

    it('does not set input value when data-set-value is missing', () => {
      document.body.innerHTML = `
        <button data-click-inputvalue="#input">Set</button>
        <input id="input" type="text" value="old value">
      `;

      const button = $<HTMLButtonElement>('button')!;
      const input = $<HTMLInputElement>('#input')!;

      fireEvent.click(button);

      expect(input.value).toBe('old value');
    });

    it('sets select value from checked radio with data-click-selectvalue', () => {
      document.body.innerHTML = `
        <div data-click-selectvalue="#select">
          <input type="radio" name="choice" value="a" data-set-value="option-a">
          <input type="radio" name="choice" value="b" data-set-value="option-b" checked>
        </div>
        <select id="select">
          <option value="option-a">A</option>
          <option value="option-b">B</option>
        </select>
      `;

      const container = $<HTMLDivElement>('[data-click-selectvalue]')!;
      const select = $<HTMLSelectElement>('#select')!;

      fireEvent.click(container);

      expect(select.value).toBe('option-b');
    });

    it('does not set select value when no radio checked with data-click-selectvalue', () => {
      document.body.innerHTML = `
        <div data-click-selectvalue="#select">
          <input type="radio" name="choice" value="a" data-set-value="option-a">
          <input type="radio" name="choice" value="b" data-set-value="option-b">
        </div>
        <select id="select">
          <option value="option-a">A</option>
          <option value="option-b">B</option>
        </select>
      `;

      const container = $<HTMLDivElement>('[data-click-selectvalue]')!;
      const select = $<HTMLSelectElement>('#select')!;

      const originalValue = select.value;
      fireEvent.click(container);

      expect(select.value).toBe(originalValue);
    });

    it('checks all checkboxes with data-click-checkall', () => {
      document.body.innerHTML = `
        <button data-click-checkall=".container">Check All</button>
        <div class="container">
          <input type="checkbox">
          <input type="checkbox" checked>
          <input type="checkbox">
        </div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const checkboxes = $$<HTMLInputElement>('.container input[type=checkbox]');

      fireEvent.click(button);

      expect(checkboxes[0].checked).toBe(true);
      expect(checkboxes[1].checked).toBe(false); // Was checked, now unchecked
      expect(checkboxes[2].checked).toBe(true);
    });

    it('unfilters image containers with data-click-unfilter', () => {
      document.body.innerHTML = `
        <div class="image-show-container">
          <button data-click-unfilter="true">Show Image</button>
        </div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      const container = $<HTMLDivElement>('.image-show-container')!;

      fireEvent.click(button);

      // Verify the util was called with the container
      expect(showBlock).toHaveBeenCalledTimes(1);
      expect(showBlock).toHaveBeenCalledWith(container);
    });

    it('does not unfilter when not in image-show-container', () => {
      document.body.innerHTML = `
        <button data-click-unfilter="true">Show Image</button>
      `;

      const button = $<HTMLButtonElement>('button')!;

      // Should not throw error
      expect(() => fireEvent.click(button)).not.toThrow();
    });

    it('adds tag with data-click-addtag', () => {
      document.body.innerHTML = `
        <div data-target="#tag-input">
          <button data-click-addtag="true" data-tag-name="test">Add Tag</button>
        </div>
        <textarea id="tag-input"></textarea>
      `;

      const button = $<HTMLButtonElement>('button')!;

      const target = $<HTMLTextAreaElement>('#tag-input')!;

      fireEvent.click(button);

      expect(addTag).toHaveBeenCalledTimes(1);
      expect(addTag).toHaveBeenCalledWith(target, 'test');
    });

    it('does not add tag when data-tag-name is missing', () => {
      document.body.innerHTML = `
        <div data-target="#tag-input">
          <button data-click-addtag="true">Add Tag</button>
        </div>
        <input id="tag-input" type="text" value="">
      `;

      const button = $<HTMLButtonElement>('button')!;
      const input = $<HTMLInputElement>('#tag-input')!;

      fireEvent.click(button);

      // Tag should not be added
      expect(input.value).toBe('');
      expect(addTag).not.toHaveBeenCalled();
    });

    it('does not add tag when target selector does not match any element', () => {
      document.body.innerHTML = `
        <div data-target="#missing-target">
          <button data-click-addtag="true" data-tag-name="ghost">Add Tag</button>
        </div>
      `;

      const button = $<HTMLButtonElement>('button')!;
      fireEvent.click(button);

      expect(addTag).not.toHaveBeenCalled();
    });

    it('switches tabs with data-click-tab', () => {
      document.body.innerHTML = `
        <div class="block">
          <div class="block__nav">
            <a class="block__tab selected" data-click-tab="tab1">Tab 1</a>
            <a class="block__tab" data-click-tab="tab2">Tab 2</a>
          </div>
          <div class="block__tab" data-tab="tab1">Content 1</div>
          <div class="block__tab" data-tab="tab2" class="hidden">Content 2</div>
        </div>
      `;

      const tab1Link = $<HTMLAnchorElement>('[data-click-tab="tab1"]')!;
      const tab2Link = $<HTMLAnchorElement>('[data-click-tab="tab2"]')!;
      const tab1Content = $<HTMLDivElement>('[data-tab="tab1"]')!;
      const tab2Content = $<HTMLDivElement>('[data-tab="tab2"]')!;

      fireEvent.click(tab2Link);

      // Tab 1 should no longer be selected
      expect(tab1Link.classList.contains('selected')).toBe(false);
      // Tab 2 should be selected
      expect(tab2Link.classList.contains('selected')).toBe(true);
      // Tab 1 content should be hidden
      expect(tab1Content.classList.contains('hidden')).toBe(true);
      // Tab 2 content should be shown
      expect(tab2Content.classList.contains('hidden')).toBe(false);
    });

    it('switches tabs when no tab is preselected', () => {
      document.body.innerHTML = `
        <div class="block">
          <div class="block__nav">
            <a class="block__tab" data-click-tab="tab1">Tab 1</a>
            <a class="block__tab" data-click-tab="tab2">Tab 2</a>
          </div>
          <div class="block__tab" data-tab="tab1">Content 1</div>
          <div class="block__tab" data-tab="tab2">Content 2</div>
        </div>
      `;

      const tab1Link = $<HTMLAnchorElement>('[data-click-tab="tab1"]')!;
      const tab2Content = $<HTMLDivElement>('[data-tab="tab2"]')!;
      const tab1Content = $<HTMLDivElement>('[data-tab="tab1"]')!;

      // Ensure no tab is preselected
      expect($('.selected')).toBeNull();

      fireEvent.click(tab1Link);

      // Selected class should be added to clicked link, and contents updated
      expect(tab1Link.classList.contains('selected')).toBe(true);
      expect(tab1Content.classList.contains('hidden')).toBe(false);
      expect(tab2Content.classList.contains('hidden')).toBe(true);
    });

    it('returns early when tab block resolves to Document (no HTMLElement two levels up)', () => {
      // Create a tab trigger directly under <html>, so parentNode is <html> and parentNode.parentNode is Document
      const tab = document.createElement('a');
      tab.className = 'block__tab';
      tab.setAttribute('data-click-tab', 'tab1');
      tab.textContent = 'Tab 1';

      // Ensure listeners are registered
      // Note: registerEvents is called in beforeEach of this describe
      document.documentElement.appendChild(tab);

      // Click the tab
      fireEvent.click(tab);

      // Because block is Document (not an HTMLElement), action returns before modifying classes
      expect(tab.classList.contains('selected')).toBe(false);

      // Cleanup: remove from <html>
      document.documentElement.removeChild(tab);
    });

    it('copies to clipboard with data-click-copy', () => {
      document.body.innerHTML = `
        <input id="copytext" value="Hello World">
        <button data-click-copy="#copytext">Copy</button>
      `;

      // Patch execCommand for JSDOM
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (document as any).execCommand = vi.fn().mockReturnValue(true);

      const input = $<HTMLInputElement>('#copytext')!;
      // Spy on select to ensure it's called
      input.select = vi.fn();

      const button = $<HTMLButtonElement>('button')!;
      fireEvent.click(button);

      expect(input.select).toHaveBeenCalledTimes(1);
      expect((document as Document & { execCommand: (cmd: string) => boolean }).execCommand).toHaveBeenCalledWith(
        'copy',
      );
    });

    it('does nothing when copy target is missing', () => {
      document.body.innerHTML = `
        <button data-click-copy="#missing">Copy</button>
      `;

      // Patch execCommand for JSDOM
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (document as any).execCommand = vi.fn().mockReturnValue(true);

      const button = $<HTMLButtonElement>('button')!;
      expect(() => fireEvent.click(button)).not.toThrow();
      expect((document as Document & { execCommand: (cmd: string) => boolean }).execCommand).not.toHaveBeenCalled();
    });

    it('ignores actions when event.target is not an HTMLElement (Text node)', () => {
      document.body.innerHTML = `
        <div id="container" data-click-preventdefault="true">Click me</div>
      `;

      const container = document.getElementById('container')!;
      const textNode = container.firstChild!; // Text node inside the container

      // Create a cancelable click event that bubbles, dispatched from the Text node
      const ev = new MouseEvent('click', { bubbles: true, cancelable: true, button: 0 });

      // Dispatch from the text node: matchAttributes should see a non-HTMLElement target and skip actions
      const result = textNode.dispatchEvent(ev);

      // Since no action ran, preventDefault wasn't called
      expect(result).toBe(true);
      expect(ev.defaultPrevented).toBe(false);
    });

    it('loads tab content once when data-load-tab is provided', async () => {
      document.body.innerHTML = `
        <div class="block">
          <div class="block__nav">
            <a class="block__tab selected" data-click-tab="tab1">Tab 1</a>
            <a class="block__tab" data-click-tab="tab2" data-load-tab="/tab2.html">Tab 2</a>
          </div>
          <div class="block__tab" data-tab="tab1">Content 1</div>
          <div class="block__tab" data-tab="tab2"></div>
        </div>
      `;

      const tab2Link = $<HTMLAnchorElement>('[data-click-tab="tab2"]')!;
      const tab2Content = $<HTMLElement>('[data-tab="tab2"]')!;

      fireEvent.click(tab2Link);

      // Allow the promise chain inside tab loader to resolve fully
      await Promise.resolve();
      await Promise.resolve();
      await new Promise(r => setTimeout(r, 0));

      expect(fetchHtml).toHaveBeenCalledWith('/tab2.html');
      expect(tab2Content.innerHTML).toBe('Loaded content');
      expect(tab2Content.dataset.loaded).toBe('true');

      // Second click should not re-fetch
      fireEvent.click(tab2Link);
      await Promise.resolve();
      await Promise.resolve();
      await new Promise(r => setTimeout(r, 0));
      expect(fetchHtml).toHaveBeenCalledTimes(1);
    });

    it('shows error text when loading tab content fails', async () => {
      document.body.innerHTML = `
        <div class="block">
          <div class="block__nav">
            <a class="block__tab selected" data-click-tab="tab1">Tab 1</a>
            <a class="block__tab" data-click-tab="tab2" data-load-tab="/tab2.html">Tab 2</a>
          </div>
          <div class="block__tab" data-tab="tab1">Content 1</div>
          <div class="block__tab" data-tab="tab2"></div>
        </div>
      `;

      // Make the next call fail to hit the catch branch
      (fetchHtml as unknown as { mockRejectedValueOnce: (e: unknown) => void }).mockRejectedValueOnce(
        new Error('boom'),
      );

      const tab2Link = $<HTMLAnchorElement>('[data-click-tab="tab2"]')!;
      const tab2Content = $<HTMLElement>('[data-tab="tab2"]')!;

      fireEvent.click(tab2Link);

      await Promise.resolve();
      await Promise.resolve();
      await new Promise(r => setTimeout(r, 0));

      expect(tab2Content.textContent).toBe('Error!');
      expect(tab2Content.dataset.loaded).toBeUndefined();
    });
  });

  describe('change actions', () => {
    beforeEach(() => {
      registerEvents();
    });

    it('hides elements with data-change-hide', () => {
      document.body.innerHTML = `
        <select data-change-hide=".target">
          <option value="1">Option 1</option>
        </select>
        <div class="target">Content</div>
      `;

      const select = $<HTMLSelectElement>('select')!;
      const target = $<HTMLDivElement>('.target')!;

      fireEvent.change(select);

      expect(target.classList.contains('hidden')).toBe(true);
    });

    it('shows elements with data-change-show', () => {
      document.body.innerHTML = `
        <input type="checkbox" data-change-show=".target">
        <div class="target hidden">Content</div>
      `;

      const checkbox = $<HTMLInputElement>('input')!;
      const target = $<HTMLDivElement>('.target')!;

      fireEvent.change(checkbox);

      expect(target.classList.contains('hidden')).toBe(false);
    });
  });

  describe('fetchcomplete actions', () => {
    beforeEach(() => {
      registerEvents();
    });

    it('hides elements with data-fetchcomplete-hide', () => {
      document.body.innerHTML = `
        <div data-fetchcomplete-hide=".target">
          <div class="target">Content</div>
        </div>
      `;

      const container = $<HTMLDivElement>('[data-fetchcomplete-hide]')!;
      const target = $<HTMLDivElement>('.target')!;

      const event = new CustomEvent('fetchcomplete', {
        bubbles: true,
        detail: new Response(),
      }) as CustomEvent<Response> & { target: HTMLElement };

      Object.defineProperty(event, 'target', { value: container, writable: false });

      container.dispatchEvent(event);

      expect(target.classList.contains('hidden')).toBe(true);
    });

    it('shows elements with data-fetchcomplete-show', () => {
      document.body.innerHTML = `
        <div data-fetchcomplete-show=".target">
          <div class="target hidden">Content</div>
        </div>
      `;

      const container = $<HTMLDivElement>('[data-fetchcomplete-show]')!;
      const target = $<HTMLDivElement>('.target')!;

      const event = new CustomEvent('fetchcomplete', {
        bubbles: true,
        detail: new Response(),
      }) as CustomEvent<Response> & { target: HTMLElement };

      Object.defineProperty(event, 'target', { value: container, writable: false });

      container.dispatchEvent(event);

      expect(target.classList.contains('hidden')).toBe(false);
    });
  });
});
