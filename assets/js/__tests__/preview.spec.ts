import { fireEvent, waitFor } from '@testing-library/dom';
import { fixEventListeners } from '../../test/fix-event-listeners';
import { $ } from '../utils/dom';

// Ensure mocks do not reference top-level variables (hoisted by Vitest)
vi.mock('../utils/requests', () => ({
  fetchJson: vi.fn(),
}));
vi.mock('../image-expansion', () => ({
  bindImageTarget: vi.fn(),
}));
vi.mock('../imagesclientside', () => ({
  filterNode: vi.fn(),
}));

// Import after mocks so they receive mocked modules
import { setupPreviews } from '../preview';
import { fetchJson } from '../utils/requests';
import { bindImageTarget } from '../image-expansion';
import { filterNode } from '../imagesclientside';

fixEventListeners(document);

function makeBaseDom({ withAnon }: { withAnon?: boolean } = {}) {
  document.body.innerHTML = `
    <a href="#" data-click-tab="preview">Preview</a>
    <a href="#" data-click-tab="write" class="not-selected"></a>
    <textarea class="js-preview-input"></textarea>
    <div class="js-preview-loading hidden"></div>
    <div class="js-preview-idle"></div>
    <div class="js-preview-content"></div>
    ${withAnon ? '<input type="checkbox" class="js-preview-anonymous" />' : ''}
  `;

  const textarea = $<HTMLTextAreaElement>('.js-preview-input')!;
  const previewBtn = $<HTMLAnchorElement>('a[data-click-tab="preview"]')!;
  const writeBtn = $<HTMLAnchorElement>('a[data-click-tab="write"]')!;
  const loading = $<HTMLDivElement>('.js-preview-loading')!;
  const idle = $<HTMLDivElement>('.js-preview-idle')!;
  const content = $<HTMLDivElement>('.js-preview-content')!;
  const anon = $<HTMLInputElement>('.js-preview-anonymous');

  return { textarea, previewBtn, writeBtn, loading, idle, content, anon };
}

function mockSuccessfulPreview(html: string) {
  const response = { ok: true, text: async () => html } as unknown as Response;
  vi.mocked(fetchJson).mockResolvedValue(response);
}

function mockFailedPreview() {
  const response = { ok: false, text: async () => 'IGNORED' } as unknown as Response;
  vi.mocked(fetchJson).mockResolvedValue(response);
}

