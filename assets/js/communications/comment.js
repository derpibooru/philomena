import { $ } from '../utils/dom';

function showOwnedComments() {
  const editableComments = $('.js-editable-comments');
  const editableCommentIds = editableComments && JSON.parse(editableComments.dataset.editable);

  if (editableCommentIds) editableCommentIds.forEach(id => $(`#comment_${id} .owner-options`).classList.remove('hidden'));
}

export { showOwnedComments };
