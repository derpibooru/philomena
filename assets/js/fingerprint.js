/**
 * Fingerprints
 */

// http://stackoverflow.com/a/34842797
function hashCode(str) {
  return str.split('').reduce((prevHash, currVal) =>
    ((prevHash << 5) - prevHash) + currVal.charCodeAt(0), 0) >>> 0;
}

function createFingerprint() {
  const prints = [
    navigator.userAgent,
    navigator.cpuClass,
    navigator.oscpu,
    navigator.platform,

    navigator.browserLanguage,
    navigator.language,
    navigator.systemLanguage,
    navigator.userLanguage,

    screen.availLeft,
    screen.availTop,
    screen.availWidth,
    screen.height,
    screen.width,

    window.devicePixelRatio,
    new Date().getTimezoneOffset(),
  ];

  return hashCode(prints.join(''));
}

function setFingerprintCookie() {
  let fingerprint;

  // The prepended 'c' acts as a crude versioning mechanism.
  try {
    fingerprint = `c${createFingerprint()}`;
  }
  // If fingerprinting fails, use fakeprint "c1836832948" as a last resort.
  catch (err) {
    fingerprint = 'c1836832948';
  }

  document.cookie = `_ses=${fingerprint}; path=/`;
}

export { setFingerprintCookie };
