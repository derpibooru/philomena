import { delegate, fire, leftClick, on, PhilomenaAvailableEventsMap, oncePersistedPageShown } from '../events';
import { getRandomArrayItem } from '../../../test/randomness';
import { fireEvent } from '@testing-library/dom';

describe('Event utils', () => {
  const mockEvent = getRandomArrayItem(['click', 'blur', 'mouseleave'] as (keyof PhilomenaAvailableEventsMap)[]);

  describe('fire', () => {
    it('should call the native dispatchEvent method on the element', () => {
      const mockElement = document.createElement('div');
      const dispatchEventSpy = vi.spyOn(mockElement, 'dispatchEvent');
      const mockDetail = getRandomArrayItem([0, 'test', null]);

      fire(mockElement, mockEvent, mockDetail);

      expect(dispatchEventSpy).toHaveBeenCalledTimes(1);

      const [customEvent] = dispatchEventSpy.mock.calls[0] as (Event | CustomEvent)[];

      expect(customEvent).toBeInstanceOf(CustomEvent);
      expect(customEvent.type).toBe(mockEvent);
      expect(customEvent.bubbles).toBe(true);
      expect(customEvent.cancelable).toBe(true);
      expect((customEvent as CustomEvent).detail).toBe(mockDetail);
    });
  });

  describe('on', () => {
    it('should fire handler on descendant click', () => {
      const mockElement = document.createElement('div');

      const mockWrapperElement = document.createElement('div');
      mockWrapperElement.classList.add('wrapper');
      mockElement.appendChild(mockWrapperElement);

      const mockInnerElement = document.createElement('div');
      const innerClass = 'inner';
      mockInnerElement.classList.add(innerClass);
      mockWrapperElement.appendChild(mockInnerElement);

      const mockButton = document.createElement('button');
      mockButton.classList.add('mock-button');
      mockInnerElement.appendChild(mockButton);

      const mockHandler = vi.fn();
      on(mockElement, 'click', `.${innerClass}`, mockHandler);

      fireEvent(mockButton, new Event('click', { bubbles: true }));

      expect(mockHandler).toHaveBeenCalledTimes(1);

      const [event, target] = mockHandler.mock.calls[0];
      expect(event).toBeInstanceOf(Event);
      expect(target).toBe(mockInnerElement);
    });
  });

  describe('leftClick', () => {
    it('should fire on left click', () => {
      const mockButton = document.createElement('button');
      const mockHandler = vi.fn();

      mockButton.addEventListener('click', e => leftClick(mockHandler)(e, mockButton));

      fireEvent.click(mockButton, { button: 0 });

      expect(mockHandler).toHaveBeenCalledTimes(1);
    });

    it('should NOT fire on any other click', () => {
      const mockButton = document.createElement('button');
      const mockHandler = vi.fn();
      const mockButtonNumber = getRandomArrayItem([1, 2, 3, 4, 5]);

      mockButton.addEventListener('click', e => leftClick(mockHandler)(e, mockButton));

      fireEvent.click(mockButton, { button: mockButtonNumber });

      expect(mockHandler).toHaveBeenCalledTimes(0);
    });
  });

  describe('oncePersistedPageShown', () => {
    it('should NOT fire on usual page show', () => {
      const mockHandler = vi.fn();

      oncePersistedPageShown(mockHandler);

      fireEvent.pageShow(window, { persisted: false });

      expect(mockHandler).toHaveBeenCalledTimes(0);
    });

    it('should fire on persisted pageshow', () => {
      const mockHandler = vi.fn();

      oncePersistedPageShown(mockHandler);

      fireEvent.pageShow(window, { persisted: true });

      expect(mockHandler).toHaveBeenCalledTimes(1);
    });

    it('should keep waiting until the first persistent page shown fired', () => {
      const mockHandler = vi.fn();

      oncePersistedPageShown(mockHandler);

      fireEvent.pageShow(window, { persisted: false });
      fireEvent.pageShow(window, { persisted: false });
      fireEvent.pageShow(window, { persisted: true });

      expect(mockHandler).toHaveBeenCalledTimes(1);
    });

    it('should NOT fire more than once', () => {
      const mockHandler = vi.fn();

      oncePersistedPageShown(mockHandler);

      fireEvent.pageShow(window, { persisted: true });
      fireEvent.pageShow(window, { persisted: true });

      expect(mockHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('delegate', () => {
    it('should call the native addEventListener method on the element', () => {
      const mockElement = document.createElement('div');
      const addEventListenerSpy = vi.spyOn(mockElement, 'addEventListener');

      delegate(mockElement, mockEvent, {});

      expect(addEventListenerSpy).toHaveBeenCalledTimes(1);

      const [event, handler] = addEventListenerSpy.mock.calls[0];
      expect(event).toBe(mockEvent);
      expect(typeof handler).toBe('function');
    });

    it('should call the function for the selector', () => {
      const mockElement = document.createElement('div');
      const parentClass = 'parent';
      mockElement.classList.add(parentClass);

      const mockButton = document.createElement('button');
      mockElement.appendChild(mockButton);

      const mockHandler = vi.fn();
      delegate(mockElement, 'click', { [`.${parentClass}`]: mockHandler });

      fireEvent(mockButton, new Event('click', { bubbles: true }));

      expect(mockHandler).toHaveBeenCalledTimes(1);

      const [event, target] = mockHandler.mock.calls[0];
      expect(event).toBeInstanceOf(Event);
      expect(target).toBe(mockElement);
    });

    it('should stop executing handlers after one returns with false', () => {
      const mockElement = document.createElement('div');
      const parentClass = 'parent';
      mockElement.classList.add(parentClass);

      const mockWrapperElement = document.createElement('div');
      const wrapperClass = 'wrapper';
      mockWrapperElement.classList.add(wrapperClass);
      mockElement.appendChild(mockWrapperElement);

      const mockButton = document.createElement('button');
      mockWrapperElement.appendChild(mockButton);

      const mockParentHandler = vi.fn();
      const mockWrapperHandler = vi.fn().mockReturnValue(false);
      delegate(mockElement, 'click', {
        [`.${wrapperClass}`]: mockWrapperHandler,
        [`.${parentClass}`]: mockParentHandler,
      });

      fireEvent(mockButton, new Event('click', { bubbles: true }));

      expect(mockWrapperHandler).toHaveBeenCalledTimes(1);
      expect(mockParentHandler).not.toHaveBeenCalled();
    });
  });
});
