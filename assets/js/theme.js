/**
 * Theme setting
 */

function setThemeCookie() {
  if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
    document.cookie = `theme=dark; path=/; max-age=788923800; samesite=lax`;
  } else {
    document.cookie = `theme=light; path=/; max-age=788923800; samesite=lax`;
  }
}

export { setThemeCookie };
