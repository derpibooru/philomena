import { fetchHtml, fetchJson, handleError } from '../requests';
import { fetchMock } from '../../../test/fetch-mock.ts';

describe('Request utils', () => {
  const mockEndpoint = '/endpoint';

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

  describe('fetchJson', () => {
    it('should call native fetch with the correct parameters (without body)', () => {
      const mockVerb = 'GET';

      fetchJson(mockVerb, mockEndpoint);

      expect(fetch).toHaveBeenNthCalledWith(1, mockEndpoint, {
        method: mockVerb,
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'x-csrf-token': window.booru.csrfToken,
          'x-requested-with': 'xmlhttprequest',
        },
      });
    });

    it('should call native fetch with the correct parameters (with body)', () => {
      const mockVerb = 'POST';
      const mockBody = { mockField: Math.random() };

      fetchJson(mockVerb, mockEndpoint, mockBody);

      expect(fetch).toHaveBeenNthCalledWith(1, mockEndpoint, {
        method: mockVerb,
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'x-csrf-token': window.booru.csrfToken,
          'x-requested-with': 'xmlhttprequest',
        },
        body: JSON.stringify({
          ...mockBody,
          _method: mockVerb,
        }),
      });
    });
  });

  describe('fetchHtml', () => {
    it('should call native fetch with the correct parameters', () => {
      fetchHtml(mockEndpoint);

      expect(fetch).toHaveBeenNthCalledWith(1, mockEndpoint, {
        credentials: 'same-origin',
        headers: {
          'x-csrf-token': window.booru.csrfToken,
          'x-requested-with': 'xmlhttprequest',
        },
      });
    });
  });

  describe('handleError', () => {
    it('should throw if ok property is false', () => {
      const mockResponse = { ok: false } as unknown as Response;
      expect(() => handleError(mockResponse)).toThrow('Received error from server');
    });

    it('should return response if ok property is true', () => {
      const mockResponse = { ok: true } as unknown as Response;
      expect(handleError(mockResponse)).toEqual(mockResponse);
    });
  });
});
