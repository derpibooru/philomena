import { $, $$ } from '../utils/dom';
import { assertNotNull } from '../utils/assert';
import { setupQuickTag } from '../quick-tag';
import { fetchMock } from '../../test/fetch-mock.ts';
import { waitFor } from '@testing-library/dom';

const quickTagData = `<div>
  <a class="js-quick-tag">Tag</a>
  <a class="js-quick-tag--abort hidden"><span>Abort tagging</span></a>
  <a class="js-quick-tag--submit hidden"><span>Submit</span></a>
  <a class="js-quick-tag--all hidden"><span>Toggle all</span></a>
  <div id="imagelist-container">
    <div class="media-box" data-image-id="0">
      <div class="media-box__header" data-image-id="0"></div>
    </div>
    <div class="media-box" data-image-id="1">
      <div class="media-box__header" data-image-id="1"></div>
    </div>
  </div>
</div>`;

describe('Batch tagging', () => {
  let tagButton: HTMLAnchorElement;
  let abortButton: HTMLAnchorElement;
  let submitButton: HTMLAnchorElement;
  let toggleAllButton: HTMLAnchorElement;
  let mediaBoxes: HTMLDivElement[];

  beforeEach(() => {
    localStorage.clear();
    document.body.innerHTML = quickTagData;

    tagButton = assertNotNull($<HTMLAnchorElement>('.js-quick-tag'));
    abortButton = assertNotNull($<HTMLAnchorElement>('.js-quick-tag--abort'));
    submitButton = assertNotNull($<HTMLAnchorElement>('.js-quick-tag--submit'));
    toggleAllButton = assertNotNull($<HTMLAnchorElement>('.js-quick-tag--all'));
    mediaBoxes = $$<HTMLDivElement>('.media-box');
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('should prompt the user on click', () => {
    const spy = vi.spyOn(window, 'prompt').mockImplementation(() => 'a');
    tagButton.click();

    expect(spy).toHaveBeenCalledOnce();
    expect(tagButton.classList).toContain('hidden');
    expect(abortButton.classList).not.toContain('hidden');
    expect(submitButton.classList).not.toContain('hidden');
    expect(toggleAllButton.classList).not.toContain('hidden');
  });

  it('should not modify media boxes before entry', () => {
    mediaBoxes[0].click();
    expect(mediaBoxes[0].firstElementChild).not.toHaveClass('media-box__header--selected');
  });

  it('should restore the list of tagged images on reload', () => {
    // TODO: this is less than ideal, because it depends on the internal
    // implementation of the quick-tag file. But we can't reload the page
    // with jsdom.
    localStorage.setItem('quickTagQueue', JSON.stringify(['0', '1']));
    localStorage.setItem('quickTagName', JSON.stringify('a'));

    setupQuickTag();
    expect(mediaBoxes[0].firstElementChild).toHaveClass('media-box__header--selected');
    expect(mediaBoxes[1].firstElementChild).toHaveClass('media-box__header--selected');
  });

  describe('after entry', () => {
    beforeEach(() => {
      vi.spyOn(window, 'prompt').mockImplementation(() => 'a');
      tagButton.click();
    });

    it('should abort the tagging process if accepted', () => {
      const spy = vi.spyOn(window, 'confirm').mockImplementation(() => true);
      abortButton.click();

      expect(spy).toHaveBeenCalledOnce();
      expect(tagButton.classList).not.toContain('hidden');
      expect(abortButton.classList).toContain('hidden');
      expect(submitButton.classList).toContain('hidden');
      expect(toggleAllButton.classList).toContain('hidden');
    });

    it('should not abort the tagging process if rejected', () => {
      const spy = vi.spyOn(window, 'confirm').mockImplementation(() => false);
      abortButton.click();

      expect(spy).toHaveBeenCalledOnce();
      expect(tagButton.classList).toContain('hidden');
      expect(abortButton.classList).not.toContain('hidden');
      expect(submitButton.classList).not.toContain('hidden');
      expect(toggleAllButton.classList).not.toContain('hidden');
    });

    it('should toggle media box state on click', () => {
      mediaBoxes[0].click();
      expect(mediaBoxes[0].firstElementChild).toHaveClass('media-box__header--selected');
      expect(mediaBoxes[1].firstElementChild).not.toHaveClass('media-box__header--selected');
    });

    it('should toggle all media box states', () => {
      mediaBoxes[0].click();
      toggleAllButton.click();
      expect(mediaBoxes[0].firstElementChild).not.toHaveClass('media-box__header--selected');
      expect(mediaBoxes[1].firstElementChild).toHaveClass('media-box__header--selected');
    });
  });

  describe('for submission', () => {
    beforeAll(() => {
      fetchMock.enableMocks();
    });

    afterAll(() => {
      fetchMock.disableMocks();
    });

    beforeEach(() => {
      vi.spyOn(window, 'prompt').mockImplementation(() => 'a');
      tagButton.click();

      fetchMock.resetMocks();
      mediaBoxes[0].click();
      mediaBoxes[1].click();
    });

    it('should return to normal state on successful submission', () => {
      fetchMock.mockResponse('{"failed":[]}');
      submitButton.click();

      expect(fetch).toHaveBeenCalledOnce();

      return waitFor(() => {
        expect(mediaBoxes[0].firstElementChild).not.toHaveClass('media-box__header--selected');
        expect(mediaBoxes[1].firstElementChild).not.toHaveClass('media-box__header--selected');
      });
    });

    it('should show error on failed submission', () => {
      fetchMock.mockResponse('{"failed":[0,1]}');
      submitButton.click();

      const spy = vi.spyOn(window, 'alert').mockImplementation(() => {});

      expect(fetch).toHaveBeenCalledOnce();

      return waitFor(() => {
        expect(spy).toHaveBeenCalledOnce();
        expect(mediaBoxes[0].firstElementChild).not.toHaveClass('media-box__header--selected');
        expect(mediaBoxes[1].firstElementChild).not.toHaveClass('media-box__header--selected');
      });
    });
  });
});
