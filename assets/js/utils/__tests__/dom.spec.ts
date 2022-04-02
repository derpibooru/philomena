import {
  $,
  $$,
  clearEl,
  escapeCss,
  escapeHtml,
  hideEl,
  insertBefore,
  makeEl,
  onLeftClick,
  removeEl,
  showEl,
  toggleEl,
  whenReady,
  findFirstTextNode,
} from '../dom';
import { getRandomArrayItem, getRandomIntBetween } from '../../../test/randomness';
import { fireEvent } from '@testing-library/dom';

describe('DOM Utilities', () => {
  const mockSelectors = ['#id', '.class', 'div', '#a .complex--selector:not(:hover)'];
  const hiddenClass = 'hidden';
  const createHiddenElement: Document['createElement'] = (...params: Parameters<Document['createElement']>) => {
    const el = document.createElement(...params);
    el.classList.add(hiddenClass);
    return el;
  };

  describe('$', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should call the native querySelector method on document by default', () => {
      const spy = jest.spyOn(document, 'querySelector');

      mockSelectors.forEach((selector, nthCall) => {
        $(selector);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });

    it('should call the native querySelector method on the passed element', () => {
      const mockElement = document.createElement('br');
      const spy = jest.spyOn(mockElement, 'querySelector');

      mockSelectors.forEach((selector, nthCall) => {
        // FIXME This will not be necessary once the file is properly typed
        $(selector, mockElement as unknown as Document);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });
  });

  describe('$$', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should call the native querySelectorAll method on document by default', () => {
      const spy = jest.spyOn(document, 'querySelectorAll');

      mockSelectors.forEach((selector, nthCall) => {
        $$(selector);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });

    it('should call the native querySelectorAll method on the passed element', () => {
      const mockElement = document.createElement('br');
      const spy = jest.spyOn(mockElement, 'querySelectorAll');

      mockSelectors.forEach((selector, nthCall) => {
        // FIXME This will not be necessary once the file is properly typed
        $$(selector, mockElement as unknown as Document);
        expect(spy).toHaveBeenNthCalledWith(nthCall + 1, selector);
      });
    });
  });

  describe('showEl', () => {
    it(`should remove the ${hiddenClass} class from the provided element`, () => {
      const mockElement = createHiddenElement('div');
      showEl(mockElement);
      expect(mockElement).not.toHaveClass(hiddenClass);
    });

    it(`should remove the ${hiddenClass} class from all provided elements`, () => {
      const mockElements = [
        createHiddenElement('div'),
        createHiddenElement('a'),
        createHiddenElement('strong'),
      ];
      showEl(mockElements);
      expect(mockElements[0]).not.toHaveClass(hiddenClass);
      expect(mockElements[1]).not.toHaveClass(hiddenClass);
      expect(mockElements[2]).not.toHaveClass(hiddenClass);
    });

    it(`should remove the ${hiddenClass} class from elements provided in multiple arrays`, () => {
      const mockElements1 = [
        createHiddenElement('div'),
        createHiddenElement('a'),
      ];
      const mockElements2 = [
        createHiddenElement('strong'),
        createHiddenElement('em'),
      ];
      showEl(mockElements1, mockElements2);
      expect(mockElements1[0]).not.toHaveClass(hiddenClass);
      expect(mockElements1[1]).not.toHaveClass(hiddenClass);
      expect(mockElements2[0]).not.toHaveClass(hiddenClass);
      expect(mockElements2[1]).not.toHaveClass(hiddenClass);
    });
  });

  describe('hideEl', () => {
    it(`should add the ${hiddenClass} class to the provided element`, () => {
      const mockElement = document.createElement('div');
      hideEl(mockElement);
      expect(mockElement).toHaveClass(hiddenClass);
    });

    it(`should add the ${hiddenClass} class to all provided elements`, () => {
      const mockElements = [
        document.createElement('div'),
        document.createElement('a'),
        document.createElement('strong'),
      ];
      hideEl(mockElements);
      expect(mockElements[0]).toHaveClass(hiddenClass);
      expect(mockElements[1]).toHaveClass(hiddenClass);
      expect(mockElements[2]).toHaveClass(hiddenClass);
    });

    it(`should add the ${hiddenClass} class to elements provided in multiple arrays`, () => {
      const mockElements1 = [
        document.createElement('div'),
        document.createElement('a'),
      ];
      const mockElements2 = [
        document.createElement('strong'),
        document.createElement('em'),
      ];
      hideEl(mockElements1, mockElements2);
      expect(mockElements1[0]).toHaveClass(hiddenClass);
      expect(mockElements1[1]).toHaveClass(hiddenClass);
      expect(mockElements2[0]).toHaveClass(hiddenClass);
      expect(mockElements2[1]).toHaveClass(hiddenClass);
    });
  });

  describe('toggleEl', () => {
    it(`should toggle the ${hiddenClass} class on the provided element`, () => {
      const mockVisibleElement = document.createElement('div');
      toggleEl(mockVisibleElement);
      expect(mockVisibleElement).toHaveClass(hiddenClass);

      const mockHiddenElement = createHiddenElement('div');
      toggleEl(mockHiddenElement);
      expect(mockHiddenElement).not.toHaveClass(hiddenClass);
    });

    it(`should toggle the ${hiddenClass} class on all provided elements`, () => {
      const mockElements = [
        document.createElement('div'),
        createHiddenElement('a'),
        document.createElement('strong'),
        createHiddenElement('em'),
      ];
      toggleEl(mockElements);
      expect(mockElements[0]).toHaveClass(hiddenClass);
      expect(mockElements[1]).not.toHaveClass(hiddenClass);
      expect(mockElements[2]).toHaveClass(hiddenClass);
      expect(mockElements[3]).not.toHaveClass(hiddenClass);
    });

    it(`should toggle the ${hiddenClass} class on elements provided in multiple arrays`, () => {
      const mockElements1 = [
        createHiddenElement('div'),
        document.createElement('a'),
      ];
      const mockElements2 = [
        createHiddenElement('strong'),
        document.createElement('em'),
      ];
      toggleEl(mockElements1, mockElements2);
      expect(mockElements1[0]).not.toHaveClass(hiddenClass);
      expect(mockElements1[1]).toHaveClass(hiddenClass);
      expect(mockElements2[0]).not.toHaveClass(hiddenClass);
      expect(mockElements2[1]).toHaveClass(hiddenClass);
    });
  });

  describe('clearEl', () => {
    it('should not throw an exception for empty element', () => {
      const emptyElement = document.createElement('br');
      expect(emptyElement.children).toHaveLength(0);
      expect(() => clearEl(emptyElement)).not.toThrow();
      expect(emptyElement.children).toHaveLength(0);
    });

    it('should remove a single child node', () => {
      const baseElement = document.createElement('p');
      baseElement.appendChild(document.createElement('br'));
      expect(baseElement.children).toHaveLength(1);
      clearEl(baseElement);
      expect(baseElement.children).toHaveLength(0);
    });

    it('should remove a multiple child nodes', () => {
      const baseElement = document.createElement('p');
      const elementsToAdd = getRandomIntBetween(5, 10);
      for (let i = 0; i < elementsToAdd; ++i) {
        baseElement.appendChild(document.createElement('br'));
      }
      expect(baseElement.children).toHaveLength(elementsToAdd);
      clearEl(baseElement);
      expect(baseElement.children).toHaveLength(0);
    });

    it('should remove child nodes of elements provided in multiple arrays', () => {
      const baseElement1 = document.createElement('p');
      const elementsToAdd1 = getRandomIntBetween(5, 10);
      for (let i = 0; i < elementsToAdd1; ++i) {
        baseElement1.appendChild(document.createElement('br'));
      }
      expect(baseElement1.children).toHaveLength(elementsToAdd1);

      const baseElement2 = document.createElement('p');
      const elementsToAdd2 = getRandomIntBetween(5, 10);
      for (let i = 0; i < elementsToAdd2; ++i) {
        baseElement2.appendChild(document.createElement('br'));
      }
      expect(baseElement2.children).toHaveLength(elementsToAdd2);

      clearEl([baseElement1], [baseElement2]);
      expect(baseElement1.children).toHaveLength(0);
      expect(baseElement2.children).toHaveLength(0);
    });
  });

  describe('removeEl', () => {
    afterEach(() => {
      jest.restoreAllMocks();
    });

    it('should NOT throw error if element has no parent', () => {
      const detachedElement = document.createElement('div');
      expect(() => removeEl(detachedElement)).not.toThrow();
    });

    it('should call the native removeElement method on parent', () => {
      const parentNode = document.createElement('div');
      const childNode = document.createElement('p');
      parentNode.appendChild(childNode);

      const spy = jest.spyOn(parentNode, 'removeChild');

      removeEl(childNode);
      expect(spy).toHaveBeenCalledTimes(1);
      expect(spy).toHaveBeenNthCalledWith(1, childNode);
    });
  });

  describe('makeEl', () => {
    it('should create br tag', () => {
      const el = makeEl('br');
      expect(el.nodeName).toEqual('BR');
    });

    it('should create a script tag', () => {
      const mockSource = 'https://example.com/';
      const el = makeEl('script', { src: mockSource, async: true, defer: true });
      expect(el.nodeName).toEqual('SCRIPT');
      expect(el.src).toEqual(mockSource);
      expect(el.async).toEqual(true);
      expect(el.defer).toEqual(true);
    });

    it('should create a link tag', () => {
      const mockHref = 'https://example.com/';
      const mockTarget = '_blank';
      const el = makeEl('a', { href: mockHref, target: mockTarget });
      expect(el.nodeName).toEqual('A');
      expect(el.href).toEqual(mockHref);
      expect(el.target).toEqual(mockTarget);
    });

    it('should create paragraph tag', () => {
      const mockClassOne = 'class-one';
      const mockClassTwo = 'class-two';
      const el = makeEl('p', { className: `${mockClassOne} ${mockClassTwo}` });
      expect(el.nodeName).toEqual('P');
      expect(el).toHaveClass(mockClassOne);
      expect(el).toHaveClass(mockClassTwo);
    });
  });

  describe('insertBefore', () => {
    it('should insert the new element before the existing element', () => {
      const mockParent = document.createElement('p');
      const mockExisingElement = document.createElement('span');
      mockParent.appendChild(mockExisingElement);
      const mockNewElement = document.createElement('strong');

      insertBefore(mockExisingElement, mockNewElement);

      expect(mockParent.children).toHaveLength(2);
      expect(mockParent.children[0].tagName).toBe('STRONG');
      expect(mockParent.children[1].tagName).toBe('SPAN');
    });

    it('should insert between two elements', () => {
      const mockParent = document.createElement('p');
      const mockFirstExisingElement = document.createElement('span');
      const mockSecondExisingElement = document.createElement('em');
      mockParent.appendChild(mockFirstExisingElement);
      mockParent.appendChild(mockSecondExisingElement);
      const mockNewElement = document.createElement('strong');

      insertBefore(mockSecondExisingElement, mockNewElement);

      expect(mockParent.children).toHaveLength(3);
      expect(mockParent.children[0].tagName).toBe('SPAN');
      expect(mockParent.children[1].tagName).toBe('STRONG');
      expect(mockParent.children[2].tagName).toBe('EM');
    });

    it('should NOT fail if there is no parent', () => {
      const mockParent = document.createElement('p');
      const mockNewElement = document.createElement('em');

      expect(() => {
        insertBefore(mockParent, mockNewElement);
      }).not.toThrow();
    });
  });

  describe('onLeftClick', () => {
    let cleanup: VoidFunction | undefined;

    afterEach(() => {
      if (cleanup) cleanup();
    });

    it('should call callback on left click', () => {
      const mockCallback = jest.fn();
      const element = document.createElement('div');
      cleanup = onLeftClick(mockCallback, element as unknown as Document);

      fireEvent.click(element, { button: 0 });

      expect(mockCallback).toHaveBeenCalledTimes(1);
    });

    it('should NOT call callback on non-left click', () => {
      const mockCallback = jest.fn();
      const element = document.createElement('div');
      cleanup = onLeftClick(mockCallback, element as unknown as Document);

      const mockButton = getRandomArrayItem([1, 2, 3, 4, 5]);
      fireEvent.click(element, { button: mockButton });

      expect(mockCallback).not.toHaveBeenCalled();
    });

    it('should add click event listener to the document by default', () => {
      const mockCallback = jest.fn();
      cleanup = onLeftClick(mockCallback);

      fireEvent.click(document.body);

      expect(mockCallback).toHaveBeenCalledTimes(1);
    });

    it('should return a cleanup function that removes the listener', () => {
      const mockCallback = jest.fn();
      const element = document.createElement('div');
      const localCleanup = onLeftClick(mockCallback, element as unknown as Document);

      fireEvent.click(element, { button: 0 });

      // Remove the listener
      localCleanup();

      fireEvent.click(element, { button: 0 });

      expect(mockCallback).toHaveBeenCalledTimes(1);
    });
  });

  describe('whenReady', () => {
    it('should call callback immediately if document ready state is not loading', () => {
      const mockReadyStateValue = getRandomArrayItem<DocumentReadyState>(['complete', 'interactive']);
      const readyStateSpy = jest.spyOn(document, 'readyState', 'get').mockReturnValue(mockReadyStateValue);
      const mockCallback = jest.fn();

      try {
        whenReady(mockCallback);
        expect(mockCallback).toHaveBeenCalledTimes(1);
      }
      finally {
        readyStateSpy.mockRestore();
      }
    });

    it('should add event listener with callback if document ready state is loading', () => {
      const readyStateSpy = jest.spyOn(document, 'readyState', 'get').mockReturnValue('loading');
      const addEventListenerSpy = jest.spyOn(document, 'addEventListener');
      const mockCallback = jest.fn();

      try {
        whenReady(mockCallback);
        expect(addEventListenerSpy).toHaveBeenCalledTimes(1);
        expect(addEventListenerSpy).toHaveBeenNthCalledWith(1, 'DOMContentLoaded', mockCallback);
        expect(mockCallback).not.toHaveBeenCalled();
      }
      finally {
        readyStateSpy.mockRestore();
        addEventListenerSpy.mockRestore();
      }
    });
  });

  describe('escapeHtml', () => {
    it('should replace only the expected characters with their HTML entity equivalents', () => {
      expect(escapeHtml('<script src="http://example.com/?a=1&b=2"></script>')).toBe('&lt;script src=&quot;http://example.com/?a=1&amp;b=2&quot;&gt;&lt;/script&gt;');
    });
  });

  describe('escapeCss', () => {
    it('should replace only the expected characters with their escaped equivalents', () => {
      expect(escapeCss('url("https://example.com")')).toBe('url(\\"https://example.com\\")');
    });
  });

  describe('findFirstTextNode', () => {
    it('should return the first text node child', () => {
      const mockText = `expected text ${Math.random()}`;
      const mockNode = document.createElement('div');
      mockNode.innerHTML = `<strong>bold</strong>${mockText}<em>italic</em>`;

      const result: Node = findFirstTextNode(mockNode);
      expect(result.nodeValue).toBe(mockText);
    });

    it('should return undefined if there is no text node child', () => {
      const mockNode = document.createElement('div');
      mockNode.innerHTML = '<strong>bold</strong><em>italic</em>';

      const result: Node = findFirstTextNode(mockNode);
      expect(result).toBe(undefined);
    });
  });
});
