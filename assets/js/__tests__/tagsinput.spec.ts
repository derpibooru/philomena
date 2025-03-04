import { $, $$, hideEl } from '../utils/dom';
import { assertNotNull } from '../utils/assert';
import { setupTagsInput, addTag, reloadTagsInput } from '../tagsinput';

const formData = `<form class="tags-form">
  <div class="js-tag-block fancy-tag-upload">
    <textarea class="js-taginput js-taginput-plain"></textarea>
    <div class="js-taginput js-taginput-fancy">
      <input type="text" class="js-taginput-input" placeholder="add a tag">
    </div>
  </div>
  <button class="js-taginput-show">Fancy Editor</button>
  <button class="js-taginput-hide hidden">Plain Editor</button>
  <input type="submit" value="Save Tags">
</form>`;

describe('Fancy tags input', () => {
  let form: HTMLFormElement;
  let tagBlock: HTMLDivElement;
  let plainInput: HTMLTextAreaElement;
  let fancyInput: HTMLDivElement;
  let fancyText: HTMLInputElement;
  let fancyShowButton: HTMLButtonElement;
  let plainShowButton: HTMLButtonElement;

  beforeEach(() => {
    window.booru.fancyTagUpload = true;
    window.booru.fancyTagEdit = true;
    document.body.innerHTML = formData;

    form = assertNotNull($<HTMLFormElement>('.tags-form'));
    tagBlock = assertNotNull($<HTMLDivElement>('.js-tag-block'));
    plainInput = assertNotNull($<HTMLTextAreaElement>('.js-taginput-plain'));
    fancyInput = assertNotNull($<HTMLDivElement>('.js-taginput-fancy'));
    fancyText = assertNotNull($<HTMLInputElement>('.js-taginput-input'));
    fancyShowButton = assertNotNull($<HTMLButtonElement>('.js-taginput-show'));
    plainShowButton = assertNotNull($<HTMLButtonElement>('.js-taginput-hide'));

    // prevent these from submitting the form
    fancyShowButton.addEventListener('click', e => e.preventDefault());
    plainShowButton.addEventListener('click', e => e.preventDefault());
  });

  for (let i = 0; i < 4; i++) {
    const type = (i & 2) === 0 ? 'upload' : 'edit';
    const name = (i & 2) === 0 ? 'fancyTagUpload' : 'fancyTagEdit';
    const value = (i & 1) === 0;

    // eslint-disable-next-line no-loop-func
    it(`should imply ${name}:${value} <-> ${type}:${value} on setup`, () => {
      window.booru.fancyTagEdit = false;
      window.booru.fancyTagUpload = false;
      window.booru[name] = value;

      plainInput.value = 'a, b';
      tagBlock.classList.remove('fancy-tag-edit', 'fancy-tag-upload');
      tagBlock.classList.add(`fancy-tag-${type}`);
      expect($$('span.tag', fancyInput)).toHaveLength(0);

      setupTagsInput(tagBlock);
      expect($$('span.tag', fancyInput)).toHaveLength(value ? 2 : 0);
    });
  }

  it('should move tags from the plain to the fancy editor when the fancy editor is shown', () => {
    expect($$('span.tag', fancyInput)).toHaveLength(0);

    setupTagsInput(tagBlock);
    plainInput.value = 'a, b';
    fancyShowButton.click();
    expect($$('span.tag', fancyInput)).toHaveLength(2);
  });

  it('should move tags from the plain to the fancy editor on reload event', () => {
    expect($$('span.tag', fancyInput)).toHaveLength(0);

    setupTagsInput(tagBlock);
    plainInput.value = 'a, b';
    reloadTagsInput(plainInput);
    expect($$('span.tag', fancyInput)).toHaveLength(2);
  });

  it('should respond to addtag events', () => {
    setupTagsInput(tagBlock);
    addTag(plainInput, 'a');
    expect($$('span.tag', fancyInput)).toHaveLength(1);
  });

  it('should not respond to addtag events if the container is hidden', () => {
    setupTagsInput(tagBlock);
    hideEl(fancyInput);
    addTag(plainInput, 'a');
    expect($$('span.tag', fancyInput)).toHaveLength(0);
  });

  it('should respond to autocomplete events', () => {
    setupTagsInput(tagBlock);
    fancyText.dispatchEvent(new CustomEvent<string>('autocomplete', { detail: 'a' }));
    expect($$('span.tag', fancyInput)).toHaveLength(1);
  });

  it('should allow removing previously added tags by clicking them', () => {
    setupTagsInput(tagBlock);
    addTag(plainInput, 'a');
    assertNotNull($<HTMLAnchorElement>('span.tag a', fancyInput)).click();
    expect($$('span.tag', fancyInput)).toHaveLength(0);
  });

  it('should allow removing previously added tags by adding one with a minus sign prepended', () => {
    setupTagsInput(tagBlock);
    addTag(plainInput, 'a');
    expect($$('span.tag', fancyInput)).toHaveLength(1);
    addTag(plainInput, '-a');
    expect($$('span.tag', fancyInput)).toHaveLength(0);
  });

  it('should disallow adding empty tags', () => {
    setupTagsInput(tagBlock);
    addTag(plainInput, '');
    expect($$('span.tag', fancyInput)).toHaveLength(0);
  });

  it('should disallow adding existing tags', () => {
    setupTagsInput(tagBlock);
    addTag(plainInput, 'a');
    addTag(plainInput, 'a');
    expect($$('span.tag', fancyInput)).toHaveLength(1);
  });

  it('should submit the form on ctrl+enter', () => {
    setupTagsInput(tagBlock);

    const ev = new KeyboardEvent('keydown', { keyCode: 13, ctrlKey: true, bubbles: true });

    return new Promise<void>(resolve => {
      form.addEventListener('submit', e => {
        e.preventDefault();
        resolve();
      });

      fancyText.dispatchEvent(ev);
      expect(ev.defaultPrevented).toBe(true);
    });
  });

  it('does nothing when backspacing on empty input and there are no tags', () => {
    setupTagsInput(tagBlock);

    const ev = new KeyboardEvent('keydown', { keyCode: 8, bubbles: true });
    fancyText.dispatchEvent(ev);

    expect($$('span.tag', fancyInput)).toHaveLength(0);
  });

  it('erases the last added tag when backspacing on empty input', () => {
    setupTagsInput(tagBlock);
    addTag(plainInput, 'a');
    addTag(plainInput, 'b');

    const ev = new KeyboardEvent('keydown', { keyCode: 8, bubbles: true });
    fancyText.dispatchEvent(ev);

    expect($$('span.tag', fancyInput)).toHaveLength(1);
  });

  it('adds new tag when comma is pressed', () => {
    setupTagsInput(tagBlock);

    const ev = new KeyboardEvent('keydown', { keyCode: 188, bubbles: true });
    fancyText.value = 'a';
    fancyText.dispatchEvent(ev);

    expect($$('span.tag', fancyInput)).toHaveLength(1);
    expect(fancyText.value).toBe('');
  });

  it('adds new tag when enter is pressed', () => {
    setupTagsInput(tagBlock);

    const ev = new KeyboardEvent('keydown', { keyCode: 13, bubbles: true });
    fancyText.value = 'a';
    fancyText.dispatchEvent(ev);

    expect($$('span.tag', fancyInput)).toHaveLength(1);
    expect(fancyText.value).toBe('');
  });
});
