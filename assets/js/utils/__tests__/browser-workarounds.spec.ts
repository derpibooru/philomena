import { needsChromiumJpegNormalization, replaceFilterImageHrefIfNeeded } from '../browser-workarounds';

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe('needsChromiumJpegNormalization', () => {
  it.each([
    ['Chromium', true],
    ['Google Chrome', false],
    ['Not A Brand', false],
  ])('uses client-hint brand %s instead of the user agent', (brand, expected) => {
    vi.stubGlobal('navigator', {
      userAgentData: { brands: [{ brand, version: '123' }] },
      userAgent: 'Chrome/123',
    });
    expect(needsChromiumJpegNormalization()).toBe(expected);
  });

  it('finds Chromium among multiple brands', () => {
    vi.stubGlobal('navigator', {
      userAgentData: { brands: [{ brand: 'Not A Brand' }, { brand: 'Chromium' }] },
    });
    expect(needsChromiumJpegNormalization()).toBe(true);
  });

  it('treats an empty brand list as authoritative', () => {
    vi.stubGlobal('navigator', { userAgentData: { brands: [] }, userAgent: 'Chrome/123' });
    expect(needsChromiumJpegNormalization()).toBe(false);
  });

  it.each([undefined, {}])('falls back when client-hint brands are unavailable: %j', userAgentData => {
    vi.stubGlobal('navigator', { userAgentData, userAgent: 'Chrome/123' });
    expect(needsChromiumJpegNormalization()).toBe(true);
  });

  it.each([
    ['Mozilla/5.0 Chrome/123.0 Safari/537.36', true],
    ['Chromium/123.0', true],
    ['Edg/123.0', true],
    ['OPR/108.0', true],
    ['Mozilla/5.0 Firefox/124.0', false],
    ['Version/17.0 Safari/605.1.15', false],
    ['CriOS/123.0 Mobile/15E148 Safari/604.1', false],
    ['NotChrome/123.0', false],
    ['', false],
  ])('detects the fallback user agent %s', (userAgent, expected) => {
    vi.stubGlobal('navigator', { userAgent });
    expect(needsChromiumJpegNormalization()).toBe(expected);
  });
});

describe('replaceFilterImageHrefIfNeeded', () => {
  const source = 'https://cdn.example/image.jpg';
  let image: HTMLImageElement;
  let element: SVGFEImageElement;

  beforeEach(() => {
    image = document.createElement('img');
    Object.defineProperties(image, {
      naturalWidth: { value: 640 },
      naturalHeight: { value: 480 },
    });
    function createImage() {
      return image;
    }
    vi.stubGlobal('Image', vi.fn(createImage));
    element = document.createElementNS('http://www.w3.org/2000/svg', 'feImage');
    // jsdom does not implement SVGAnimatedString.
    Object.defineProperty(element, 'href', { value: { baseVal: source } });
  });

  it.each(['image.png', 'image.gif', 'image.webp', 'data:image/png;base64,abc'])('leaves %s untouched', async href => {
    element.href.baseVal = href;
    await replaceFilterImageHrefIfNeeded(element);
    expect(element.href.baseVal).toBe(href);
    expect(Image).not.toHaveBeenCalled();
  });

  it('loads anonymously and converts at natural dimensions using the CPU canvas path', async () => {
    const drawImage = vi.fn();
    const getContext = vi
      .spyOn(HTMLCanvasElement.prototype, 'getContext')
      .mockReturnValue({ drawImage } as unknown as CanvasRenderingContext2D);
    const toBlob = vi.spyOn(HTMLCanvasElement.prototype, 'toBlob').mockImplementation((callback, _type) => {
      callback(new Blob());
    });
    const srcSetter = vi.spyOn(image, 'src', 'set');
    const corsSetter = vi.spyOn(image, 'crossOrigin', 'set');

    const replacement = replaceFilterImageHrefIfNeeded(element);
    expect(image.crossOrigin).toBe('anonymous');
    expect(image.src).toBe(source);
    expect(corsSetter).toHaveBeenCalledBefore(srcSetter);
    expect(element.href.baseVal).toBe(source);
    expect(getContext).not.toHaveBeenCalled();

    image.dispatchEvent(new Event('load'));
    await replacement;

    expect(getContext).toHaveBeenCalledWith('2d', { willReadFrequently: true });
    const canvas = getContext.mock.contexts[0] as HTMLCanvasElement;
    expect(canvas.width).toBe(640);
    expect(canvas.height).toBe(480);
    expect(drawImage).toHaveBeenCalledWith(image, 0, 0);
    expect(toBlob).toHaveBeenCalledWith(expect.any(Function), 'image/png');
    expect(element.href.baseVal).toMatch(/^blob:/);
  });

  it('rejects failed image loads without changing the href', async () => {
    const replacement = replaceFilterImageHrefIfNeeded(element);
    const rejection = expect(replacement).rejects.toBeUndefined();
    image.dispatchEvent(new Event('error'));
    await rejection;
    expect(element.href.baseVal).toBe(source);
  });

  it('preserves the href when no canvas context is available', async () => {
    vi.spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue(null);
    const replacement = replaceFilterImageHrefIfNeeded(element);
    const rejection = expect(replacement).rejects.toThrow();
    image.dispatchEvent(new Event('load'));
    await rejection;
    expect(element.href.baseVal).toBe(source);
  });
});
