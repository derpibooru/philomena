import { $, $$, removeEl } from '../utils/dom';
import { assertNotNull, assertNotUndefined } from '../utils/assert';

import { fetchMock } from '../../test/fetch-mock';
import { fixEventListeners } from '../../test/fix-event-listeners';
import { fireEvent, waitFor } from '@testing-library/dom';
import { promises } from 'fs';
import { join } from 'path';

import { setupImageUpload } from '../upload';

/* eslint-disable camelcase */
const scrapeResponse = {
  description: 'test',
  images: [
    { url: 'http://localhost/images/1', camo_url: 'http://localhost/images/1' },
    { url: 'http://localhost/images/2', camo_url: 'http://localhost/images/2' },
  ],
  source_url: 'http://localhost/images',
  author_name: 'test',
};
const nullResponse = null;
const errorResponse = {
  errors: ['Error 1', 'Error 2'],
};
/* eslint-enable camelcase */

describe('Image upload form', () => {
  let mockPng: File;
  let mockWebm: File;

  beforeAll(async () => {
    const mockPngPath = join(__dirname, 'upload-test.png');
    const mockWebmPath = join(__dirname, 'upload-test.webm');

    mockPng = new File([(await promises.readFile(mockPngPath, { encoding: null })).buffer], 'upload-test.png', {
      type: 'image/png',
    });
    mockWebm = new File([(await promises.readFile(mockWebmPath, { encoding: null })).buffer], 'upload-test.webm', {
      type: 'video/webm',
    });
  });

  beforeAll(() => {
    fetchMock.enableMocks();
  });

  afterAll(() => {
    fetchMock.disableMocks();
  });

  fixEventListeners(window);

  let form: HTMLFormElement;
  let imgPreviews: HTMLDivElement;
  let fileField: HTMLInputElement;
  let remoteUrl: HTMLInputElement;
  let scraperError: HTMLDivElement;
  let fetchButton: HTMLButtonElement;
  let tagsEl: HTMLTextAreaElement;
  let taginputEl: HTMLDivElement;
  let sourceEl: HTMLInputElement;
  let descrEl: HTMLTextAreaElement;
  let submitButton: HTMLButtonElement;

  const assertFetchButtonIsDisabled = () => {
    if (!fetchButton.hasAttribute('disabled')) throw new Error('fetchButton is not disabled');
  };

  beforeEach(() => {
    document.documentElement.insertAdjacentHTML(
      'beforeend',
      `<form action="/images">
        <div id="js-image-upload-previews"></div>
        <input id="image_image" name="image[image]" type="file" class="js-scraper" />
        <input id="image_scraper_url" name="image[scraper_url]" type="url" class="js-scraper" />
        <button id="js-scraper-preview" type="button">Fetch</button>
        <div class="field-error-js hidden js-scraper"></div>

        <input id="image_sources_0_source" name="image[sources][0][source]" type="text" class="js-source-url" />
        <textarea id="image_tag_input" name="image[tag_input]" class="js-image-tags-input"></textarea>
          <div class="js-taginput" value="safe, pony, third tag"/>
        <button id="tagsinput-save" type="button" class="button"/>
        <textarea id="image_description" name="image[description]" class="js-image-descr-input"></textarea>
        <div class="actions">
          <button class="button" type="submit"/>
        </div>
       </form>`,
    );

    form = assertNotNull($<HTMLFormElement>('form'));
    imgPreviews = assertNotNull($<HTMLDivElement>('#js-image-upload-previews'));
    fileField = assertNotUndefined($$<HTMLInputElement>('.js-scraper')[0]);
    remoteUrl = assertNotUndefined($$<HTMLInputElement>('.js-scraper')[1]);
    scraperError = assertNotUndefined($$<HTMLInputElement>('.js-scraper')[2]);
    tagsEl = assertNotNull($<HTMLTextAreaElement>('.js-image-tags-input'));
    taginputEl = assertNotNull($<HTMLDivElement>('.js-taginput'));
    sourceEl = assertNotNull($<HTMLInputElement>('.js-source-url'));
    descrEl = assertNotNull($<HTMLTextAreaElement>('.js-image-descr-input'));
    fetchButton = assertNotNull($<HTMLButtonElement>('#js-scraper-preview'));
    submitButton = assertNotNull($<HTMLButtonElement>('.actions > .button'))

    setupImageUpload();
    fetchMock.resetMocks();
  });

  afterEach(() => {
    removeEl(form);
  });

  it('should disable fetch button on empty source', () => {
    fireEvent.input(remoteUrl, { target: { value: '' } });
    expect(fetchButton.disabled).toBe(true);
  });

  it('should enable fetch button on non-empty source', () => {
    fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
    expect(fetchButton.disabled).toBe(false);
  });

  it('should create a preview element when an image file is uploaded', () => {
    fireEvent.change(fileField, { target: { files: [mockPng] } });
    return waitFor(() => {
      assertFetchButtonIsDisabled();
      expect(imgPreviews.querySelectorAll('img')).toHaveLength(1);
    });
  });

  it('should create a preview element when a Matroska video file is uploaded', () => {
    fireEvent.change(fileField, { target: { files: [mockWebm] } });
    return waitFor(() => {
      assertFetchButtonIsDisabled();
      expect(imgPreviews.querySelectorAll('video')).toHaveLength(1);
    });
  });

  it('should block navigation away after an image file is attached, but not after form submission', async () => {
    fireEvent.change(fileField, { target: { files: [mockPng] } });
    await waitFor(() => {
      assertFetchButtonIsDisabled();
      expect(imgPreviews.querySelectorAll('img')).toHaveLength(1);
    });

    const failedUnloadEvent = new Event('beforeunload', { cancelable: true });
    expect(fireEvent(window, failedUnloadEvent)).toBe(false);

    await new Promise<void>(resolve => {
      form.addEventListener('submit', event => {
        event.preventDefault();
        resolve();
      });
      fireEvent.submit(form);
    });

    const succeededUnloadEvent = new Event('beforeunload', { cancelable: true });
    expect(fireEvent(window, succeededUnloadEvent)).toBe(true);
  });

  it('should scrape images when the fetch button is clicked', async () => {
    fetchMock.mockResolvedValue(new Response(JSON.stringify(scrapeResponse), { status: 200 }));
    fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });

    await new Promise<void>(resolve => {
      tagsEl.addEventListener('addtag', (event: Event) => {
        expect((event as CustomEvent).detail).toEqual({ name: 'artist:test' });
        resolve();
      });

      fireEvent.keyDown(remoteUrl, { keyCode: 13 });
    });

    await waitFor(() => expect(fetch).toHaveBeenCalledTimes(1));
    await waitFor(() => expect(imgPreviews.querySelectorAll('img')).toHaveLength(2));

    expect(scraperError.innerHTML).toEqual('');
    expect(sourceEl.value).toEqual('http://localhost/images');
    expect(descrEl.value).toEqual('test');
  });

  it('should show null scrape result', () => {
    fetchMock.mockResolvedValue(new Response(JSON.stringify(nullResponse), { status: 200 }));

    fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
    fireEvent.click(fetchButton);

    return waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(1);
      expect(imgPreviews.querySelectorAll('img')).toHaveLength(0);
      expect(scraperError.innerText).toEqual('No image found at that address.');
    });
  });

  it('should show error scrape result', () => {
    fetchMock.mockResolvedValue(new Response(JSON.stringify(errorResponse), { status: 200 }));

    fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
    fireEvent.click(fetchButton);

    return waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(1);
      expect(imgPreviews.querySelectorAll('img')).toHaveLength(0);
      expect(scraperError.innerText).toEqual('Error 1 Error 2');
    });
  });
});
