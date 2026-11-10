import { bindImageTarget, selectVersion, pickAndResize, ImageTargetElement } from '../image-expansion';
import store from '../utils/store';
import { fireEvent } from '@testing-library/dom';
import { $ } from '../utils/dom';

describe('image-expansion', () => {
  let originalClientWidth: number;
  let originalClientHeight: number;
  let originalDevicePixelRatio: number;

  beforeEach(() => {
    // Save original values
    originalClientWidth = document.documentElement.clientWidth;
    originalClientHeight = document.documentElement.clientHeight;
    originalDevicePixelRatio = window.devicePixelRatio;

    // Set default viewport dimensions
    Object.defineProperty(document.documentElement, 'clientWidth', {
      writable: true,
      configurable: true,
      value: 1920,
    });
    Object.defineProperty(document.documentElement, 'clientHeight', {
      writable: true,
      configurable: true,
      value: 1080,
    });

    // Clear store
    vi.spyOn(store, 'get').mockReturnValue(null);
  });

  afterEach(() => {
    // Restore original values
    Object.defineProperty(document.documentElement, 'clientWidth', {
      writable: true,
      configurable: true,
      value: originalClientWidth,
    });
    Object.defineProperty(document.documentElement, 'clientHeight', {
      writable: true,
      configurable: true,
      value: originalClientHeight,
    });
    Object.defineProperty(window, 'devicePixelRatio', {
      writable: true,
      configurable: true,
      value: originalDevicePixelRatio,
    });
    vi.restoreAllMocks();
  });

  describe('selectVersion', () => {
    it('should return "tall" for comic-sized images on wide viewports', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 1280,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 1024,
      });

      const result = selectVersion(400, 3000, 1000000, 'image/png');
      expect(result).toBe('tall');
    });

    it('should return "medium" when viewport is between small and medium', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 640,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 480,
      });

      const result = selectVersion(1920, 1080, 1000000, 'image/png');
      expect(result).toBe('medium');
    });

    it('should return "full" when viewport is larger than all versions and size is reasonable', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 1920,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 1080,
      });

      const result = selectVersion(2000, 1500, 1000000, 'image/png');
      expect(result).toBe('full');
    });

    it('should return "large" when viewport is larger but file size exceeds limit', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 1920,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 1080,
      });

      const result = selectVersion(2000, 1500, 30_000_000, 'image/png');
      expect(result).toBe('large');
    });

    it('should return "full" for video/webm regardless of file size', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 1920,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 1080,
      });

      const result = selectVersion(2000, 1500, 50_000_000, 'video/webm');
      expect(result).toBe('full');
    });

    it('should scale viewport by devicePixelRatio when serve_hidpi is enabled', () => {
      Object.defineProperty(window, 'devicePixelRatio', {
        writable: true,
        configurable: true,
        value: 2,
      });
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 640,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 480,
      });

      vi.spyOn(store, 'get').mockReturnValue(true);

      // With 2x DPR, effective viewport is 1280x960, so it should pick large
      const result = selectVersion(1920, 1080, 1000000, 'image/png');
      expect(result).toBe('large');
    });

    it('should handle missing devicePixelRatio', () => {
      Object.defineProperty(window, 'devicePixelRatio', {
        writable: true,
        configurable: true,
        value: undefined,
      });
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 640,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 480,
      });

      vi.spyOn(store, 'get').mockReturnValue(true);

      const result = selectVersion(1920, 1080, 1000000, 'image/png');
      expect(result).toBe('medium');
    });

    it('should select version based on height when height constraint is reached first', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 1920,
      });
      Object.defineProperty(document.documentElement, 'clientHeight', {
        writable: true,
        configurable: true,
        value: 400,
      });

      const result = selectVersion(800, 1200, 1000000, 'image/png');
      expect(result).toBe('medium');
    });
  });

  describe('pickAndResize', () => {
    function createImageTarget(
      width: string,
      height: string,
      imageSize: string,
      mimeType: string,
      scaled: string,
      uris: string,
    ): ImageTargetElement {
      const elem = document.createElement('div');
      elem.className = 'image-target';
      elem.dataset.width = width;
      elem.dataset.height = height;
      elem.dataset.imageSize = imageSize;
      elem.dataset.mimeType = mimeType;
      elem.dataset.scaled = scaled;
      elem.dataset.uris = uris;
      return elem as unknown as ImageTargetElement;
    }

    it('should render a static image when not scaled', () => {
      const uris = JSON.stringify({
        full: '/images/full.png',
        large: '/images/large.png',
        medium: '/images/medium.png',
        small: '/images/small.png',
      });
      const elem = createImageTarget('1920', '1080', '1000000', 'image/png', 'false', uris);

      pickAndResize(elem);

      expect(elem.innerHTML).toContain('<picture>');
      expect(elem.innerHTML).toContain('src="/images/full.png"');
      expect(elem.innerHTML).toContain('width="1920"');
      expect(elem.innerHTML).toContain('height="1080"');
      expect(elem.innerHTML).not.toContain('class=');
    });

    it('should render a scaled image when scaled is true', () => {
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 640,
      });

      const uris = JSON.stringify({
        full: '/images/full.png',
        large: '/images/large.png',
        medium: '/images/medium.png',
        small: '/images/small.png',
      });
      const elem = createImageTarget('1920', '1080', '1000000', 'image/png', 'true', uris);

      pickAndResize(elem);

      expect(elem.innerHTML).toContain('<picture>');
      expect(elem.innerHTML).toContain('src="/images/medium.png"');
      expect(elem.innerHTML).toContain('class="image-scaled"');
    });

    it('should render a partscaled image', () => {
      const uris = JSON.stringify({
        full: '/images/full.png',
        large: '/images/large.png',
        medium: '/images/medium.png',
        small: '/images/small.png',
      });
      const elem = createImageTarget('1920', '1080', '1000000', 'image/png', 'partscaled', uris);

      pickAndResize(elem);

      expect(elem.innerHTML).toContain('<picture>');
      expect(elem.innerHTML).toContain('src="/images/full.png"');
      expect(elem.innerHTML).toContain('class="image-partscaled"');
    });

    it('should not re-render if the image content is the same', () => {
      const uris = JSON.stringify({
        full: '/images/full.png',
      });
      const elem = createImageTarget('1920', '1080', '1000000', 'image/png', 'false', uris);

      pickAndResize(elem);
      const firstHTML = elem.innerHTML;

      pickAndResize(elem);
      const secondHTML = elem.innerHTML;

      expect(firstHTML).toBe(secondHTML);
    });

    it('should render webm video with scaled class when scaled is true', () => {
      const uris = JSON.stringify({
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'true', uris);

      pickAndResize(elem);

      const video = $<HTMLVideoElement>('video', elem);
      expect(video).not.toBeNull();
      expect(video?.className).toBe('image-scaled');
    });

    it('should render webm video with partscaled class when scaled is partscaled', () => {
      const uris = JSON.stringify({
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'partscaled', uris);

      pickAndResize(elem);

      const video = $<HTMLVideoElement>('video', elem);
      expect(video).not.toBeNull();
      expect(video?.className).toBe('image-partscaled');
    });

    it('should prefer mp4 when serve_webm is enabled and mp4 is available', () => {
      vi.spyOn(store, 'get').mockReturnValue(true);

      const uris = JSON.stringify({
        full: '/videos/video.webm',
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);

      pickAndResize(elem);

      expect(elem.innerHTML).toContain('src="/videos/video.webm"');
      expect(elem.innerHTML).toContain('src="/videos/video.mp4"');
      expect(elem.innerHTML).toContain('width="1920"');
      expect(elem.innerHTML).toContain('height="1080"');
      expect(elem.classList.contains('full-height')).toBe(true);
    });

    it('should add muted attribute when unmute_videos is not set', () => {
      vi.spyOn(store, 'get').mockReturnValue(null);

      const uris = JSON.stringify({
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);

      pickAndResize(elem);

      expect(elem.innerHTML).toContain('muted');
    });

    it('should not add muted attribute when unmute_videos is true', () => {
      vi.spyOn(store, 'get').mockImplementation((key: string) => {
        if (key === 'unmute_videos') return true;
        return null;
      });

      const uris = JSON.stringify({
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);

      pickAndResize(elem);

      expect(elem.innerHTML).not.toContain('muted');
    });

    it('should not add autoplay attribute when element has hidden class', () => {
      const uris = JSON.stringify({
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);
      elem.classList.add('hidden');

      pickAndResize(elem);

      expect(elem.innerHTML).not.toContain('autoplay');
    });

    it('should add autoplay attribute when element does not have hidden class', () => {
      const uris = JSON.stringify({
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);

      pickAndResize(elem);

      expect(elem.innerHTML).toContain('autoplay');
    });

    it('should handle missing uri gracefully', () => {
      const uris = JSON.stringify({
        small: '/images/small.png',
      });
      const elem = createImageTarget('1920', '1080', '1000000', 'image/png', 'true', uris);

      // Force it to select a version that doesn't exist
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 5000,
      });

      pickAndResize(elem);

      // Should not crash, element should remain empty or unchanged
      expect(elem.innerHTML).toBe('');
    });

    it('should handle malformed uri regex gracefully', () => {
      const uris = JSON.stringify({
        full: 'no-extension',
      });
      const elem = createImageTarget('1920', '1080', '1000000', 'image/png', 'false', uris);

      pickAndResize(elem);

      // Should not crash
      expect(elem.innerHTML).toBe('');
    });

    it('should not re-render video when mp4 source already matches via uris.mp4', () => {
      vi.spyOn(store, 'get').mockImplementation((key: string) => {
        if (key === 'serve_webm') return true;
        return null;
      });

      const uris = JSON.stringify({
        full: '/videos/video.webm',
        webm: '/videos/video.webm',
        mp4: '/videos/alt-video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);

      // First render
      pickAndResize(elem);

      // Manually set up the video element with sources that would match the mp4 condition
      elem.innerHTML = `
        <video controls autoplay loop muted playsinline preload="auto" id="image-display" width="1920" height="1080">
          <source src="/videos/video.webm" type="video/webm">
          <source src="/videos/alt-video.mp4" type="video/mp4">
        </video>
      `;

      const firstHTML = elem.innerHTML;

      // Second render should not re-render because source matches uris.mp4
      pickAndResize(elem);
      const secondHTML = elem.innerHTML;

      expect(firstHTML).toBe(secondHTML);
    });

    it('should not re-render when webm source already matches uri under mp4 mode', () => {
      vi.spyOn(store, 'get').mockImplementation((key: string) => {
        if (key === 'serve_webm') return true;
        return null;
      });

      const uris = JSON.stringify({
        full: '/videos/video.webm',
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);

      // First render
      pickAndResize(elem);

      // Manually alter video to keep webm src equal to uri (so first disjunct matches),
      // but change mp4 to a different file so the second disjunct would be false
      elem.innerHTML = `
        <video controls autoplay loop muted playsinline preload="auto" id="image-display" width="1920" height="1080">
          <source src="/videos/video.webm" type="video/webm">
          <source src="/videos/different.mp4" type="video/mp4">
        </video>
      `;

      const firstHTML = elem.innerHTML;

      // Second render should detect matching webm source (uri) and avoid re-render
      pickAndResize(elem);
      const secondHTML = elem.innerHTML;

      expect(firstHTML).toBe(secondHTML);
    });

    it('should clear and re-render when switching to mp4 with non-matching existing video sources', () => {
      // Force mp4 mode
      vi.spyOn(store, 'get').mockImplementation((key: string) => {
        if (key === 'serve_webm') return true;
        return null;
      });

      const uris = JSON.stringify({
        full: '/videos/target.webm',
        webm: '/videos/target.webm',
        mp4: '/videos/target.mp4',
      });
      const elem = createImageTarget('1920', '1080', '5000000', 'video/webm', 'false', uris);

      // Seed with a different video whose sources do not match either uri or uris.mp4
      elem.innerHTML = `
        <video controls autoplay loop muted playsinline preload="auto" id="image-display" width="1920" height="1080">
          <source src="/videos/old.webm" type="video/webm">
          <source src="/videos/old.mp4" type="video/mp4">
        </video>
      `;

      const before = elem.innerHTML;
      pickAndResize(elem);
      const after = elem.innerHTML;

      // Should have cleared and re-rendered to use the target sources
      expect(after).not.toBe(before);
      expect(after).toContain('/videos/target.webm');
      expect(after).toContain('/videos/target.mp4');
    });
  });

  describe('bindImageTarget', () => {
    function createImageTarget(mimeType: string): HTMLElement {
      const elem = document.createElement('div');
      elem.className = 'image-target';
      elem.dataset.width = '1920';
      elem.dataset.height = '1080';
      elem.dataset.imageSize = '1000000';
      elem.dataset.mimeType = mimeType;
      elem.dataset.scaled = 'true';
      elem.dataset.uris = JSON.stringify({
        full: '/images/full.png',
        large: '/images/large.png',
        medium: '/images/medium.png',
        small: '/images/small.png',
      });
      return elem;
    }

    it('should toggle scaled state on click for images', () => {
      const elem = createImageTarget('image/png');
      document.body.appendChild(elem);

      bindImageTarget();

      expect(elem.dataset.scaled).toBe('true');

      fireEvent.click(elem);
      expect(elem.dataset.scaled).toBe('partscaled');

      fireEvent.click(elem);
      expect(elem.dataset.scaled).toBe('false');

      fireEvent.click(elem);
      expect(elem.dataset.scaled).toBe('true');

      document.body.removeChild(elem);
    });

    it('should not bind click handler for video/webm', () => {
      const elem = createImageTarget('video/webm');
      elem.dataset.uris = JSON.stringify({
        webm: '/videos/video.webm',
        mp4: '/videos/video.mp4',
      });
      document.body.appendChild(elem);

      bindImageTarget();

      const initialScaled = elem.dataset.scaled;
      fireEvent.click(elem);

      // Should not change because click handler should not be bound
      expect(elem.dataset.scaled).toBe(initialScaled);

      document.body.removeChild(elem);
    });

    it('should re-render image on window resize', () => {
      const elem = createImageTarget('image/png');
      document.body.appendChild(elem);

      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 640,
      });

      bindImageTarget();

      expect(elem.innerHTML).toContain('medium.png');

      // Change viewport size
      Object.defineProperty(document.documentElement, 'clientWidth', {
        writable: true,
        configurable: true,
        value: 1100,
      });

      fireEvent(window, new Event('resize'));

      // Should now pick a larger version (1100 is larger than medium 800 but smaller than large 1280)
      expect(elem.innerHTML).toContain('large.png');

      document.body.removeChild(elem);
    });
  });
});
