import { $ } from '../utils/dom';
import { assertNotNull } from '../utils/assert';
import { setupSearch } from '../search';
import { setupTagListener } from '../tagsinput';

const formData = `<form class="js-search-form">
  <input type="text" class="js-search-field">
  <a data-search-prepend="-">NOT</a>
  <a data-search-add="id.lte:10" data-search-select-last="2" data-search-show-help="numeric">Numeric ID</a>
  <a data-search-add="my:faves" data-search-show-help=" ">My favorites</a>
  <div class="hidden" data-search-help="boolean">
    <span class="js-search-help-subject"></span> is a Boolean value field
  </div>
  <div class="hidden" data-search-help="numeric">
    <span class="js-search-help-subject"></span> is a numerical range field
  </div>
</form>`;

describe('Search form help', () => {
  beforeAll(() => {
    setupSearch();
    setupTagListener();
  });

  let input: HTMLInputElement;
  let prependAnchor: HTMLAnchorElement;
  let idAnchor: HTMLAnchorElement;
  let favesAnchor: HTMLAnchorElement;
  let helpNumeric: HTMLDivElement;
  let subjectSpan: HTMLElement;

  beforeEach(() => {
    document.body.innerHTML = formData;

    input = assertNotNull($<HTMLInputElement>('input'));
    prependAnchor = assertNotNull($<HTMLAnchorElement>('a[data-search-prepend]'));
    idAnchor = assertNotNull($<HTMLAnchorElement>('a[data-search-add="id.lte:10"]'));
    favesAnchor = assertNotNull($<HTMLAnchorElement>('a[data-search-add="my:faves"]'));
    helpNumeric = assertNotNull($<HTMLDivElement>('[data-search-help="numeric"]'));
    subjectSpan = assertNotNull($<HTMLSpanElement>('span', helpNumeric));
  });

  it('should add text to input field', () => {
    idAnchor.click();
    expect(input.value).toBe('id.lte:10');

    favesAnchor.click();
    expect(input.value).toBe('id.lte:10, my:faves');
  });

  it('should focus and select text in input field when requested', () => {
    idAnchor.click();
    expect(input).toHaveFocus();
    expect(input.selectionStart).toBe(7);
    expect(input.selectionEnd).toBe(9);
  });

  it('should highlight subject name when requested', () => {
    expect(helpNumeric).toHaveClass('hidden');
    idAnchor.click();
    expect(helpNumeric).not.toHaveClass('hidden');
    expect(subjectSpan).toHaveTextContent('Numeric ID');
  });

  it('should not focus and select text in input field when unavailable', () => {
    favesAnchor.click();
    expect(input).not.toHaveFocus();
    expect(input.selectionStart).toBe(8);
    expect(input.selectionEnd).toBe(8);
  });

  it('should not highlight subject name when unavailable', () => {
    favesAnchor.click();
    expect(helpNumeric).toHaveClass('hidden');
  });

  it('should prepend to empty input', () => {
    prependAnchor.click();
    expect(input.value).toBe('-');
  });

  it('should prepend to single input', () => {
    input.value = 'a';
    prependAnchor.click();
    expect(input.value).toBe('-a');
  });

  it('should prepend to comma-separated input', () => {
    input.value = 'a,b';
    prependAnchor.click();
    expect(input.value).toBe('a,-b');
  });

  it('should prepend to comma and space-separated input', () => {
    input.value = 'a, b';
    prependAnchor.click();
    expect(input.value).toBe('a, -b');
  });
});
