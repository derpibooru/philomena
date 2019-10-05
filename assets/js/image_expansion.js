import { clearEl } from './utils/dom';
import store from './utils/store';

const imageVersions = {
  // [width, height]
  small: [320, 240],
  medium: [800, 600],
  large: [1280, 1024]
};

/**
 * Picks the appropriate image version for a given width and height
 * of the viewport and the image dimensions.
 */
function selectVersion(imageWidth, imageHeight) {
  let viewWidth = document.documentElement.clientWidth,
      viewHeight = document.documentElement.clientHeight;

  // load hires if that's what you asked for
  if (store.get('serve_hidpi')) {
    viewWidth *= window.devicePixelRatio || 1;
    viewHeight *= window.devicePixelRatio || 1;
  }

  if (viewWidth > 1024 && imageHeight > 1024 && imageHeight > 2.5 * imageWidth) {
    // Treat as comic-sized dimensions..
    return 'tall';
  }

  // Find a version that is larger than the view in one/both axes
  // .find() is not supported in older browsers, using a loop
  for (let i = 0, versions = Object.keys(imageVersions); i < versions.length; ++i) {
    const version = versions[i],
          dimensions = imageVersions[version],
          versionWidth = Math.min(imageWidth, dimensions[0]),
          versionHeight = Math.min(imageHeight, dimensions[1]);
    if (versionWidth > viewWidth || versionHeight > viewHeight) {
      return version;
    }
  }

  // If the view is larger than any available version, display the original image
  return 'full';
}

/**
 * Given a target container element, chooses and scales an image
 * to an appropriate dimension.
 */
function pickAndResize(elem) {
  const imageWidth = parseInt(elem.getAttribute('data-width'), 10),
        imageHeight = parseInt(elem.getAttribute('data-height'), 10),
        scaled = elem.getAttribute('data-scaled'),
        uris = JSON.parse(elem.getAttribute('data-uris'));
  let version = 'full';

  if (scaled === 'true') {
    version = selectVersion(imageWidth, imageHeight);
  }

  const uri = uris[version];
  let imageFormat = /\.(\w+?)$/.exec(uri)[1];

  if (version === 'full' && store.get('serve_webm') && Boolean(uris.mp4)) {
    imageFormat = 'mp4';
  }

  // Check if we need to change to avoid flickering
  if (imageFormat === 'mp4' || imageFormat === 'webm') {
    for (const sourceEl of elem.querySelectorAll('video source')) {
      if (sourceEl.src.endsWith(uri) || (imageFormat === 'mp4' && sourceEl.src.endsWith(uris.mp4))) return;
    }

    // Scrub out the target element.
    clearEl(elem);
  }

  if (imageFormat === 'mp4') {
    elem.classList.add('full-height');
    elem.insertAdjacentHTML('afterbegin',
      `<video controls autoplay loop muted playsinline preload="auto" id="image-display"
           width="${imageWidth}" height="${imageHeight}">
        <source src="${uris.mp4}" type="video/mp4">
        <source src="${uris.webm}" type="video/webm">
        <p class="block block--fixed block--warning">
          Your browser supports neither MP4/H264 nor
          WebM/VP8! Please update it to the latest version.
        </p>
       </video>`
    );
  }
  else if (imageFormat === 'webm') {
    elem.insertAdjacentHTML('afterbegin',
      `<video controls autoplay loop muted playsinline id="image-display">
        <source src="${uri}" type="video/webm">
        <source src="${uri.replace(/webm$/, 'mp4')}" type="video/mp4">
        <p class="block block--fixed block--warning">
          Your browser supports neither MP4/H264 nor
          WebM/VP8! Please update it to the latest version.
        </p>
       </video>`
    );
    const video = elem.querySelector('video');
    if (scaled === 'true') {
      video.className = 'image-scaled';
    }
    else if (scaled === 'partscaled') {
      video.className = 'image-partscaled';
    }
  }
  else {
    let image;
    if (scaled === 'true') {
      image = `<picture><img id="image-display" src="${uri}" class="image-scaled"></picture>`;
    }
    else if (scaled === 'partscaled') {
      image = `<picture><img id="image-display" src="${uri}" class="image-partscaled"></picture>`;
    }
    else {
      image = `<picture><img id="image-display" src="${uri}" width="${imageWidth}" height="${imageHeight}"></picture>`;
    }
    if (elem.innerHTML === image) return;

    clearEl(elem);
    elem.insertAdjacentHTML('afterbegin', image);
  }
}

/**
 * Bind an event to an image container for updating an image on
 * click/tap.
 */
function bindImageForClick(target) {
  target.addEventListener('click', () => {
    if (target.getAttribute('data-scaled') === 'true') {
      target.setAttribute('data-scaled', 'partscaled');
    }
    else if (target.getAttribute('data-scaled') === 'partscaled') {
      target.setAttribute('data-scaled', 'false');
    }
    else {
      target.setAttribute('data-scaled', 'true');
    }

    pickAndResize(target);
  });
}

function bindImageTarget() {
  const target = document.getElementById('image_target');
  if (target) {
    pickAndResize(target);
    bindImageForClick(target);
    window.addEventListener('resize', () => {
      pickAndResize(target);
    });
  }
}

export { bindImageTarget };
