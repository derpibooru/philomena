/**
 * Game progress banner
 */

import { $ } from './utils/dom';

export function setupGameProgress() {
  const ticker = $<HTMLElement>('.game__progress_ticker');

  if (ticker) {
    ticker.style.left = `${ticker.dataset.percentage}%`;
  }
}
