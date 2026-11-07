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
const notFoundResponse = {
  errors: ['No images found at that URL.'],
};
const errorResponse = {
  errors: ['Error 1', 'Error 2'],
};
/* eslint-enable camelcase */

const tagSets = ['', 'a tag', 'safe', 'one, two, three', 'safe, explicit', 'safe, explicit, three', 'safe, two, three'];
const tagErrorCounts = [2, 2, 1, 1, 2, 1, 0];

describe('Image upload form', () => {
  let mockPng: File;
  let mockWebm: File;

  beforeAll(async () => {
    const mockPngPath = join(__dirname, 'upload-test.png');
    const mockWebmPath = join(__dirname, 'upload-test.webm');

    const pngBuf = await promises.readFile(mockPngPath, { encoding: null });
    const pngAb = new ArrayBuffer(pngBuf.length);
    new Uint8Array(pngAb).set(pngBuf);
    mockPng = new File([pngAb], 'upload-test.png', {
      type: 'image/png',
    });
    const webmBuf = await promises.readFile(mockWebmPath, { encoding: null });
    const webmAb = new ArrayBuffer(webmBuf.length);
    new Uint8Array(webmAb).set(webmBuf);
    mockWebm = new File([webmAb], 'upload-test.webm', {
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
  let sourceEl: HTMLInputElement;
  let descrEl: HTMLTextAreaElement;
  let submitButton: HTMLButtonElement;

  const assertFetchButtonIsDisabled = () => {
    if (!fetchButton.hasAttribute('disabled')) throw new Error('fetchButton is not disabled');
  };

  const assertSubmitButtonIsDisabled = () => {
    if (!submitButton.hasAttribute('disabled')) throw new Error('submitButton is not disabled');
  };

  const assertSubmitButtonIsEnabled = () => {
    if (submitButton.hasAttribute('disabled')) throw new Error('submitButton is disabled');
  };

  beforeEach(() => {
    // Mock scrollIntoView since jsdom doesn't implement it
    Element.prototype.scrollIntoView = vi.fn();

    document.documentElement.insertAdjacentHTML(
      'beforeend',
      `<form action="/images">
        <div id="js-image-upload-previews"></div>
        <input id="image_image" name="image[image]" type="file" class="js-scraper" />
        <input id="image_scraper_url" name="image[scraper_url]" type="url" class="js-scraper" />
        <button id="js-scraper-preview" type="button">Fetch</button>
        <div class="field-error-js hidden js-scraper"></div>

        <input id="image_sources_0_source" name="image[sources][0][source]" type="text" class="js-source-url" />
        <div class="js-tag-block fancy-tag-upload">
          <textarea id="image_tag_input" name="image[tag_input]" class="input input--wide tagsinput js-image-tags-input js-taginput js-taginput-plain"></textarea>
          <div class="js-taginput input input--wide tagsinput hidden js-taginput-fancy"></div>
        </div>
        <button id="tagsinput-save" type="button" class="button">Save</button>
        <textarea id="image_description" name="image[description]" class="js-image-descr-input"></textarea>
        <div class="actions">
          <button class="button input--separate-top" type="submit">Upload</button>
        </div>
       </form>`,
    );

    form = assertNotNull($<HTMLFormElement>('form'));
    imgPreviews = assertNotNull($<HTMLDivElement>('#js-image-upload-previews'));
    fileField = assertNotUndefined($$<HTMLInputElement>('.js-scraper')[0]);
    remoteUrl = assertNotUndefined($$<HTMLInputElement>('.js-scraper')[1]);
    scraperError = assertNotUndefined($$<HTMLInputElement>('.js-scraper')[2]);
    tagsEl = assertNotNull($<HTMLTextAreaElement>('.js-image-tags-input'));
    sourceEl = assertNotNull($<HTMLInputElement>('.js-source-url'));
    descrEl = assertNotNull($<HTMLTextAreaElement>('.js-image-descr-input'));
    fetchButton = assertNotNull($<HTMLButtonElement>('#js-scraper-preview'));
    submitButton = assertNotNull($<HTMLButtonElement>('.actions > .button'));
    fetchMock.resetMocks();
  });

  afterEach(() => {
    removeEl(form);
  });

  async function submitForm(frm: HTMLFormElement): Promise<boolean> {
    return new Promise(resolve => {
      function onSubmit() {
        frm.removeEventListener('submit', onSubmit);
        resolve(true);
      }

      frm.addEventListener('submit', onSubmit);

      if (!fireEvent.submit(frm)) {
        frm.removeEventListener('submit', onSubmit);
        resolve(false);
      }
    });
  }

  describe('With all elements', () => {
    beforeEach(() => {
      setupImageUpload();
    });

    it('should disable fetch button on empty source', () => {
      fireEvent.input(remoteUrl, { target: { value: '' } });
      expect(fetchButton.disabled).toBe(true);
    });

    it('should create a preview element when an image file is uploaded', () => {
      fireEvent.change(fileField, { target: { files: [mockPng] } });
      return waitFor(() => {
        assertFetchButtonIsDisabled();
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(1);
      });
    });

    it('should ignore file change when no files are provided', async () => {
      // Ensure previews are empty initially
      expect($$<HTMLElement>('img,video', imgPreviews)).toHaveLength(0);

      // Trigger change with empty files array
      fireEvent.change(fileField, { target: { files: [] } });

      // Nothing should be rendered
      await waitFor(() => {
        expect($$<HTMLElement>('img,video', imgPreviews)).toHaveLength(0);
      });
    });

    it('should create a preview element when a Matroska video file is uploaded', () => {
      fireEvent.change(fileField, { target: { files: [mockWebm] } });
      return waitFor(() => {
        assertFetchButtonIsDisabled();
        expect($$<HTMLVideoElement>('video', imgPreviews)).toHaveLength(1);
      });
    });

    it('should block navigation away after an image file is attached, but not after form submission', async () => {
      // Set valid tags first
      tagsEl.value = 'safe, two, three';

      fireEvent.change(fileField, { target: { files: [mockPng] } });
      await waitFor(() => {
        assertFetchButtonIsDisabled();
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(1);
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

    it('should not add author tag when author_name is missing', async () => {
      const response = {
        description: 'no author',
        images: [
          { url: 'http://localhost/images/1', camo_url: 'http://localhost/images/1' },
          { url: 'http://localhost/images/2', camo_url: 'http://localhost/images/2' },
        ],
        // eslint-disable-next-line camelcase
        source_url: 'http://localhost/images',
        // author_name omitted
      };

      fetchMock.mockResolvedValue(new Response(JSON.stringify(response), { status: 200 }));
      const addTagListener = vi.fn();
      tagsEl.addEventListener('addtag', addTagListener);

      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      fireEvent.click(fetchButton);

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(2);
      });

      expect(addTagListener).not.toHaveBeenCalled();
    });

    it('should show server-provided error when no images are found (422)', () => {
      fetchMock.mockResolvedValue(new Response(JSON.stringify(notFoundResponse), { status: 422 }));

      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      fireEvent.click(fetchButton);

      return waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(0);
        expect(scraperError.innerText).toEqual('No images found at that URL.');
      });
    });

    it('should show error scrape result', () => {
      fetchMock.mockResolvedValue(new Response(JSON.stringify(errorResponse), { status: 422 }));

      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      fireEvent.click(fetchButton);

      return waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(0);
        expect(scraperError.innerText).toEqual('Error 1 Error 2');
      });
    });

    it('should set empty strings when source_url and description are missing', async () => {
      const response = {
        // no description
        images: [
          { url: 'http://localhost/images/1', camo_url: 'http://localhost/images/1' },
          { url: 'http://localhost/images/2', camo_url: 'http://localhost/images/2' },
        ],
        // no source_url
        // no author_name
      };

      fetchMock.mockResolvedValue(new Response(JSON.stringify(response), { status: 200 }));

      // Ensure fields are empty before
      expect(sourceEl.value).toBe('');
      expect(descrEl.value).toBe('');

      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      fireEvent.click(fetchButton);

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(2);
        // Fallback branch should evaluate to '' for both assignments
        expect(sourceEl.value).toBe('');
        expect(descrEl.value).toBe('');
      });
    });

    it('shows scraper error when request rejects (network failure path)', async () => {
      fetchMock.mockRejectedValue(new Error('network down'));

      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      // Button becomes enabled on input; click triggers disable + request
      expect(fetchButton.disabled).toBe(false);
      fireEvent.click(fetchButton);

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        // On error we clear previews and show error element, and re-enable fetch
        expect($$<HTMLElement>('img,video', imgPreviews)).toHaveLength(0);
        expect(fetchButton.disabled).toBe(false);
        // The error element should be visible (hidden class removed)
        expect(scraperError.classList.contains('hidden')).toBe(false);
      });
    });

    it('shows scraper error when server responds with an unexpected error status', async () => {
      fetchMock.mockResolvedValue(new Response('', { status: 500 }));

      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      fireEvent.click(fetchButton);

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        expect($$<HTMLElement>('img,video', imgPreviews)).toHaveLength(0);
        expect(fetchButton.disabled).toBe(false);
        expect(scraperError.classList.contains('hidden')).toBe(false);
      });
    });

    it('should prevent form submission if tag checks fail', async () => {
      for (let i = 0; i < tagSets.length; i += 1) {
        if (tagErrorCounts[i] === 0) continue;

        tagsEl.value = tagSets[i];
        await submitForm(form);

        const frm = form;
        await waitFor(() => {
          assertSubmitButtonIsEnabled();
          expect($$<HTMLDivElement>('.help-block', frm)).toHaveLength(tagErrorCounts[i]);
        });
      }
    });

    it('should allow form submission if tag checks pass', async () => {
      for (let i = 0; i < tagSets.length; i += 1) {
        if (tagErrorCounts[i] !== 0) continue;

        tagsEl.value = tagSets[i];
        await submitForm(form);

        await waitFor(() => {
          assertSubmitButtonIsDisabled();
          const succeededUnloadEvent = new Event('beforeunload', { cancelable: true });
          expect(fireEvent(window, succeededUnloadEvent)).toBe(true);
        });
      }
    });

    it('should not create tag errors if buttonAfter element is missing', () => {
      // Remove the save button
      const saveButton = $('#tagsinput-save');
      if (saveButton) saveButton.remove();

      // Set invalid tags
      tagsEl.value = 'one';

      // Try to submit
      fireEvent.submit(form);

      // Should not crash and no errors should be created
      expect($$<HTMLDivElement>('.help-block', form)).toHaveLength(0);
    });

    it('should return early from disableUploadButton if submitButton not disabled on pagehide', async () => {
      // Set valid tags
      tagsEl.value = 'safe, two, three';

      // Submit the form
      await submitForm(form);

      // Verify button is disabled
      await waitFor(() => {
        expect(submitButton.disabled).toBe(true);
        expect(submitButton.hasAttribute('disabled')).toBe(true);
      });

      // Enable the button manually (simulate some edge case)
      submitButton.disabled = false;
      submitButton.removeAttribute('disabled');

      // Fire pagehide event (which triggers oncePersistedPageShown callback)
      const pagehideEvent = new PageTransitionEvent('pagehide', { persisted: true });
      fireEvent(window, pagehideEvent);

      // Fire pageshow event to trigger the callback
      const pageshowEvent = new PageTransitionEvent('pageshow', { persisted: true });
      fireEvent(window, pageshowEvent);

      // Button should remain enabled (early return path)
      expect(submitButton.disabled).toBe(false);
    });

    it('should restore button state when user navigates back after form submission', async () => {
      // Set valid tags
      tagsEl.value = 'safe, two, three';

      const originalText = submitButton.innerText;

      // Submit the form
      await submitForm(form);

      // Verify button is disabled with new text
      await waitFor(() => {
        expect(submitButton.disabled).toBe(true);
        expect(submitButton.innerText).toBe('Please wait...');
        expect(submitButton.hasAttribute('disabled')).toBe(true);
      });

      // Simulate browser back/forward cache restoration
      const pagehideEvent = new PageTransitionEvent('pagehide', { persisted: true });
      fireEvent(window, pagehideEvent);

      const pageshowEvent = new PageTransitionEvent('pageshow', { persisted: true });
      fireEvent(window, pageshowEvent);

      // Button should be restored
      await waitFor(() => {
        expect(submitButton.disabled).toBe(false);
        expect(submitButton.innerText).toBe(originalText);
        expect(submitButton.hasAttribute('disabled')).toBe(false);
      });
    });

    it('should clear file field after successful scrape', async () => {
      fetchMock.mockResolvedValue(new Response(JSON.stringify(scrapeResponse), { status: 200 }));

      // First add a file
      fireEvent.change(fileField, { target: { files: [mockPng] } });
      await waitFor(() => {
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(1);
      });

      // Then scrape
      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      fireEvent.click(fetchButton);

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(2);
        expect(fileField.value).toBe('');
      });
    });
  });

  describe('With missing elements', () => {
    it('should not disable upload button if button is not found', async () => {
      // Remove submit button
      removeEl(submitButton);
      setupImageUpload();

      // Set valid tags
      tagsEl.value = 'safe, two, three';

      // Submit form should work without error
      const submitted = await submitForm(form);
      expect(submitted).toBe(true);
    });

    it('should validate tags correctly when tagInput element is missing', () => {
      // Remove all taginput elements so validateTags finds no element at all
      $$<HTMLElement>('.js-taginput', form).forEach(el => removeEl(el));
      setupImageUpload();

      // Set valid tags in the textarea
      tagsEl.value = 'safe, two, three';

      // Submit form should succeed (validateTags returns true when tagInput is null)
      const submitted = fireEvent.submit(form);
      expect(submitted).toBe(true);
    });

    it('should not set source/description if elements are missing', async () => {
      fetchMock.mockResolvedValue(new Response(JSON.stringify(scrapeResponse), { status: 200 }));

      // Remove source and description elements
      removeEl(sourceEl, descrEl);
      setupImageUpload();

      fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
      fireEvent.click(fetchButton);

      await waitFor(() => {
        expect(fetch).toHaveBeenCalledTimes(1);
        expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(2);
      });

      // Should not crash even though elements are missing
    });
  });
});

