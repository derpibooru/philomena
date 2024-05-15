import { hideThumb, showBlock, showThumb, spoilerBlock, spoilerThumb } from '../image';
import { getRandomArrayItem } from '../../../test/randomness';
import { mockStorage } from '../../../test/mock-storage';
import { createEvent, fireEvent } from '@testing-library/dom';
import { EventType } from '@testing-library/dom/types/events';
import { SpoilerType } from '../../../types/booru-object';
import { beforeEach } from 'vitest';

describe('Image utils', () => {
  const hiddenClass = 'hidden';
  const spoilerOverlayClass = 'js-spoiler-info-overlay';
  const serveHidpiStorageKey = 'serve_hidpi';
  const mockSpoilerReason = 'Mock reason';
  const mockSpoilerUri = '/images/tagblocked.svg';
  const mockImageUri = 'data:image/gif;base64,R0lGODlhAQABAIAAAP///////yH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';
  const getMockImageSizeUrls = (extension: string) => ({
    thumb: `https://example.com/thumb.${extension}`,
    small: `https://example.com/small.${extension}`,
    medium: `https://example.com/medium.${extension}`,
    large: `https://example.com/large.${extension}`,
  });
  type ImageSize = keyof ReturnType<typeof getMockImageSizeUrls>;
  const PossibleImageSizes: ImageSize[] = ['thumb', 'small', 'medium', 'large'];

  const applyMockDataAttributes = (element: HTMLElement, extension: string, size?: ImageSize) => {
    const mockSize = size || getRandomArrayItem(PossibleImageSizes);
    const mockSizeUrls = getMockImageSizeUrls(extension);
    element.setAttribute('data-size', mockSize);
    element.setAttribute('data-uris', JSON.stringify(mockSizeUrls));
    return { mockSize, mockSizeUrls };
  };
  const createMockSpoilerOverlay = () => {
    const mockSpoilerOverlay = document.createElement('div');
    mockSpoilerOverlay.classList.add(spoilerOverlayClass);
    return mockSpoilerOverlay;
  };
  const createMockElementWithPicture = (extension: string, size?: ImageSize) => {
    const mockElement = document.createElement('div');
    const { mockSizeUrls, mockSize } = applyMockDataAttributes(mockElement, extension, size);

    const mockPicture = document.createElement('picture');
    mockElement.appendChild(mockPicture);

    const mockSizeImage = new Image();
    mockPicture.appendChild(mockSizeImage);

    const mockSpoilerOverlay = createMockSpoilerOverlay();
    mockElement.appendChild(mockSpoilerOverlay);

    return {
      mockElement,
      mockPicture,
      mockSize,
      mockSizeImage,
      mockSizeUrls,
      mockSpoilerOverlay,
    };
  };
  const imageFilteredClass = 'image-filtered';
  const imageShowClass = 'image-show';
  const spoilerPendingClass = 'spoiler-pending';
  const createImageFilteredElement = (mockElement: HTMLDivElement) => {
    const mockFilteredImageElement = document.createElement('div');
    mockFilteredImageElement.classList.add(imageFilteredClass);
    mockElement.appendChild(mockFilteredImageElement);
    return { mockFilteredImageElement };
  };
  const createImageShowElement = (mockElement: HTMLDivElement) => {
    const mockShowElement = document.createElement('div');
    mockShowElement.classList.add(imageShowClass);
    mockShowElement.classList.add(hiddenClass);
    mockElement.appendChild(mockShowElement);
    return { mockShowElement };
  };

  describe('showThumb', () => {
    let mockServeHidpiValue: string | null = null;
    mockStorage({
      getItem(key: string) {
        if (key !== serveHidpiStorageKey) return null;

        return mockServeHidpiValue;
      },
    });

    beforeEach(() => {
      mockServeHidpiValue = null;
    });

    describe('video thumbnail', () => {
      type CreateMockElementsOptions = {
        extension: string;
        videoClasses?: string[];
        imgClasses?: string[];
      }

      const createMockElements = ({ videoClasses, imgClasses, extension }: CreateMockElementsOptions) => {
        const mockElement = document.createElement('div');
        const { mockSize, mockSizeUrls } = applyMockDataAttributes(mockElement, extension);

        const mockImage = new Image();
        mockImage.src = mockImageUri;
        if (imgClasses) {
          imgClasses.forEach(videoClass => {
            mockImage.classList.add(videoClass);
          });
        }
        mockElement.appendChild(mockImage);

        const mockVideo = document.createElement('video');
        if (videoClasses) {
          videoClasses.forEach(videoClass => {
            mockVideo.classList.add(videoClass);
          });
        }
        mockElement.appendChild(mockVideo);
        const playSpy = vi.spyOn(mockVideo, 'play').mockReturnValue(Promise.resolve());

        const mockSpoilerOverlay = createMockSpoilerOverlay();
        mockElement.appendChild(mockSpoilerOverlay);

        return {
          mockElement,
          mockImage,
          mockSize,
          mockSizeUrls,
          mockSpoilerOverlay,
          mockVideo,
          playSpy,
        };
      };

      it('should hide the img element and show the video instead if no picture element is present', () => {
        const {
          mockElement,
          mockImage,
          playSpy,
          mockVideo,
          mockSize,
          mockSizeUrls,
          mockSpoilerOverlay,
        } = createMockElements({
          extension: 'webm',
          videoClasses: ['hidden'],
        });

        const result = showThumb(mockElement);

        expect(mockImage).toHaveClass(hiddenClass);
        expect(mockVideo.children).toHaveLength(2);

        const webmSourceElement = mockVideo.children[0];
        const webmSource = mockSizeUrls[mockSize];
        expect(webmSourceElement.nodeName).toEqual('SOURCE');
        expect(webmSourceElement.getAttribute('type')).toEqual('video/webm');
        expect(webmSourceElement.getAttribute('src')).toEqual(webmSource);

        const mp4SourceElement = mockVideo.children[1];
        expect(mp4SourceElement.nodeName).toEqual('SOURCE');
        expect(mp4SourceElement.getAttribute('type')).toEqual('video/mp4');
        expect(mp4SourceElement.getAttribute('src')).toEqual(webmSource.replace('webm', 'mp4'));

        expect(mockVideo).not.toHaveClass(hiddenClass);
        expect(playSpy).toHaveBeenCalledTimes(1);

        expect(mockSpoilerOverlay).toHaveClass(hiddenClass);

        expect(result).toBe(true);
      });

      ['data-size', 'data-uris'].forEach(missingAttributeName => {
        it(`should return early if the ${missingAttributeName} attribute is missing`, () => {
          const { mockElement } = createMockElements({
            extension: 'webm',
          });
          const jsonParseSpy = vi.spyOn(JSON, 'parse');

          mockElement.removeAttribute(missingAttributeName);

          try {
            const result = showThumb(mockElement);
            expect(result).toBe(false);
            expect(jsonParseSpy).not.toHaveBeenCalled();
          }
          finally {
            jsonParseSpy.mockRestore();
          }
        });
      });

      it('should return early if there is no video element', () => {
        const { mockElement, mockVideo, playSpy } = createMockElements({
          extension: 'webm',
        });

        mockElement.removeChild(mockVideo);

        const result = showThumb(mockElement);
        expect(result).toBe(false);
        expect(playSpy).not.toHaveBeenCalled();
      });

      it('should return early if img element is missing', () => {
        const { mockElement, mockImage, playSpy } = createMockElements({
          extension: 'webm',
          imgClasses: ['hidden'],
        });

        mockElement.removeChild(mockImage);

        const result = showThumb(mockElement);
        expect(result).toBe(false);
        expect(playSpy).not.toHaveBeenCalled();
      });

      it('should return early if img element already has the hidden class', () => {
        const { mockElement, playSpy } = createMockElements({
          extension: 'webm',
          imgClasses: ['hidden'],
        });

        const result = showThumb(mockElement);
        expect(result).toBe(false);
        expect(playSpy).not.toHaveBeenCalled();
      });
    });

    it('should show the correct thumbnail image for jpg extension', () => {
      const {
        mockElement,
        mockSizeImage,
        mockSizeUrls,
        mockSize,
        mockSpoilerOverlay,
      } = createMockElementWithPicture('jpg');
      const result = showThumb(mockElement);

      expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize]);
      expect(mockSizeImage.srcset).toBe('');

      expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
      expect(result).toBe(true);
    });

    it('should show the correct thumbnail image for gif extension', () => {
      const {
        mockElement,
        mockSizeImage,
        mockSizeUrls,
        mockSize,
        mockSpoilerOverlay,
      } = createMockElementWithPicture('gif');
      const result = showThumb(mockElement);

      expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize]);
      expect(mockSizeImage.srcset).toBe('');

      expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
      expect(result).toBe(true);
    });

    it('should show the correct thumbnail image for webm extension', () => {
      const {
        mockElement,
        mockSpoilerOverlay,
        mockSizeImage,
        mockSizeUrls,
        mockSize,
      } = createMockElementWithPicture('webm');
      const result = showThumb(mockElement);

      expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize].replace('webm', 'gif'));
      expect(mockSizeImage.srcset).toBe('');

      expect(mockSpoilerOverlay).not.toHaveClass(hiddenClass);
      expect(mockSpoilerOverlay).toHaveTextContent('WebM');

      expect(result).toBe(true);
    });

    describe('high DPI srcset handling', () => {
      beforeEach(() => {
        mockServeHidpiValue = 'true';
      });

      const checkSrcsetAttribute = (size: ImageSize, x2size: ImageSize) => {
        const {
          mockElement,
          mockSizeImage,
          mockSizeUrls,
          mockSpoilerOverlay,
        } = createMockElementWithPicture('jpg', size);
        const result = showThumb(mockElement);

        expect(mockSizeImage.src).toBe(mockSizeUrls[size]);
        expect(mockSizeImage.srcset).toContain(`${mockSizeUrls[size]} 1x`);
        expect(mockSizeImage.srcset).toContain(`${mockSizeUrls[x2size]} 2x`);

        expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
        return result;
      };

      it('should set correct srcset on img if thumbUri is NOT a gif at small size', () => {
        const result = checkSrcsetAttribute('small', 'medium');
        expect(result).toBe(true);
      });

      it('should set correct srcset on img if thumbUri is NOT a gif at medium size', () => {
        const result = checkSrcsetAttribute('medium', 'large');
        expect(result).toBe(true);
      });

      it('should NOT set srcset on img if thumbUri is a gif at small size', () => {
        const mockSize = 'small';
        const {
          mockElement,
          mockSizeImage,
          mockSizeUrls,
          mockSpoilerOverlay,
        } = createMockElementWithPicture('gif', mockSize);
        const result = showThumb(mockElement);

        expect(mockSizeImage.src).toBe(mockSizeUrls[mockSize]);
        expect(mockSizeImage.srcset).toBe('');

        expect(mockSpoilerOverlay).toHaveClass(hiddenClass);
        expect(result).toBe(true);
      });
    });

    it('should return false if img cannot be found', () => {
      const { mockElement, mockPicture, mockSizeImage } = createMockElementWithPicture('jpg');
      mockPicture.removeChild(mockSizeImage);
      const result = showThumb(mockElement);
      expect(result).toBe(false);
    });

    it('should return false if img source already matches thumbUri', () => {
      const {
        mockElement,
        mockSizeImage,
        mockSizeUrls,
        mockSize,
      } = createMockElementWithPicture('jpg');
      mockSizeImage.src = mockSizeUrls[mockSize];
      const result = showThumb(mockElement);
      expect(result).toBe(false);
    });

    it('should return false if overlay is missing', () => {
      const { mockElement, mockSpoilerOverlay } = createMockElementWithPicture('jpg');
      mockSpoilerOverlay.parentNode?.removeChild(mockSpoilerOverlay);
      const result = showThumb(mockElement);
      expect(result).toBe(false);
    });
  });

  describe('showBlock', () => {
    it('should hide the filtered image element and show the image', () => {
      const mockElement = document.createElement('div');

      const { mockFilteredImageElement } = createImageFilteredElement(mockElement);
      const { mockShowElement } = createImageShowElement(mockElement);

      showBlock(mockElement);

      expect(mockFilteredImageElement).toHaveClass(hiddenClass);
      expect(mockShowElement).not.toHaveClass(hiddenClass);
      expect(mockShowElement).toHaveClass(spoilerPendingClass);
    });

    it('should play the video if it is present', () => {
      const mockElement = document.createElement('div');
      const { mockShowElement } = createImageShowElement(mockElement);
      const mockVideo = document.createElement('video');
      mockShowElement.appendChild(mockVideo);

      const playSpy = vi.spyOn(mockVideo, 'play').mockReturnValue(Promise.resolve());

      showBlock(mockElement);

      expect(playSpy).toHaveBeenCalledTimes(1);
    });

    it('should not throw if image-filtered element is missing', () => {
      const mockElement = document.createElement('div');
      createImageShowElement(mockElement);
      expect(() => showBlock(mockElement)).not.toThrow();
    });

    it('should not throw if image-show element is missing', () => {
      const mockElement = document.createElement('div');
      createImageFilteredElement(mockElement);
      expect(() => showBlock(mockElement)).not.toThrow();
    });
  });

  describe('hideThumb', () => {
    describe('hideVideoThumb', () => {
      it('should return early if picture AND video elements are missing', () => {
        const mockElement = document.createElement('div');

        const querySelectorSpy = vi.spyOn(mockElement, 'querySelector');

        hideThumb(mockElement, mockSpoilerUri, mockSpoilerReason);

        try {
          expect(querySelectorSpy).toHaveBeenCalledTimes(2);
          expect(querySelectorSpy).toHaveBeenNthCalledWith(1, 'picture');
          expect(querySelectorSpy).toHaveBeenNthCalledWith(2, 'video');
        }
        finally {
          querySelectorSpy.mockRestore();
        }
      });
      it('should return early if picture and img elements are missing BUT video element is present', () => {
        const mockElement = document.createElement('div');
        const mockVideo = document.createElement('video');
        mockElement.appendChild(mockVideo);
        const pauseSpy = vi.spyOn(mockVideo, 'pause').mockReturnValue(undefined);

        const querySelectorSpy = vi.spyOn(mockElement, 'querySelector');

        hideThumb(mockElement, mockSpoilerUri, mockSpoilerReason);

        try {
          expect(querySelectorSpy).toHaveBeenCalledTimes(4);
          expect(querySelectorSpy).toHaveBeenNthCalledWith(1, 'picture');
          expect(querySelectorSpy).toHaveBeenNthCalledWith(2, 'video');
          expect(querySelectorSpy).toHaveBeenNthCalledWith(3, 'img');
          expect(querySelectorSpy).toHaveBeenNthCalledWith(4, `.${spoilerOverlayClass}`);
          expect(mockVideo).not.toHaveClass(hiddenClass);
        }
        finally {
          querySelectorSpy.mockRestore();
          pauseSpy.mockRestore();
        }
      });

      it('should hide video thumbnail if picture element is missing BUT video element is present', () => {
        const mockElement = document.createElement('div');
        const mockVideo = document.createElement('video');
        mockElement.appendChild(mockVideo);
        const pauseSpy = vi.spyOn(mockVideo, 'pause').mockReturnValue(undefined);
        const mockImage = document.createElement('img');
        mockImage.classList.add(hiddenClass);
        mockElement.appendChild(mockImage);
        const mockOverlay = document.createElement('span');
        mockOverlay.classList.add(spoilerOverlayClass, hiddenClass);
        mockElement.appendChild(mockOverlay);

        hideThumb(mockElement, mockSpoilerUri, mockSpoilerReason);

        try {
          expect(mockImage).not.toHaveClass(hiddenClass);
          expect(mockImage).toHaveAttribute('src', mockSpoilerUri);
          expect(mockOverlay).toHaveTextContent(mockSpoilerReason);
          expect(mockVideo).toBeEmptyDOMElement();
          expect(mockVideo).toHaveClass(hiddenClass);
          expect(pauseSpy).toHaveBeenCalled();
        }
        finally {
          pauseSpy.mockRestore();
        }
      });
    });

    it('should return early if picture element is present AND img element is missing', () => {
      const mockElement = document.createElement('div');
      const mockPicture = document.createElement('picture');
      mockElement.appendChild(mockPicture);

      const imgQuerySelectorSpy = vi.spyOn(mockElement, 'querySelector');
      const pictureQuerySelectorSpy = vi.spyOn(mockPicture, 'querySelector');

      hideThumb(mockElement, mockSpoilerUri, mockSpoilerReason);

      try {
        expect(imgQuerySelectorSpy).toHaveBeenCalledTimes(2);
        expect(pictureQuerySelectorSpy).toHaveBeenCalledTimes(1);

        expect(imgQuerySelectorSpy).toHaveBeenNthCalledWith(1, 'picture');
        expect(pictureQuerySelectorSpy).toHaveBeenNthCalledWith(1, 'img');
        expect(imgQuerySelectorSpy).toHaveBeenNthCalledWith(2, `.${spoilerOverlayClass}`);
      }
      finally {
        imgQuerySelectorSpy.mockRestore();
        pictureQuerySelectorSpy.mockRestore();
      }
    });

    it('should hide img thumbnail if picture element is present AND img element is present', () => {
      const mockElement = document.createElement('div');
      const mockPicture = document.createElement('picture');
      mockElement.appendChild(mockPicture);
      const mockImage = document.createElement('img');
      mockPicture.appendChild(mockImage);
      const mockOverlay = document.createElement('span');
      mockOverlay.classList.add(spoilerOverlayClass, hiddenClass);
      mockElement.appendChild(mockOverlay);

      hideThumb(mockElement, mockSpoilerUri, mockSpoilerReason);

      expect(mockImage).toHaveAttribute('srcset', '');
      expect(mockImage).toHaveAttribute('src', mockSpoilerUri);
      expect(mockOverlay).toContainHTML(mockSpoilerReason);
      expect(mockOverlay).not.toHaveClass(hiddenClass);
    });
  });

  describe('spoilerThumb', () => {
    const testSpoilerThumb = (handlers?: [EventType, EventType]) => {
      const { mockElement, mockSpoilerOverlay, mockSizeImage } = createMockElementWithPicture('jpg');
      const addEventListenerSpy = vi.spyOn(mockElement, 'addEventListener');

      spoilerThumb(mockElement, mockSpoilerUri, mockSpoilerReason);

      // Element should be hidden by the call
      expect(mockSizeImage).toHaveAttribute('src', mockSpoilerUri);
      expect(mockSpoilerOverlay).not.toHaveClass(hiddenClass);
      expect(mockSpoilerOverlay).toContainHTML(mockSpoilerReason);

      // If addEventListener calls are not expected, bail
      if (!handlers) {
        expect(addEventListenerSpy).not.toHaveBeenCalled();
        return;
      }

      const [firstHandler, secondHandler] = handlers;

      // Event listeners should be attached to correct events
      expect(addEventListenerSpy).toHaveBeenCalledTimes(2);
      expect(addEventListenerSpy.mock.calls[0][0]).toBe(firstHandler.toLowerCase());
      expect(addEventListenerSpy.mock.calls[1][0]).toBe(secondHandler.toLowerCase());

      // Clicking once should reveal the image and hide spoiler elements
      let clickEvent = createEvent[firstHandler](mockElement);
      fireEvent(mockElement, clickEvent);
      if (firstHandler === 'click') {
        expect(clickEvent.defaultPrevented).toBe(true);
      }
      expect(mockSizeImage).not.toHaveAttribute('src', mockSpoilerUri);
      expect(mockSpoilerOverlay).toHaveClass(hiddenClass);

      if (firstHandler === 'click') {
        // Second attempt to click a shown spoiler should not cause default prevention
        clickEvent = createEvent.click(mockElement);
        fireEvent(mockElement, clickEvent);
        expect(clickEvent.defaultPrevented).toBe(false);
      }

      // Moving the mouse away should hide the image and show the overlay again
      const mouseLeaveEvent = createEvent.mouseLeave(mockElement);
      fireEvent(mockElement, mouseLeaveEvent);
      expect(mockSizeImage).toHaveAttribute('src', mockSpoilerUri);
      expect(mockSpoilerOverlay).not.toHaveClass(hiddenClass);
      expect(mockSpoilerOverlay).toContainHTML(mockSpoilerReason);
    };
    let lastSpoilerType: SpoilerType;

    beforeEach(() => {
      lastSpoilerType = window.booru.spoilerType;
    });

    afterEach(() => {
      window.booru.spoilerType = lastSpoilerType;
    });

    it('should add click and mouseleave handlers for click spoiler type', () => {
      window.booru.spoilerType = 'click';
      expect.hasAssertions();
      testSpoilerThumb(['click', 'mouseLeave']);
    });

    it('should add mouseenter and mouseleave handlers for hover spoiler type', () => {
      window.booru.spoilerType = 'hover';
      expect.hasAssertions();
      testSpoilerThumb(['mouseEnter', 'mouseLeave']);
    });

    it('should not add event handlers for off spoiler type', () => {
      window.booru.spoilerType = 'off';
      expect.hasAssertions();
      testSpoilerThumb();
    });

    it('should not add event handlers for static spoiler type', () => {
      window.booru.spoilerType = 'static';
      expect.hasAssertions();
      testSpoilerThumb();
    });
  });

  describe('spoilerBlock', () => {
    const filterExplanationClass = 'filter-explanation';
    const createFilteredImageElement = () => {
      const mockImageFiltered = document.createElement('div');
      mockImageFiltered.classList.add(imageFilteredClass, hiddenClass);

      const mockImage = new Image();
      mockImage.src = mockImageUri;
      mockImageFiltered.appendChild(mockImage);

      return { mockImageFiltered, mockImage };
    };
    const createMockElement = (appendImageShow = true, appendImageFiltered = true) => {
      const mockElement = document.createElement('div');
      const { mockImageFiltered, mockImage } = createFilteredImageElement();
      if (appendImageFiltered) mockElement.appendChild(mockImageFiltered);
      const mockExplanation = document.createElement('span');
      mockExplanation.classList.add(filterExplanationClass);
      mockElement.appendChild(mockExplanation);

      const mockImageShow = document.createElement('div');
      mockImageShow.classList.add(imageShowClass);
      if (appendImageShow) mockElement.appendChild(mockImageShow);

      return { mockElement, mockImage, mockExplanation, mockImageShow, mockImageFiltered };
    };

    it('should not throw if image element is missing', () => {
      const mockElement = document.createElement('div');
      const { mockImageFiltered, mockImage } = createFilteredImageElement();
      mockImage.parentNode?.removeChild(mockImage);
      mockElement.appendChild(mockImageFiltered);
      expect(() => spoilerBlock(mockElement, mockSpoilerUri, mockSpoilerReason)).not.toThrow();
    });

    it('should update the elements with the parameters and set classes if image element is found', () => {
      const { mockElement, mockImage, mockExplanation, mockImageShow, mockImageFiltered } = createMockElement();

      spoilerBlock(mockElement, mockSpoilerUri, mockSpoilerReason);

      expect(mockImage).toHaveAttribute('src', mockSpoilerUri);
      expect(mockExplanation).toContainHTML(mockSpoilerReason);
      expect(mockImageShow).toHaveClass(hiddenClass);
      expect(mockImageFiltered).not.toHaveClass(hiddenClass);
    });

    it('should not throw if image-filtered element is missing', () => {
      const { mockElement } = createMockElement(true, false);
      expect(() => spoilerBlock(mockElement, mockSpoilerUri, mockSpoilerReason)).not.toThrow();
    });

    it('should not throw if image-show element is missing', () => {
      const { mockElement } = createMockElement(false, true);
      expect(() => spoilerBlock(mockElement, mockSpoilerUri, mockSpoilerReason)).not.toThrow();
    });
  });
});
