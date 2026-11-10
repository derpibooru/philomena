/**
 * Comments.
 */

import { $ } from './utils/dom';
import { filterNode } from './imagesclientside';
import { fetchHtml } from './utils/requests';
import { timeAgo } from './timeago';
import { assertString, assertType, assertNotNull, assertNullableType } from './utils/assert';
import { delegate, leftClick } from './utils/events';

function handleError(response: Response): Promise<string> | string {
  const errorMessage = '<div>Comment failed to load!</div>';

  if (!response.ok) {
    return errorMessage;
  }
  return response.text();
}

function commentPosted(response: Response) {
  const commentEditTab = $<HTMLAnchorElement>('#js-comment-form a[data-click-tab="write"]');
  const commentEditForm = assertType($('#js-comment-form'), HTMLFormElement);
  const container = document.getElementById('comments')!;
  const requestOk = response.ok;

  commentEditTab?.click();
  commentEditForm.reset();

  if (requestOk) {
    response.text().then(text => {
      if (text.includes('<div class="flash flash--warning">')) {
        window.location.reload();
      } else {
        displayComments(container, text);
      }
    });
  } else {
    window.location.reload();
    window.scrollTo(0, 0); // Error message is displayed at the top of the page (flash)
  }
}

function loadParentPost(event: Event, target: HTMLElement) {
  // Find the comment containing the link that was clicked
  const fullComment = assertType(target.closest('article.block'), HTMLElement);
  // Look for a potential image and comment ID
  const href = assertNotNull(target.getAttribute('href'));
  const commentMatches = /(\w+)#comment_(\w+)$/.exec(href);

  // If the clicked link is already active, just clear the parent comments
  if (target.classList.contains('active_reply_link')) {
    clearParentPost(target, fullComment);
    event.preventDefault();
    return;
  }

  if (commentMatches) {
    // If the regex matched, get the image and comment ID
    const [, imageId, commentId] = commentMatches;

    fetchHtml(`/images/${imageId}/comments/${commentId}`)
      .then(handleError)
      .then(data => {
        clearParentPost(target, fullComment);
        insertParentPost(data, target, fullComment);
      });

    event.preventDefault();
  }
}

function insertParentPost(data: string, clickedLink: HTMLElement, fullComment: HTMLElement) {
  // Add the 'subthread' class to the comment with the clicked link
  fullComment.classList.add('subthread');

  // Parse the HTML into an element so we can decorate it before insertion
  const tpl = document.createElement('template');
  tpl.innerHTML = data.trim();
  const newEl = assertNullableType(tpl.content.firstElementChild, HTMLElement);

  if (!newEl) return;

  // Mark the inserted parent comment
  newEl.classList.add('subthread');
  newEl.classList.add('fetched-comment');

  // Insert parent comment before the full comment
  fullComment.insertAdjacentElement('beforebegin', newEl);

  // Execute timeago on the new comment - it was not present when first run
  timeAgo(newEl.getElementsByTagName('time'));

  // Add class active_reply_link to the clicked link
  clickedLink.classList.add('active_reply_link');

  // Filter images (if any) in the loaded comment
  filterNode(newEl);
}

function clearParentPost(_clickedLink: HTMLElement, fullComment: HTMLElement) {
  // Remove any previous siblings with the class fetched-comment
  let prevEl = fullComment.previousElementSibling;

  while (prevEl && prevEl.classList.contains('fetched-comment')) {
    prevEl.parentNode?.removeChild(prevEl);
    prevEl = fullComment.previousElementSibling;
  }

  // Remove class active_reply_link from all links in the comment
  for (const link of fullComment.getElementsByClassName('active_reply_link')) {
    assertType(link, HTMLElement).classList.remove('active_reply_link');
  }

  // If this full comment isn't a fetched comment, remove the subthread class.
  if (!fullComment.classList.contains('fetched-comment')) {
    fullComment.classList.remove('subthread');
  }
}

function displayComments(container: HTMLElement, commentsHtml: string) {
  container.innerHTML = commentsHtml;

  // Execute timeago on comments
  timeAgo(document.getElementsByTagName('time'));

  // Filter images in the comments
  filterNode(container);
}

function loadComments(target?: Element) {
  const container = document.getElementById('comments')!;
  const href = target?.getAttribute('href');
  const hashMatch = window.location.hash && window.location.hash.match(/#comment_([a-f0-9]+)/i);
  const url = new URL(assertString(container.dataset.currentUrl), window.location.origin);
  // Looking up the page for a linked comment that isn't on the current page.
  const isCommentLookup = !href && Boolean(hashMatch);

  if (href) {
    url.href = `${url.origin}${href}`;
  } else if (hashMatch) {
    url.searchParams.set('comment_id', window.location.hash.substring(9));
  }

  fetchHtml(url.toString())
    .then(response => {
      // The linked comment was deleted or isn't visible to this viewer. Keep the
      // comments already rendered on the page instead of replacing them with an error.
      if (!response.ok && isCommentLookup && container.dataset.loaded) {
        filterNode(container);
        return null;
      }

      return handleError(response);
    })
    .then(data => {
      if (data === null) return;

      displayComments(container, data);

      // Make sure the :target CSS selector applies to the inserted content
      // https://bugs.chromium.org/p/chromium/issues/detail?id=98561
      if (hashMatch) {
        // Force hash reassignment to itself to re-apply :target
        const current = window.location.hash;
        window.location.hash = current;
      }
    });
}

function setupComments() {
  const comments = document.getElementById('comments');
  const hasHash = window.location.hash && window.location.hash.match(/^#comment_([a-f0-9]+)$/i);
  const targetOnPage = hasHash ? Boolean($(window.location.hash)) : true;

  // Fetch comments if we are on a page with element #comments
  if (comments) {
    if (!comments.dataset.loaded || !targetOnPage) {
      // There is no event associated with the initial load, so just call without arguments.
      loadComments();
    } else {
      filterNode(comments);
    }
  }

  // Define clickable elements and the function to execute on click
  delegate(document, 'click', {
    'article[id*="comment"] .communication__body__text a[href]': leftClick((e: Event, link: HTMLElement) => {
      loadParentPost(e, link);
    }),
    '#comments .pagination a[href]': leftClick((e: Event, link: HTMLElement) => {
      loadComments(link);
      e.preventDefault();
    }),
    '#js-refresh-comments': leftClick((e: Event, btn: HTMLElement) => {
      loadComments(btn);
      e.preventDefault();
    }),
  });

  delegate(document, 'fetchcomplete', {
    '#js-comment-form': (e: FetchcompleteEvent) => commentPosted(e.detail),
  });
}

export { setupComments };
