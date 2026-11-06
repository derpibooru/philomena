import { setupDupeReports } from '../duplicate-reports';
import { needsChromiumJpegNormalization, replaceFilterImageHrefIfNeeded } from '../utils/browser-workarounds';
import { fixEventListeners } from '../../test/fix-event-listeners';
import { assertNotNull } from '../utils/assert';
import { $ } from '../utils/dom';
import { fireEvent } from '@testing-library/dom';
import { MockInstance } from 'vitest';

vi.mock('../utils/browser-workarounds');
fixEventListeners(document);

afterEach(() => {
  document.body.innerHTML = '';
  vi.resetAllMocks();
});

it.each([true, false])('normalizes both difference filter images only for Chromium: %s', chromium => {
  document.body.innerHTML = `
    <svg><filter><feImage id="source"/><feImage id="target"/></filter></svg>
    <svg><image id="source"/><image id="target"/></svg>`;
  vi.mocked(needsChromiumJpegNormalization).mockReturnValue(chromium);

  setupDupeReports();

  expect(needsChromiumJpegNormalization).toHaveBeenCalledOnce();
  const expectedCalls = chromium
    ? [[document.querySelector('feImage#source')], [document.querySelector('feImage#target')]]
    : [];
  expect(vi.mocked(replaceFilterImageHrefIfNeeded).mock.calls).toEqual(expectedCalls);
});

it.each(['', '<feImage id="source"/>', '<feImage id="target"/>'])(
  'skips normalization without a complete filter pair: %s',
  markup => {
    document.body.innerHTML = `<svg><filter>${markup}</filter></svg>`;
    setupDupeReports();
    expect(needsChromiumJpegNormalization).not.toHaveBeenCalled();
    expect(replaceFilterImageHrefIfNeeded).not.toHaveBeenCalled();
  },
);

describe('key bindings', () => {
  let swipeClick: MockInstance;

  beforeEach(() => {
    document.body.innerHTML = `
      <button class="onion-skin__button"></button>
      <button class="onion-skin__button"></button>
      <button class="comparison--navigation__button"></button>
      <button class="comparison--navigation__button"></button>
      <button class="comparison--navigation__button"></button>
      <button class="comparison--navigation__button" id="swipe"></button>
      <button class="comparison--navigation__button"></button>
      <input type="text">`;
    swipeClick = vi.spyOn(assertNotNull($<HTMLButtonElement>('#swipe')), 'click');
    setupDupeReports();
  });

  it('clicks the bound button on a plain key press', () => {
    fireEvent.keyDown(document, { key: 'k', keyCode: 75 });
    expect(swipeClick).toHaveBeenCalledOnce();
  });

  it('ignores keys typed into a text field', () => {
    const input = assertNotNull($<HTMLInputElement>('input'));
    input.focus();
    fireEvent.keyDown(input, { key: 'k', keyCode: 75 });
    expect(swipeClick).not.toHaveBeenCalled();
  });

  it('ignores keys pressed with a modifier', () => {
    fireEvent.keyDown(document, { key: 'k', keyCode: 75, ctrlKey: true });
    expect(swipeClick).not.toHaveBeenCalled();
  });
});
