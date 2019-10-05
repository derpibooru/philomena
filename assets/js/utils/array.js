// http://stackoverflow.com/a/5306832/1726690
function moveElement(array, from, to) {
  array.splice(to, 0, array.splice(from, 1)[0]);
}

function arraysEqual(array1, array2) {
  for (let i = 0; i < array1.length; ++i) {
    if (array1[i] !== array2[i]) return false;
  }
  return true;
}

export { moveElement, arraysEqual };
