import { $$ } from './dom';

let dragSrcEl;

function dragStart(event, target) {
  target.classList.add('dragging');
  dragSrcEl = target;

  if (event.dataTransfer.items.length === 0) {
    event.dataTransfer.setData('text/plain', '');
  }

  event.dataTransfer.effectAllowed = 'move';
}

function dragOver(event) {
  event.preventDefault();
  event.dataTransfer.dropEffect = 'move';
}

function dragEnter(event, target) {
  target.classList.add('over');
}

function dragLeave(event, target) {
  target.classList.remove('over');
}

function drop(event, target) {
  event.preventDefault();

  dragSrcEl.classList.remove('dragging');

  if (dragSrcEl === target) return;

  // divide the target element into two sets of coordinates
  // and determine how to act based on the relative mouse positioin
  const bbox = target.getBoundingClientRect();
  const detX = bbox.left + (bbox.width / 2);

  if (event.clientX < detX) {
    target.insertAdjacentElement('beforebegin', dragSrcEl);
  }
  else {
    target.insertAdjacentElement('afterend', dragSrcEl);
  }
}

function dragEnd(event, target) {
  dragSrcEl.classList.remove('dragging');

  $$('.over', target.parentNode).forEach(t => t.classList.remove('over'));
}

function wrapper(func) {
  return function(event) {
    if (!event.target.closest) return;
    const target = event.target.closest('.drag-container [draggable]');
    if (target) func(event, target);
  };
}

export function initDraggables() {
  document.addEventListener('dragstart', wrapper(dragStart));
  document.addEventListener('dragover', wrapper(dragOver));
  document.addEventListener('dragenter', wrapper(dragEnter));
  document.addEventListener('dragleave', wrapper(dragLeave));
  document.addEventListener('dragend', wrapper(dragEnd));
  document.addEventListener('drop', wrapper(drop));
}
