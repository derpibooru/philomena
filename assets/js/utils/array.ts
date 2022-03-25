// http://stackoverflow.com/a/5306832/1726690
export function moveElement<Items>(array: Items[], from: number, to: number): void {
  array.splice(to, 0, array.splice(from, 1)[0]);
}

export function arraysEqual(array1: unknown[], array2: unknown[]): boolean {
  if (array1.length !== array2.length) return false;

  return array1.every((item, index) => item === array2[index]);
}
