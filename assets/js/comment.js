/**
 * Comments.
 */

import { $ } from './utils/dom';
import { filterNode } from './imagesclientside';
import { fetchHtml } from './utils/requests';
import { timeAgo } from './timeago';

function handleError(response) {
  const errorMessage = '<div>Comment failed to load!</div>';

  if (!response.ok) {
    return errorMessage;
  }
  return response.text();
}

function commentPosted(response) {
  const commentEditTab = $('#js-comment-form a[data-click-tab="write"]'),
    commentEditForm = $('#js-comment-form'),
    container = document.getElementById('comments'),
    requestOk = response.ok;

  commentEditTab.click();
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

function loadParentPost(event) {
  const clickedLink = event.target,
    // Find the comment containing the link that was clicked
    fullComment = clickedLink.closest('article.block'),
    // Look for a potential image and comment ID
    commentMatches = /(\w+)#comment_(\w+)$/.exec(clickedLink.getAttribute('href'));

  // If the clicked link is already active, just clear the parent comments
  if (clickedLink.classList.contains('active_reply_link')) {
    clearParentPost(clickedLink, fullComment);

    return true;
  }

  if (commentMatches) {
    // If the regex matched, get the image and comment ID
    const [, imageId, commentId] = commentMatches;

    fetchHtml(`/images/${imageId}/comments/${commentId}`)
      .then(handleError)
      .then(data => {
        clearParentPost(clickedLink, fullComment);
        insertParentPost(data, clickedLink, fullComment);
      });

    return true;
  }
}

function insertParentPost(data, clickedLink, fullComment) {
  // Add the 'subthread' class to the comment with the clicked link
  fullComment.classList.add('subthread');

  // Insert parent comment
  fullComment.insertAdjacentHTML('beforebegin', data);

  // Add class subthread and fetched-comment - use separate add()-methods to support IE11
  fullComment.previousSibling.classList.add('subthread');
  fullComment.previousSibling.classList.add('fetched-comment');

  // Execute timeago on the new comment - it was not present when first run
  timeAgo(fullComment.previousSibling.getElementsByTagName('time'));

  // Add class active_reply_link to the clicked link
  clickedLink.classList.add('active_reply_link');

  // Filter images (if any) in the loaded comment
  filterNode(fullComment.previousSibling);
}

function clearParentPost(_clickedLink, fullComment) {
  // Remove any previous siblings with the class fetched-comment
  while (fullComment.previousSibling && fullComment.previousSibling.classList.contains('fetched-comment')) {
    fullComment.previousSibling.parentNode.removeChild(fullComment.previousSibling);
  }

  // Remove class active_reply_link from all links in the comment
  [].slice.call(fullComment.getElementsByClassName('active_reply_link')).forEach(link => {
    link.classList.remove('active_reply_link');
  });

  // If this full comment isn't a fetched comment, remove the subthread class.
  if (!fullComment.classList.contains('fetched-comment')) {
    fullComment.classList.remove('subthread');
  }
}

function displayComments(container, commentsHtml) {
  container.innerHTML = commentsHtml;

  // Execute timeago on comments
  timeAgo(document.getElementsByTagName('time'));

  // Filter images in the comments
  filterNode(container);
}

function loadComments(event) {
  const container = document.getElementById('comments'),
    hasHref = event.target && event.target.getAttribute('href'),
    hasHash = window.location.hash && window.location.hash.match(/#comment_([a-f0-9]+)/),
    getURL =
      hasHref ||
      (hasHash
        ? `${container.dataset.currentUrl}?comment_id=${window.location.hash.substring(9, window.location.hash.length)}`
        : container.dataset.currentUrl);

  fetchHtml(getURL)
    .then(handleError)
    .then(data => {
      displayComments(container, data);

      // Make sure the :target CSS selector applies to the inserted content
      // https://bugs.chromium.org/p/chromium/issues/detail?id=98561
      if (hasHash) {
        // eslint-disable-next-line
        window.location = window.location;
      }
    });

  return true;
}

function setupComments() {
  const comments = document.getElementById('comments'),
    hasHash = window.location.hash && window.location.hash.match(/^#comment_([a-f0-9]+)$/),
    targetOnPage = hasHash ? Boolean($(window.location.hash)) : true;

  // Load comments over AJAX if we are on a page with element #comments
  if (comments) {
    if (!comments.dataset.loaded || !targetOnPage) {
      // There is no event associated with the initial load, so use false
      loadComments(false);
    } else {
      filterNode(comments);
    }
  }

  // Define clickable elements and the function to execute on click
  const targets = {
    'article[id*="comment"] .communication__body__text a[href]': loadParentPost,
    '#comments .pagination a[href]': loadComments,
    '#js-refresh-comments': loadComments,
  };

  document.addEventListener('click', event => {
    if (event.button === 0) {
      // Left-click only
      for (const target in targets) {
        if (event.target && event.target.closest(target)) {
          if (targets[target](event)) event.preventDefault();
        }
      }
    }
  });

  document.addEventListener('fetchcomplete', event => {
    if (event.target.id === 'js-comment-form') commentPosted(event.detail);
  });
}

export { setupComments };
