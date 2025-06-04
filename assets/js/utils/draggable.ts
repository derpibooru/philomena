import { $$ } from './dom';
import { delegate } from './events';

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

function dragEnter(_event: DragEvent, target: HTMLElement) {
  target.classList.add('over');
}

function dragLeave(_event: DragEvent, target: HTMLElement) {
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
  } else {
    target.insertAdjacentElement('afterend', dragSrcEl);
  }
}

function dragEnd(_event: DragEvent, target: HTMLElement) {
  clearDragSource();

  if (target.parentNode) {
    $$('.over', target.parentNode).forEach(t => t.classList.remove('over'));
  }
}

export function initDraggables() {
  const draggableSelector = '.drag-container [draggable]';
  delegate(document, 'dragstart', { [draggableSelector]: dragStart });
  delegate(document, 'dragover', { [draggableSelector]: dragOver });
  delegate(document, 'dragenter', { [draggableSelector]: dragEnter });
  delegate(document, 'dragleave', { [draggableSelector]: dragLeave });
  delegate(document, 'dragend', { [draggableSelector]: dragEnd });
  delegate(document, 'drop', { [draggableSelector]: drop });
}

export function clearDragSource() {
  if (!dragSrcEl) return;

  dragSrcEl.classList.remove('dragging');
  dragSrcEl = null;
}
