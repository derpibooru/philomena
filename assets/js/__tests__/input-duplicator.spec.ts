import { inputDuplicatorCreator } from '../input-duplicator';
import { assertNotNull } from '../utils/assert';
import { $, $$, removeEl } from '../utils/dom';

describe('Input duplicator functionality', () => {
  beforeEach(() => {
    document.documentElement.insertAdjacentHTML('beforeend', `<form action="/">
      <div class="js-max-input-count">3</div>
      <div class="js-input-source">
        <input id="0" name="0" class="js-input" type="text"/>
        <label>
          <a href="#" class="js-remove-input">Delete</a>
        </label>
      </div>
      <div class="js-button-container">
        <button type="button" class="js-add-input">Add input</button>
      </div>
    </form>`);
  });

  afterEach(() => {
    removeEl($$<HTMLFormElement>('form'));
  });

  function runCreator() {
    inputDuplicatorCreator({
      addButtonSelector: '.js-add-input',
      fieldSelector: '.js-input-source',
      maxInputCountSelector: '.js-max-input-count',
      removeButtonSelector: '.js-remove-input',
    });
  }

  it('should ignore forms without a duplicator button', () => {
    removeEl($$<HTMLButtonElement>('button'));
    expect(runCreator()).toBeUndefined();
  });

  it('should duplicate the input elements', () => {
    runCreator();

    expect($$('input')).toHaveLength(1);

    assertNotNull($<HTMLButtonElement>('.js-add-input')).click();

    expect($$('input')).toHaveLength(2);
  });

  it('should duplicate the input elements when the button is before the inputs', () => {
    const form = assertNotNull($<HTMLFormElement>('form'));
    const buttonDiv = assertNotNull($<HTMLDivElement>('.js-button-container'));
    removeEl(buttonDiv);
    form.insertAdjacentElement('afterbegin', buttonDiv);
    runCreator();

    assertNotNull($<HTMLButtonElement>('.js-add-input')).click();

    expect($$('input')).toHaveLength(2);
  });

  it('should not create more input elements than the limit', () => {
    runCreator();

    for (let i = 0; i < 5; i += 1) {
      assertNotNull($<HTMLButtonElement>('.js-add-input')).click();
    }

    expect($$('input')).toHaveLength(3);
  });

  it('should remove duplicated input elements', () => {
    runCreator();

    assertNotNull($<HTMLButtonElement>('.js-add-input')).click();
    assertNotNull($<HTMLAnchorElement>('.js-remove-input')).click();

    expect($$('input')).toHaveLength(1);
  });

  it('should not remove the last input element', () => {
    runCreator();

    assertNotNull($<HTMLAnchorElement>('.js-remove-input')).click();
    assertNotNull($<HTMLAnchorElement>('.js-remove-input')).click();
    for (let i = 0; i < 5; i += 1) {
      assertNotNull($<HTMLAnchorElement>('.js-remove-input')).click();
    }

    expect($$('input')).toHaveLength(1);
  });
});