describe('preview.ts setupPreviews', () => {
  beforeEach(() => {
    vi.mocked(fetchJson).mockReset();
    vi.mocked(bindImageTarget).mockReset();
    vi.mocked(filterNode).mockReset();
    document.body.innerHTML = '';
  });

  it('loads and renders preview, calls helpers, toggles loading', async () => {
    const { textarea, previewBtn, loading, idle, content } = makeBaseDom();
    textarea.value = 'Hello world';

    mockSuccessfulPreview('<p>rendered</p>');

    setupPreviews();

    // click preview
    fireEvent.click(previewBtn);

    // loading shown, idle hidden immediately
    expect(loading).not.toHaveClass('hidden');
    expect(idle).toHaveClass('hidden');

    // wait for async chain
    await waitFor(() => {
      expect(fetchJson).toHaveBeenCalledTimes(1);
      expect(content).toContainHTML('<p>rendered</p>');
      expect(vi.mocked(filterNode)).toHaveBeenCalledWith(content);
      expect(vi.mocked(bindImageTarget)).toHaveBeenCalledWith(content);
      expect(idle).not.toHaveClass('hidden');
      expect(loading).toHaveClass('hidden');
    });

    // data-previewed-text cache should be set
    expect(content.getAttribute('data-previewed-text')).toBe(textarea.value);
  });

  it('caches preview and avoids duplicate fetch', async () => {
    const { textarea, previewBtn, content } = makeBaseDom();
    textarea.value = 'Cache me';

    mockSuccessfulPreview('<p>once</p>');

    setupPreviews();

    fireEvent.click(previewBtn);
    await waitFor(() => expect(fetchJson).toHaveBeenCalledTimes(1));

    // Second click with no changes should not fetch again
    fireEvent.click(previewBtn);
    await new Promise(r => setTimeout(r, 10));
    expect(fetchJson).toHaveBeenCalledTimes(1);

    // Changing textarea should invalidate cache and fetch again
    textarea.value = 'Cache me again';
    fireEvent.click(previewBtn);
    await waitFor(() => expect(fetchJson).toHaveBeenCalledTimes(2));

    // cache attribute should reflect new value
    expect(content.getAttribute('data-previewed-text')).toBe(textarea.value);
  });

  it('passes anonymous flag and updates cache when toggled', async () => {
    const { textarea, previewBtn, anon, content } = makeBaseDom({ withAnon: true });
    textarea.value = 'Anon test';

    mockSuccessfulPreview('<p>a</p>');

    setupPreviews();

    fireEvent.click(previewBtn);
    await waitFor(() => expect(fetchJson).toHaveBeenCalledTimes(1));
    expect(vi.mocked(fetchJson).mock.calls[0][2]).toEqual({ body: 'Anon test', anonymous: false });

    // Click checkbox to toggle from unchecked -> checked (true)
    fireEvent.click(anon!);
    await waitFor(() => expect(fetchJson).toHaveBeenCalledTimes(2));

    const lastIdx = vi.mocked(fetchJson).mock.calls.length - 1;
    const lastCall = vi.mocked(fetchJson).mock.calls[lastIdx];
    expect(lastCall[2]).toEqual({ body: 'Anon test', anonymous: true });

    // cache key includes anon;
    expect(content.getAttribute('data-previewed-text')).toBe(`anon;${textarea.value}`);
  });

  it('handles failed preview by rendering error message', async () => {
    const { textarea, previewBtn, content } = makeBaseDom();
    textarea.value = 'Hi';

    mockFailedPreview();

    setupPreviews();

    fireEvent.click(previewBtn);
    await waitFor(() => expect(content).toContainHTML('Preview failed to load!'));
  });

  it('reply link populates textarea and focuses it', () => {
    const { textarea } = makeBaseDom();
    textarea.value = '';

    // add write tab that should be clicked when replying
    const writeTab = $<HTMLAnchorElement>('a[data-click-tab="write"]')!;
    writeTab.classList.remove('selected');
    const clickSpy = vi.spyOn(writeTab, 'click');

    // add reply link
    const container = document.createElement('div');
    container.innerHTML = `
      <a href="/u/test" class="post-reply" data-author="User" data-post="quote\nmore">
        <span class="inner">reply</span>
      </a>
    `;
    document.body.appendChild(container);

    setupPreviews();

    const inner = $<HTMLSpanElement>('.inner', container)!;
    fireEvent.click(inner);

    expect(textarea.value).toMatch(/\[User\]\(\/u\/test\)\n> quote\n> more\n\n$/);
    expect(clickSpy).toHaveBeenCalled();
    expect(document.activeElement).toBe(textarea);
  });

  it('auto-resizes textarea on change/keyup', () => {
    const { textarea } = makeBaseDom();
    textarea.value = 'text';

    // mock computed style and scroll height
    const styleSpy = vi.spyOn(window, 'getComputedStyle');
    styleSpy.mockImplementation(
      () =>
        ({
          borderTopWidth: '2',
          borderBottomWidth: '3',
          height: '50',
        }) as unknown as CSSStyleDeclaration,
    );
    Object.defineProperty(textarea, 'scrollHeight', { value: 200, configurable: true });

    setupPreviews();

    // setupPreviews will dispatch a change if textarea has value
    expect(parseInt(textarea.style.height || '0', 10)).toBeGreaterThanOrEqual(50);

    // typing increases height
    Object.defineProperty(textarea, 'scrollHeight', { value: 400 });
    fireEvent.keyUp(textarea);
    expect(parseInt(textarea.style.height || '0', 10)).toBeGreaterThanOrEqual(50);

    styleSpy.mockRestore();
  });

  it('does nothing when required elements are missing', () => {
    document.body.innerHTML = `
      <a href="#" data-click-tab="preview">Preview</a>
      <textarea class="js-preview-input"></textarea>
      <!-- no loading/idle/content elements present -->
    `;

    const previewBtn = $<HTMLAnchorElement>('a[data-click-tab="preview"]')!;

    setupPreviews();

    fireEvent.click(previewBtn);
    expect(fetchJson).not.toHaveBeenCalled();
  });

  it('does not update preview when content is hidden and anon is toggled', async () => {
    document.body.innerHTML = `
      <a href="#" data-click-tab="preview">Preview</a>
      <a href="#" data-click-tab="write" class="not-selected"></a>
      <textarea class="js-preview-input"></textarea>
      <div class="js-preview-loading hidden"></div>
      <div class="js-preview-idle"></div>
      <div class="js-preview-content hidden"></div>
      <input type="checkbox" class="js-preview-anonymous" />
    `;

    const textarea = $<HTMLTextAreaElement>('.js-preview-input')!;
    const anon = $<HTMLInputElement>('.js-preview-anonymous')!;
    textarea.value = 'Hidden content test';

    setupPreviews();

    vi.mocked(fetchJson).mockReset();

    // Toggling anon should be ignored due to hidden content
    fireEvent.click(anon);

    // Give time for any async handlers (there should be none)
    await new Promise(r => setTimeout(r, 10));

    expect(fetchJson).not.toHaveBeenCalled();
  });

  it('uses description textarea fallback when input is missing', async () => {
    document.body.innerHTML = `
      <a href="#" data-click-tab="preview">Preview</a>
      <a href="#" data-click-tab="write" class="not-selected"></a>
      <textarea class="js-preview-description"></textarea>
      <div class="js-preview-loading hidden"></div>
      <div class="js-preview-idle"></div>
      <div class="js-preview-content"></div>
    `;

    const desc = $<HTMLTextAreaElement>('.js-preview-description')!;
    const previewBtn = $<HTMLAnchorElement>('a[data-click-tab="preview"]')!;
    desc.value = 'From description';

    mockSuccessfulPreview('<p>desc</p>');

    setupPreviews();

    fireEvent.click(previewBtn);
    await waitFor(() => expect(fetchJson).toHaveBeenCalledTimes(1));

    // Ensure body came from description textarea
    expect(vi.mocked(fetchJson).mock.calls[0][2]).toEqual({ body: 'From description', anonymous: false });
  });

  it('does not click write tab when it is already selected', () => {
    const { textarea } = makeBaseDom();
    textarea.value = '';

    const writeTab = $<HTMLAnchorElement>('a[data-click-tab="write"]')!;
    writeTab.classList.add('selected'); // make it selected so selector :not(.selected) won't match
    const clickSpy = vi.spyOn(writeTab, 'click');

    const container = document.createElement('div');
    container.innerHTML = `
      <a href="/u/test" class="post-reply" data-author="User" data-post="quote">
        <span class="inner">reply</span>
      </a>
    `;
    document.body.appendChild(container);

    setupPreviews();

    const inner = $<HTMLSpanElement>('.inner', container)!;
    fireEvent.click(inner);

    expect(clickSpy).not.toHaveBeenCalled();
  });

  it('reply without quote does not add quote block', () => {
    const { textarea } = makeBaseDom();
    textarea.value = '';

    const writeTab = $<HTMLAnchorElement>('a[data-click-tab="write"]')!;
    writeTab.classList.remove('selected');

    const container = document.createElement('div');
    container.innerHTML = `
      <a href="/u/test" class="post-reply" data-author="User">
        <span class="inner">reply</span>
      </a>
    `;
    document.body.appendChild(container);

    setupPreviews();

    const inner = $<HTMLSpanElement>('.inner', container)!;
    fireEvent.click(inner);

    // Only the user link line and trailing newline
    expect(textarea.value).toMatch(/^\[User\]\(\/u\/test\)\n$/);
  });

  it('resize does not shrink below current height and caps at 1000', () => {
    const { textarea } = makeBaseDom();
    textarea.value = 'text';

    const styleSpy = vi.spyOn(window, 'getComputedStyle');

    // First, large current height with small content -> stays at current height (no shrink)
    styleSpy.mockImplementationOnce(
      () => ({ borderTopWidth: '0', borderBottomWidth: '0', height: '400' }) as unknown as CSSStyleDeclaration,
    );
    Object.defineProperty(textarea, 'scrollHeight', { value: 100, configurable: true });
    setupPreviews();
    fireEvent.keyUp(textarea);
    expect(textarea.style.height).toBe('400px');

    // Then, huge content -> capped at 1000
    styleSpy.mockImplementationOnce(
      () => ({ borderTopWidth: '0', borderBottomWidth: '0', height: '50' }) as unknown as CSSStyleDeclaration,
    );
    Object.defineProperty(textarea, 'scrollHeight', { value: 5000 });
    fireEvent.keyUp(textarea);
    expect(textarea.style.height).toBe('1000px');

    styleSpy.mockRestore();
  });

  it('reply uses empty defaults when data attributes are missing', () => {
    const { textarea } = makeBaseDom();
    textarea.value = '';

    const container = document.createElement('div');
    container.innerHTML = `
      <a class="post-reply">
        <span class="inner">reply</span>
      </a>
    `;
    document.body.appendChild(container);

    setupPreviews();

    const inner = $<HTMLSpanElement>('.inner', container)!;
    fireEvent.click(inner);

    // Falls back to empty author and href, and no quote
    expect(textarea.value).toBe('[]()\n');
  });
});