describe('Image upload form - early returns and edge paths', () => {
  beforeAll(() => {
    fetchMock.enableMocks();
  });

  afterAll(() => {
    fetchMock.disableMocks();
  });

  afterEach(() => {
    // Cleanup between tests
    document.documentElement.innerHTML = '';
    vi.restoreAllMocks();
    fetchMock.resetMocks();
  });

  it('returns early when #js-image-upload-previews is missing', () => {
    // No DOM setup at all
    expect(() => setupImageUpload()).not.toThrow();
  });

  it('returns early when previews element is not inside a form', () => {
    document.documentElement.insertAdjacentHTML('beforeend', '<div id="js-image-upload-previews"></div>');
    expect(() => setupImageUpload()).not.toThrow();
  });

  it('returns early when scraper inputs are missing', () => {
    document.documentElement.insertAdjacentHTML(
      'beforeend',
      `<form action="/images">
        <div id="js-image-upload-previews"></div>
      </form>`,
    );
    expect(() => setupImageUpload()).not.toThrow();
  });

  it('returns early when fetch button is missing', () => {
    document.documentElement.insertAdjacentHTML(
      'beforeend',
      `<form action="/images">
        <div id="js-image-upload-previews"></div>
        <input id="image_image" type="file" class="js-scraper" />
        <input id="image_scraper_url" type="url" class="js-scraper" />
        <div class="field-error-js hidden js-scraper"></div>
        <input id="image_sources_0_source" type="text" class="js-source-url" />
        <textarea id="image_description" class="js-image-descr-input"></textarea>
      </form>`,
    );
    expect(() => setupImageUpload()).not.toThrow();
  });
});

