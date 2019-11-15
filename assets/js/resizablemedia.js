let mediaContainers;

/* Hardcoded dimensions of thumb boxes; at mediaLargeMinSize, large box becomes a small one (font size gets diminished).
 * At minimum width, the large box still has four digit fave/score numbers and five digit comment number fitting in a single row
 * (small box may lose the number of comments in a hidden overflow) */
const mediaLargeMaxSize = 250, mediaLargeMinSize = 190, mediaSmallMaxSize = 156, mediaSmallMinSize = 140;
/* Margin between thumbs (6) + borders (2) + 1 extra px to correct rounding errors */
const mediaBoxOffset = 9;

export function processResizableMedia() {
  [].slice.call(mediaContainers).forEach(container => {
    const containerHasLargeBoxes = container.querySelector('.media-box__content--large') !== null,
          containerWidth = container.offsetWidth - 14; /* subtract container padding */

    /* If at least three large boxes fit in a single row, we do not downsize them to small ones.
     * This ensures that desktop users get less boxes in a row, but with bigger images inside. */
    const largeBoxesFitting = Math.floor(containerWidth / (mediaLargeMinSize + mediaBoxOffset));
    if (largeBoxesFitting >= 3) {
      /* At the same time, we don't want small boxes to be upscaled. */
      if (containerHasLargeBoxes) {
        /* Larger boxes are preferred to more items in a row */
        setMediaSize(container, containerWidth, mediaLargeMinSize, mediaLargeMaxSize);
      }
    }
    /* Mobile users, on the other hand, should get as many boxes in a row as possible */
    else {
      setMediaSize(container, containerWidth, mediaSmallMinSize, mediaSmallMaxSize);
    }
  });
}

function applyMediaSize(container, size) {
  const mediaItems = container.querySelectorAll('.media-box__content');

  [].slice.call(mediaItems).forEach(item => {
    item.style.width = `${size}px`;
    item.style.height = `${size}px`;

    const header = item.parentNode.firstElementChild;
    // TODO: Make this proper and/or rethink this entire croc of bullshit
    item.parentNode.style.width = `${size}px`;
    /* When the large box has width less than mediaLargeMinSize, the header gets wrapped and occupies more than one line.
     * To prevent that, we add a class that diminishes its padding and font size. */
    if (size < mediaLargeMinSize) {
      header.classList.add('media-box__header--small');
    }
    else {
      header.classList.remove('media-box__header--small');
    }
  });
}

function setMediaSize(container, containerWidth, minMediaSize, maxMediaSize) {
  const maxThumbsFitting = Math.floor(containerWidth / (minMediaSize + mediaBoxOffset)),
        minThumbsFitting = Math.floor(containerWidth / (maxMediaSize + mediaBoxOffset)),
        fitThumbs = Math.round((maxThumbsFitting + minThumbsFitting) / 2),
        thumbSize = Math.max(Math.floor(containerWidth / fitThumbs) - 9, minMediaSize);

  applyMediaSize(container, thumbSize);
}

function initializeListener() {
  mediaContainers = document.querySelectorAll('.js-resizable-media-container');

  if (mediaContainers.length > 0) {
    window.addEventListener('resize', processResizableMedia);
    processResizableMedia();
  }
}

export { initializeListener };
