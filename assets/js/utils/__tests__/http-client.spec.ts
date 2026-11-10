import { HttpClient } from '../http-client';
import { fetchMock } from '../../../test/fetch-mock';

describe('HttpClient', () => {
  beforeAll(() => {
    vi.useFakeTimers();
    fetchMock.enableMocks();
  });

  afterEach(() => {
    fetchMock.resetMocks();
  });

  it('should throw an HttpError on non-OK responses', async () => {
    const client = new HttpClient();

    fetchMock.mockResponse('Not Found', { status: 404, statusText: 'Not Found' });

    await expect(client.fetch('/', {})).rejects.toThrowError(/404: Not Found/);

    // 404 is non-retryable
    expect(fetch).toHaveBeenCalledOnce();
  });

  it('should retry 500 errors', async () => {
    const client = new HttpClient();

    fetchMock.mockResponses(
      ['Internal Server Error', { status: 500, statusText: 'Internal Server Error' }],
      ['OK', { status: 200, statusText: 'OK' }],
    );

    const promise = expect(client.fetch('/', {})).resolves.toMatchObject({ status: 200, statusText: 'OK' });
    await vi.runAllTimersAsync();
    await promise;

    expect(fetch).toHaveBeenCalledTimes(2);
  });

  it('should not retry AbortError', async () => {
    const client = new HttpClient();

    fetchMock.mockResponse('OK', { status: 200, statusText: 'OK' });

    const abortController = new AbortController();

    const promise = expect(client.fetch('/', { signal: abortController.signal })).rejects.toThrowError(
      'The operation was aborted.',
    );

    abortController.abort();

    await vi.runAllTimersAsync();
    await promise;

    expect(fetch).toHaveBeenCalledOnce();
  });
});
