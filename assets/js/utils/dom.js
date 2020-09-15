/**
 * DOM Utils
 */

function $(selector, context = document) { // Get the first matching element
  const element = context.querySelector(selector);

  return element || null;
}

function $$(selector, context = document) { // Get every matching element as an array
  const elements = context.querySelectorAll(selector);

  return [].slice.call(elements);
}

function showEl(...elements) {
  [].concat(...elements).forEach(el => el.classList.remove('hidden'));
}

function hideEl(...elements) {
  [].concat(...elements).forEach(el => el.classList.add('hidden'));
}

function toggleEl(...elements) {
  [].concat(...elements).forEach(el => el.classList.toggle('hidden'));
}

function clearEl(...elements) {
  [].concat(...elements).forEach(el => { while (el.firstChild) el.removeChild(el.firstChild); });
}

function removeEl(...elements) {
  [].concat(...elements).forEach(el => el.parentNode.removeChild(el));
}

function makeEl(tag, attr = {}) {
  const el = document.createElement(tag);
  for (const prop in attr) el[prop] = attr[prop];
  return el;
}

function insertBefore(existingElement, newElement) {
  existingElement.parentNode.insertBefore(newElement, existingElement);
}

function onLeftClick(callback, context = document) {
  context.addEventListener('click', event => {
    if (event.button === 0) callback(event);
  });
}

function whenReady(callback) { // Execute a function when the DOM is ready
  if (document.readyState !== 'loading') callback();
  else document.addEventListener('DOMContentLoaded', callback);
}

function escapeHtml(html) {
  return html.replace(/&/g, '&amp;')
    .replace(/>/g, '&gt;')
    .replace(/</g, '&lt;')
    .replace(/"/g, '&quot;');
}

function escapeCss(css) {
  return css.replace(/\\/g, '\\\\')
    .replace(/"/g, '\\"');
}

function findFirstTextNode(of) {
  return Array.prototype.filter.call(of.childNodes, el => el.nodeType === Node.TEXT_NODE)[0];
}

export { $, $$, showEl, hideEl, toggleEl, clearEl, removeEl, makeEl, insertBefore, onLeftClick, whenReady, escapeHtml, escapeCss, findFirstTextNode };
