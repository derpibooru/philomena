import { fireEvent, waitFor } from '@testing-library/dom';
import { fixEventListeners } from '../../test/fix-event-listeners';
import { mockLocationReload } from '../../test/mock-location-reload';
import { $ } from '../utils/dom';

vi.mock('../utils/requests', () => ({
  fetchHtml: vi.fn(),
}));

vi.mock('../imagesclientside', () => ({
  filterNode: vi.fn(),
}));

vi.mock('../timeago', () => ({
  timeAgo: vi.fn(),
}));

import { fetchHtml } from '../utils/requests';
import { filterNode } from '../imagesclientside';
import { timeAgo } from '../timeago';
import { setupComments } from '../comment';

mockLocationReload();

fixEventListeners(document);

function mockCommentsDom({ loaded = '', withForm = true } = {}) {
  document.body.innerHTML = `
    <div id="comments" data-current-url="/comments${loaded}"></div>
    ${
      withForm
        ? `
      <form id="js-comment-form">
        <a href="#" data-click-tab="write">Write</a>
      </form>
    `
        : ''
    }
  `;
}

function mockFetchHtml(html: string, ok = true) {
  vi.mocked(fetchHtml).mockResolvedValue({ ok, text: async () => html } as unknown as Response);
}

describe('comment.ts setupComments', () => {
  beforeEach(() => {
    vi.mocked(fetchHtml).mockReset();
    vi.mocked(filterNode).mockReset();
    vi.mocked(timeAgo).mockReset();
    // Provide a default resolved value to avoid unhandled promise errors in incidental calls
    vi.mocked(fetchHtml).mockResolvedValue({ ok: true, text: async () => '' } as unknown as Response);
    document.body.innerHTML = '';
    window.location.hash = '';
  });

  it('does nothing if comments not on page', () => {
    expect(() => setupComments()).not.toThrow();
  });

  it('initially loads comments if not loaded', async () => {
    mockCommentsDom({ loaded: 'false' });
    mockFetchHtml('<div>loaded</div>');

    setupComments();

    await waitFor(() => {
      expect(fetchHtml).toHaveBeenCalledTimes(1);
      expect($<HTMLDivElement>('#comments')!).toContainHTML('<div>loaded</div>');
      expect(timeAgo).toHaveBeenCalled();
      expect(filterNode).toHaveBeenCalled();
    });
  });

  it('filters existing comments when already loaded', () => {
    mockCommentsDom({ loaded: 'loaded=true' });
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';

    setupComments();

    expect(filterNode).toHaveBeenCalledWith(comments);
  });

  it('clears fetched parent when clicking active link', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';
    comments.innerHTML = `
       <article class="block fetched-comment"></article>
      <article class="block" id="comment_1">
         <div class="communication__body__text">
           <a class="active_reply_link" href="/123#comment_456">parent</a>
         </div>
       </article>
     `;

    setupComments();

    const link = $<HTMLAnchorElement>('a.active_reply_link')!;
    fireEvent.click(link);

    // fetched-comment should be removed (sibling before full comment)
    expect($('.fetched-comment', comments)).toBeNull();
  });

  it('handles nested comment subthreads', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';
    comments.innerHTML = `
      <article class="block fetched-comment subthread" id="comment_1"></article>
      <article class="block fetched-comment subthread" id="comment_2">
        <div class="communication__body__text">
          <a class="active_reply_link" href="/123#comment_456">parent</a>
        </div>
      </article>
      <article class="block subthread" id="comment_3"></article>
    `;

    setupComments();

    const link = $<HTMLAnchorElement>('a.active_reply_link')!;
    fireEvent.click(link);

    // fetched-comment should be removed (siblings before latest comment)
    expect($('.fetched-comment', comments)!.id).toEqual('comment_2');
  });

  it('handles comment post completion via fetchcomplete event', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;

    mockFetchHtml('<div>after post</div>');

    setupComments();

    const form = $<HTMLFormElement>('#js-comment-form')!;
    const writeTab = $<HTMLAnchorElement>('a[data-click-tab="write"]')!;
    const clickSpy = vi.spyOn(writeTab, 'click');

    const event = new CustomEvent('fetchcomplete', {
      detail: { ok: true, text: async () => '<div>after post</div>' },
      bubbles: true,
    });
    Object.defineProperty(event, 'target', { value: form });
    document.dispatchEvent(event);

    await waitFor(() => {
      expect(clickSpy).toHaveBeenCalled();
      expect(comments).toContainHTML('<div>after post</div>');
    });
  });

  it('reloads page on server warning after comment post', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';

    const reloadSpy = vi.spyOn(window.location, 'reload');

    setupComments();

    const form = $<HTMLFormElement>('#js-comment-form')!;
    const event = new CustomEvent('fetchcomplete', {
      detail: { ok: true, text: async () => '<div class="flash flash--warning">warn</div>' },
      bubbles: true,
    });
    Object.defineProperty(event, 'target', { value: form });
    document.dispatchEvent(event);

    await waitFor(() => expect(reloadSpy).toHaveBeenCalled());
  });

  it('reloads and scrolls on failed comment post', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';

    const reloadSpy = vi.spyOn(window.location, 'reload');
    const scrollSpy = vi.spyOn(window, 'scrollTo');

    setupComments();

    const form = $<HTMLFormElement>('#js-comment-form')!;
    const event = new CustomEvent('fetchcomplete', {
      detail: { ok: false, text: async () => '' },
      bubbles: true,
    });
    Object.defineProperty(event, 'target', { value: form });
    document.dispatchEvent(event);

    await waitFor(() => {
      expect(reloadSpy).toHaveBeenCalled();
      expect(scrollSpy).toHaveBeenCalledWith(0, 0);
    });
  });

  it('loads comments via pagination click with hash handling', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.innerHTML = `
      <div id="c1"></div>
      <div class="pagination"><a href="/comments?page=2">next</a></div>
    `;

    window.location.hash = '#comment_abc';

    mockFetchHtml('<div>page2</div>');

    setupComments();

    const link = $<HTMLAnchorElement>('.pagination a')!;
    const dispatched = fireEvent.click(link, { button: 0 });
    // default should be prevented by the delegated handler
    expect(dispatched).toBe(false);

    await waitFor(() => {
      expect(fetchHtml).toHaveBeenCalledWith('http://localhost:3000/comments?page=2');
      expect($<HTMLDivElement>('#comments')!).toContainHTML('page2');
    });
  });

  it('displays error message when initial load fails (handleError path)', async () => {
    mockCommentsDom({ loaded: '' });
    // Simulate server returning non-ok Response
    mockFetchHtml('<div>ignored</div>', false);

    setupComments();

    await waitFor(() => {
      const comments = $<HTMLDivElement>('#comments')!;
      expect(comments).toContainHTML('Comment failed to load!');
    });
  });

  it('ignores fetchcomplete from other targets', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';

    setupComments();

    // Dispatch fetchcomplete on a different target element
    const other = document.createElement('div');
    other.id = 'not-the-form';
    const event = new CustomEvent('fetchcomplete', { detail: { ok: true }, bubbles: true });
    Object.defineProperty(event, 'target', { value: other });
    document.dispatchEvent(event);

    // Nothing should change; no errors thrown and no fetchHtml invoked
    await new Promise(r => setTimeout(r, 10));
    expect(fetchHtml).not.toHaveBeenCalled();
  });

  it('marks reply link active and decorates inserted parent comment', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';
    comments.innerHTML = `
      <article class="block" id="comment_1">
        <div class="communication__body__text">
          <a id="reply" href="/999#comment_111">parent</a>
        </div>
      </article>
    `;

    mockFetchHtml('<article class="block"><time></time></article>');

    setupComments();

    const link = $<HTMLAnchorElement>('#reply')!;
    fireEvent.click(link, { button: 0 });

    await waitFor(() => {
      // inserted parent is marked as fetched and subthread
      const fetched = $<HTMLElement>('article.block.fetched-comment', comments);
      expect(fetched).toBeTruthy();
      expect(fetched!).toHaveClass('subthread');
      // clicked link becomes active
      expect(link).toHaveClass('active_reply_link');
      // helpers called
      expect(timeAgo).toHaveBeenCalled();
      expect(filterNode).toHaveBeenCalled();
    });
  });

  it('refresh button loads comments and prevents default', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;
    comments.innerHTML = `
      <a id="js-refresh-comments">refresh</a>
    `;

    mockFetchHtml('<div>refreshed</div>');

    setupComments();

    const btn = $<HTMLAnchorElement>('#js-refresh-comments')!;
    const dispatched = fireEvent.click(btn, { button: 0 });
    expect(dispatched).toBe(false);

    await waitFor(() => {
      expect(fetchHtml).toHaveBeenCalled();
      expect($<HTMLDivElement>('#comments')!).toContainHTML('refreshed');
    });
  });

  it('handles fetchcomplete when write tab link is missing', async () => {
    mockCommentsDom();
    const comments = $<HTMLDivElement>('#comments')!;

    setupComments();

    // Remove the write tab link to cover the optional chaining false branch
    const writeLink = $<HTMLAnchorElement>('a[data-click-tab="write"]');
    writeLink?.parentElement?.removeChild(writeLink);
    mockFetchHtml('<div>posted</div>');

    setupComments();

    const form = $<HTMLFormElement>('#js-comment-form')!;
    const event = new CustomEvent('fetchcomplete', {
      detail: { ok: true, text: async () => '<div>posted</div>' },
      bubbles: true,
    });
    Object.defineProperty(event, 'target', { value: form });
    document.dispatchEvent(event);

    await waitFor(() => {
      expect(comments).toContainHTML('<div>posted</div>');
    });
  });

  it('keeps rendered comments when a linked comment no longer exists', async () => {
    mockCommentsDom({ loaded: '' });
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';
    comments.innerHTML = '<div>no comments yet</div>';
    window.location.hash = '#comment_123';
    mockFetchHtml('Not found', false);

    setupComments();

    await waitFor(() => {
      expect(fetchHtml).toHaveBeenCalledWith('http://localhost:3000/comments?comment_id=123');
      expect(filterNode).toHaveBeenCalledWith(comments);
    });
    expect(comments).toContainHTML('no comments yet');
    expect(comments).not.toContainHTML('Comment failed to load!');
  });

  it('still shows the error when refreshing a rendered page fails', async () => {
    mockCommentsDom({ loaded: '' });
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';
    comments.innerHTML = '<a id="js-refresh-comments" href="/comments">Refresh</a>';
    window.location.hash = '#comment_123';

    setupComments();
    mockFetchHtml('Server error', false);
    fireEvent.click($<HTMLAnchorElement>('#js-refresh-comments')!);

    await waitFor(() => {
      expect(comments).toContainHTML('Comment failed to load!');
    });
  });

  it('initial load with hash uses comment_id param', async () => {
    mockCommentsDom({ loaded: '' });
    window.location.hash = '#comment_AbC123';
    mockFetchHtml('<div>hash-load</div>');

    setupComments();

    await waitFor(() => {
      expect(fetchHtml).toHaveBeenCalledWith('http://localhost:3000/comments?comment_id=AbC123');
      expect($<HTMLDivElement>('#comments')!).toContainHTML('hash-load');
    });
  });

  it('ignores reply link when href does not match comment pattern (no preventDefault, no fetch)', async () => {
    mockCommentsDom({ loaded: 'loaded=true' });
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';
    comments.innerHTML = `
      <article class="block" id="comment_1">
        <div class="communication__body__text">
          <a id="bad" href="/123#no_comment_marker">bad</a>
        </div>
      </article>
    `;

    setupComments();
    vi.mocked(fetchHtml).mockClear();

    const link = $<HTMLAnchorElement>('#bad')!;
    const dispatched = fireEvent.click(link, { button: 0 });

    expect(dispatched).toBe(true);
    expect(fetchHtml).not.toHaveBeenCalled();
  });

  it('loads parent comment and prevents default when reply link has comment id', async () => {
    mockCommentsDom({ loaded: 'loaded=true' });
    const comments = $<HTMLDivElement>('#comments')!;
    comments.dataset.loaded = 'true';
    comments.innerHTML = `
      <article class="block" id="comment_1">
        <div class="communication__body__text">
          <a id="good" href="/123#comment_456">parent</a>
        </div>
      </article>
    `;

    mockFetchHtml('<article class="block fetched-comment"><time></time></article>');

    setupComments();
    vi.mocked(fetchHtml).mockClear();

    const link = $<HTMLAnchorElement>('#good')!;
    const dispatched = fireEvent.click(link, { button: 0 });
    expect(dispatched).toBe(false);

    await waitFor(() => {
      expect(fetchHtml).toHaveBeenCalledWith('/images/123/comments/456');
      expect($('.fetched-comment', comments)).toBeTruthy();
    });
  });
});