describe('Image upload form - additional branches', () => {
  let form: HTMLFormElement;
  let imgPreviews: HTMLDivElement;
  let remoteUrl: HTMLInputElement;
  let fetchButton: HTMLButtonElement;
  let tagsEl: HTMLTextAreaElement;
  let sourceEl: HTMLInputElement;
  let descrEl: HTMLTextAreaElement;

  beforeAll(() => {
    fetchMock.enableMocks();
  });

  afterAll(() => {
    fetchMock.disableMocks();
  });

  beforeEach(() => {
    Element.prototype.scrollIntoView = vi.fn();

    document.documentElement.insertAdjacentHTML(
      'beforeend',
      `<form action="/images">
        <div id="js-image-upload-previews"></div>
        <input id="image_image" name="image[image]" type="file" class="js-scraper" />
        <input id="image_scraper_url" name="image[scraper_url]" type="url" class="js-scraper" />
        <button id="js-scraper-preview" type="button">Fetch</button>
        <div class="field-error-js hidden js-scraper"></div>

        <input id="image_sources_0_source" name="image[sources][0][source]" type="text" class="js-source-url" />
        <div class="js-tag-block fancy-tag-upload">
          <textarea id="image_tag_input" name="image[tag_input]" class="input input--wide tagsinput js-image-tags-input js-taginput js-taginput-plain"></textarea>
          <div class="js-taginput input input--wide tagsinput hidden js-taginput-fancy"></div>
        </div>
        <button id="tagsinput-save" type="button" class="button">Save</button>
        <textarea id="image_description" name="image[description]" class="js-image-descr-input"></textarea>
        <div class="actions">
          <button class="button input--separate-top" type="submit">Upload</button>
        </div>
       </form>`,
    );

    form = assertNotNull($<HTMLFormElement>('form'));
    imgPreviews = assertNotNull($<HTMLDivElement>('#js-image-upload-previews'));
    remoteUrl = assertNotNull($<HTMLInputElement>('#image_scraper_url'));
    fetchButton = assertNotNull($<HTMLButtonElement>('#js-scraper-preview'));
    tagsEl = assertNotNull($<HTMLTextAreaElement>('.js-image-tags-input'));
    sourceEl = assertNotNull($<HTMLInputElement>('.js-source-url'));
    descrEl = assertNotNull($<HTMLTextAreaElement>('.js-image-descr-input'));

    setupImageUpload();
    fetchMock.resetMocks();
  });

  afterEach(() => {
    removeEl(form);
  });

  it('does nothing on Enter when URL is empty (click handler early return)', async () => {
    // Ensure button is disabled initially
    expect(fetchButton.disabled).toBe(true);

    // Press Enter in the empty URL field; key normalization will treat this as Enter
    fireEvent.keyDown(remoteUrl, { key: 'Enter', keyCode: 13 });

    // No network call and no previews created
    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(0);
      expect($$<HTMLElement>('img,video', imgPreviews)).toHaveLength(0);
      expect(fetchButton.disabled).toBe(true);
    });
  });

  it('does not trigger fetch on non-Enter keydown in URL field', () => {
    const clickSpy = vi.spyOn(fetchButton, 'click');
    fireEvent.keyDown(remoteUrl, { key: 'Escape', keyCode: 27 });
    expect(clickSpy).not.toHaveBeenCalled();
    clickSpy.mockRestore();
  });

  it('triggers fetch button click on Enter keydown when URL is present', () => {
    // Provide a URL so fetch is enabled
    fireEvent.input(remoteUrl, { target: { value: 'http://example.com/image' } });

    const clickSpy = vi.spyOn(fetchButton, 'click');

    // Press Enter in the URL field
    fireEvent.keyDown(remoteUrl, { key: 'Enter', keyCode: 13 });

    expect(clickSpy).toHaveBeenCalledTimes(1);
    clickSpy.mockRestore();
  });

  it('does nothing on button click when URL is empty (forced enabled)', async () => {
    // Force-enable fetch button and click with empty URL
    fetchButton.disabled = false;
    fetchButton.removeAttribute('disabled');
    fireEvent.click(fetchButton);

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(0);
      expect($$<HTMLElement>('img,video', imgPreviews)).toHaveLength(0);
    });
  });

  it('does not overwrite pre-filled source and description values', async () => {
    /* eslint-disable camelcase */
    const response = {
      description: 'server description',
      images: [
        { url: 'http://localhost/images/1', camo_url: 'http://localhost/images/1' },
        { url: 'http://localhost/images/2', camo_url: 'http://localhost/images/2' },
      ],
      source_url: 'http://localhost/images',
      author_name: 'TestAuthor',
    };
    /* eslint-enable camelcase */

    // Pre-fill fields
    sourceEl.value = 'already set';
    descrEl.value = 'keep me';

    fetchMock.mockResolvedValue(new Response(JSON.stringify(response), { status: 200 }));

    // Attach listener before triggering fetch so we don't miss the event
    const tagAdded = new Promise<void>(resolve => {
      tagsEl.addEventListener('addtag', () => resolve(), { once: true });
    });

    // Trigger fetch via button
    fireEvent.input(remoteUrl, { target: { value: 'http://localhost/images/1' } });
    fireEvent.click(fetchButton);

    await waitFor(() => {
      expect(fetch).toHaveBeenCalledTimes(1);
      expect($$<HTMLImageElement>('img', imgPreviews)).toHaveLength(2);
      // Values should remain untouched
      expect(sourceEl.value).toBe('already set');
      expect(descrEl.value).toBe('keep me');
    });

    // Author tag still added
    await tagAdded;
  });
});

