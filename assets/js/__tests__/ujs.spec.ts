import fetchMock from 'jest-fetch-mock';
import { fireEvent, waitFor } from '@testing-library/dom';
import { assertType } from '../utils/assert';
import '../ujs';

const mockEndpoint = 'http://localhost/endpoint';
const mockVerb = 'POST';

describe('Remote utilities', () => {
  beforeAll(() => {
    fetchMock.enableMocks();
  });

  afterAll(() => {
    fetchMock.disableMocks();
  });

  beforeEach(() => {
    window.booru.csrfToken = Math.random().toString();
    fetchMock.resetMocks();
  });

  function addOneShotEventListener(name: string, cb: (e: Event) => void) {
    const handler = (event: Event) => {
      cb(event);
      document.removeEventListener(name, handler);
    };
    document.addEventListener(name, handler);
  }

  describe('a[data-remote]', () => {
    const submitA = ({ setMethod }: { setMethod: boolean; }) => {
      const a = document.createElement('a');
      a.href = mockEndpoint;
      a.dataset.remote = 'remote';
      if (setMethod) {
        a.dataset.method = mockVerb;
      }

      document.documentElement.insertAdjacentElement('beforeend', a);
      a.click();

      return a;
    };

    it('should call native fetch with the correct parameters (without body)', () => {
      submitA({ setMethod: true });
      expect(fetch).toHaveBeenCalledTimes(1);
      expect(fetch).toHaveBeenNthCalledWith(1, mockEndpoint, {
        method: mockVerb,
        credentials: 'same-origin',
        headers: {
          'x-csrf-token': window.booru.csrfToken,
          'x-requested-with': 'XMLHttpRequest'
        }
      });
    });

    it('should call native fetch for a get request without explicit method', () => {
      submitA({ setMethod: false });
      expect(fetch).toHaveBeenCalledTimes(1);
      expect(fetch).toHaveBeenNthCalledWith(1, mockEndpoint, {
        method: 'GET',
        credentials: 'same-origin',
        headers: {
          'x-csrf-token': window.booru.csrfToken,
          'x-requested-with': 'XMLHttpRequest'
        }
      });
    });

    it('should emit fetchcomplete event', () => new Promise<void>(resolve => {
      let a: HTMLAnchorElement | null = null;

      addOneShotEventListener('fetchcomplete', event => {
        expect(event.target).toBe(a);
        resolve();
      });

      a = submitA({ setMethod: true });
    }));
  });

  describe('a[data-method]', () => {
    const submitA = () => {
      const a = document.createElement('a');
      a.href = mockEndpoint;
      a.dataset.method = mockVerb;

      document.documentElement.insertAdjacentElement('beforeend', a);
      a.click();

      return a;
    };

    it('should submit a form with the given action', () => new Promise<void>(resolve => {
      addOneShotEventListener('submit', event => {
        event.preventDefault();

        const target = assertType(event.target, HTMLFormElement);
        const [ csrf, method ] = target.querySelectorAll('input');

        expect(csrf.name).toBe('_csrf_token');
        expect(csrf.value).toBe(window.booru.csrfToken);

        expect(method.name).toBe('_method');
        expect(method.value).toBe(mockVerb);

        resolve();
      });

      submitA();
    }));
  });

  describe('form[data-remote]', () => {
    // https://www.benmvp.com/blog/mocking-window-location-methods-jest-jsdom/
    let oldWindowLocation: Location;

    /* eslint-disable @typescript-eslint/no-explicit-any */
    beforeAll(() => {
      oldWindowLocation = window.location;
      delete (window as any).location;

      (window as any).location = Object.defineProperties(
        {},
        {
          ...Object.getOwnPropertyDescriptors(oldWindowLocation),
          reload: {
            configurable: true,
            value: jest.fn(),
          },
        },
      );
    });

    beforeEach(() => {
      (window.location.reload as any).mockReset();
    });
    /* eslint-enable @typescript-eslint/no-explicit-any */

    afterAll(() => {
      // restore window.location to the jsdom Location object
      window.location = oldWindowLocation;
    });

    const configureForm = () => {
      const form = document.createElement('form');
      form.action = mockEndpoint;
      form.dataset.remote = 'remote';
      document.documentElement.insertAdjacentElement('beforeend', form);
      return form;
    };

    const submitForm = () => {
      const form = configureForm();
      form.method = mockVerb;
      form.submit();
      return form;
    };

    it('should call native fetch with the correct parameters (with body)', () => {
      submitForm();
      expect(fetch).toHaveBeenCalledTimes(1);
      expect(fetch).toHaveBeenNthCalledWith(1, mockEndpoint, {
        method: mockVerb,
        credentials: 'same-origin',
        headers: {
          'x-csrf-token': window.booru.csrfToken,
          'x-requested-with': 'XMLHttpRequest'
        },
        body: new FormData(),
      });
    });

    it('should submit a PUT request with put data-method specified', () => {
      const form = configureForm();
      form.dataset.method = 'put';
      form.submit();
      expect(fetch).toHaveBeenCalledTimes(1);
      expect(fetch).toHaveBeenNthCalledWith(1, mockEndpoint, {
        method: 'PUT',
        credentials: 'same-origin',
        headers: {
          'x-csrf-token': window.booru.csrfToken,
          'x-requested-with': 'XMLHttpRequest'
        },
        body: new FormData(),
      });
    });

    it('should emit fetchcomplete event', () => new Promise<void>(resolve => {
      let form: HTMLFormElement | null = null;

      addOneShotEventListener('fetchcomplete', event => {
        expect(event.target).toBe(form);
        resolve();
      });

      form = submitForm();
    }));

    it('should reload the page on 300 multiple choices response', () => {
      jest.spyOn(global, 'fetch').mockResolvedValue(new Response('', { status: 300}));

      submitForm();
      return waitFor(() => expect(window.location.reload).toHaveBeenCalledTimes(1));
    });
  });
});

