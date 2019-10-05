import { $ } from '../utils/dom';

function showOwnedPosts() {
  const editablePost = $('.js-editable-posts');
  const editablePostIds = editablePost && JSON.parse(editablePost.dataset.editable);

  if (editablePostIds) editablePostIds.forEach(id => $(`#post_${id} .owner-options`).classList.remove('hidden'));
}

export { showOwnedPosts };