describe('Image upload form - synthetic FileReader', () => {
  let form: HTMLFormElement;
  let imgPreviews: HTMLDivElement;
  let fileField: HTMLInputElement;
  let remoteUrl: HTMLInputElement;
  let fetchButton: HTMLButtonElement;
  let OriginalFileReader: typeof FileReader;

  beforeAll(() => {
    fetchMock.enableMocks();
  });

  afterAll(() => {
    fetchMock.disableMocks();
  });

  beforeEach(() => {
    // Replace FileReader with a fake that dispatches a load event with no result
    OriginalFileReader = FileReader;
    globalThis.FileReader = class FakeFileReader {
      private handler: ((e: Event) => void) | null = null;
      addEventListener(type: string, cb: (e: Event) => void) {
        if (type === 'load') this.handler = cb;
      }
      readAsArrayBuffer(_blob: Blob) {
        // Invoke the registered handler with a minimal object that has no result,
        // which should trigger the early-return path in the code under test.
        const fakeEvent = { target: { result: undefined } } as unknown as Event;
        this.handler?.(fakeEvent);
      }
    } as unknown as typeof FileReader;

    document.documentElement.insertAdjacentHTML(
      'beforeend',
      `<form action="/images">
        <div id="js-image-upload-previews"></div>
        <input id="image_image" name="image[image]" type="file" class="js-scraper" />
        <input id="image_scraper_url" name="image[scraper_url]" type="url" class="js-scraper" />
        <button id="js-scraper-preview" type="button">Fetch</button>
        <div class="field-error-js hidden js-scraper"></div>
      </form>`,
    );

    form = assertNotNull($<HTMLFormElement>('form'));
    imgPreviews = assertNotNull($<HTMLDivElement>('#js-image-upload-previews'));
    fileField = assertNotNull($<HTMLInputElement>('#image_image'));
    remoteUrl = assertNotNull($<HTMLInputElement>('#image_scraper_url'));
    fetchButton = assertNotNull($<HTMLButtonElement>('#js-scraper-preview'));

    setupImageUpload();
    fetchMock.resetMocks();
  });

  afterEach(() => {
    // Restore FileReader
    globalThis.FileReader = OriginalFileReader;
    removeEl(form);
  });

  it('ignores FileReader load when result is missing', async () => {
    // Simulate selecting a file
    const file = new File([new ArrayBuffer(1)], 'x.png', { type: 'image/png' });
    fireEvent.change(fileField, { target: { files: [file] } });

    // No previews should be created because the fake reader provided no result
    await waitFor(() => {
      expect($$<HTMLElement>('img,video', imgPreviews)).toHaveLength(0);
      // Button remains disabled because remoteUrl is empty
      expect(fetchButton.disabled).toBe(true);
      expect(remoteUrl.value).toBe('');
    });
  });
});