describe('Form utilities', () => {
  beforeEach(() => {
    jest.spyOn(window, 'requestAnimationFrame').mockImplementation(cb => {
      cb(1);
      return 1;
    });
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('[data-confirm]', () => {
    const createA = () => {
      const a = document.createElement('a');
      a.dataset.confirm = 'confirm';
      a.href = mockEndpoint;
      document.documentElement.insertAdjacentElement('beforeend', a);
      return a;
    };

    it('should cancel the event on failed confirm', () => {
      const a = createA();
      const confirm = jest.spyOn(window, 'confirm').mockImplementationOnce(() => false);
      const event = new MouseEvent('click', { bubbles: true, cancelable: true });

      expect(fireEvent(a, event)).toBe(false);
      expect(confirm).toHaveBeenCalledTimes(1);
    });

    it('should allow the event on confirm', () => {
      const a = createA();
      const confirm = jest.spyOn(window, 'confirm').mockImplementationOnce(() => true);
      const event = new MouseEvent('click', { bubbles: true, cancelable: true });

      expect(fireEvent(a, event)).toBe(true);
      expect(confirm).toHaveBeenCalledTimes(1);
    });
  });

  describe('[data-disable-with][data-enable-with]', () => {
    const createFormAndButton = (innerHTML: string, disableWith: string) => {
      const form = document.createElement('form');
      form.action = mockEndpoint;

      // jsdom has no implementation for HTMLFormElement.prototype.submit
      // and will return an error if the event's default isn't prevented
      form.addEventListener('submit', event => event.preventDefault());

      const button = document.createElement('button');
      button.type = 'submit';
      button.innerHTML = innerHTML;
      button.dataset.disableWith = disableWith;

      form.insertAdjacentElement('beforeend', button);
      document.documentElement.insertAdjacentElement('beforeend', form);

      return [ form, button ];
    };

    const submitText = 'Submit';
    const loadingText = 'Loading...';
    const submitMarkup = '<em>Submit</em>';
    const loadingMarkup = '<em>Loading...</em>';

    it('should disable submit button containing a text child on click', () => {
      const [ , button ] = createFormAndButton(submitText, loadingText);
      button.click();

      expect(button.textContent).toEqual(' Loading...');
      expect(button.dataset.enableWith).toEqual(submitText);
    });

    it('should disable submit button containing element children on click', () => {
      const [ , button ] = createFormAndButton(submitMarkup, loadingMarkup);
      button.click();

      expect(button.innerHTML).toEqual(loadingMarkup);
      expect(button.dataset.enableWith).toEqual(submitMarkup);
    });

    it('should not disable anything when the form is invalid', () => {
      const [ form, button ] = createFormAndButton(submitText, loadingText);
      form.insertAdjacentHTML('afterbegin', '<input type="text" name="valid" required="true" />');
      button.click();

      expect(button.textContent).toEqual(submitText);
      expect(button.dataset.enableWith).not.toBeDefined();
    });

    it('should reset submit button containing a text child on completion', () => {
      const [ form, button ] = createFormAndButton(submitText, loadingText);
      button.click();
      fireEvent(form, new CustomEvent('reset', { bubbles: true }));

      expect(button.textContent?.trim()).toEqual(submitText);
      expect(button.dataset.enableWith).not.toBeDefined();
    });

    it('should reset submit button containing element children on completion', () => {
      const [ form, button ] = createFormAndButton(submitMarkup, loadingMarkup);
      button.click();
      fireEvent(form, new CustomEvent('reset', { bubbles: true }));

      expect(button.innerHTML).toEqual(submitMarkup);
      expect(button.dataset.enableWith).not.toBeDefined();
    });

    it('should reset disabled form elements on pageshow', () => {
      const [ , button ] = createFormAndButton(submitText, loadingText);
      button.click();
      fireEvent(window, new CustomEvent('pageshow'));

      expect(button.textContent?.trim()).toEqual(submitText);
      expect(button.dataset.enableWith).not.toBeDefined();
    });
  });
});
