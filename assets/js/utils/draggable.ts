import { $$ } from './dom';

let dragSrcEl: HTMLElement | null = null;

function dragStart(event: DragEvent, target: HTMLElement) {
  target.classList.add('dragging');
  dragSrcEl = target;

  if (!event.dataTransfer) return;

  if (event.dataTransfer.items.length === 0) {
    event.dataTransfer.setData('text/plain', '');
  }

  event.dataTransfer.effectAllowed = 'move';
}

function dragOver(event: DragEvent) {
  event.preventDefault();
  if (event.dataTransfer) {
    event.dataTransfer.dropEffect = 'move';
  }
}

function dragEnter(event: DragEvent, target: HTMLElement) {
  target.classList.add('over');
}

function dragLeave(event: DragEvent, target: HTMLElement) {
  target.classList.remove('over');
}

function drop(event: DragEvent, target: HTMLElement) {
  event.preventDefault();

  if (!dragSrcEl) return;

  dragSrcEl.classList.remove('dragging');

  if (dragSrcEl === target) return;

  // divide the target element into two sets of coordinates
  // and determine how to act based on the relative mouse position
  const bbox = target.getBoundingClientRect();
  const detX = bbox.left + bbox.width / 2;

  if (event.clientX < detX) {
    target.insertAdjacentElement('beforebegin', dragSrcEl);
  }
  else {
    target.insertAdjacentElement('afterend', dragSrcEl);
  }
}

function dragEnd(event: DragEvent, target: HTMLElement) {
  clearDragSource();

  if (target.parentNode) {
    $$('.over', target.parentNode).forEach(t => t.classList.remove('over'));
  }
}

function wrapper<E extends Event, T extends Element>(func: (event: E, target: T) => void) {
  return function(event: E) {
    const evtTarget = event.target as EventTarget | Element | null;
    if (evtTarget && 'closest' in evtTarget && typeof evtTarget.closest === 'function') {
      const target: T | null = evtTarget.closest('.drag-container [draggable]');
      if (target) func(event, target);
    }
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

export function clearDragSource() {
  if (!dragSrcEl) return;

  dragSrcEl.classList.remove('dragging');
  dragSrcEl = null;
}
