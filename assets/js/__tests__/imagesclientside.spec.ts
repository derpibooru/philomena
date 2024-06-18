import { filterNode, initImagesClientside } from '../imagesclientside';
import { parseSearch } from '../match_query';
import { matchNone } from '../query/boolean';
import { assertNotNull } from '../utils/assert';
import { $ } from '../utils/dom';

describe('filterNode', () => {
  beforeEach(() => {
    window.booru.hiddenTagList = [];
    window.booru.spoileredTagList = [];
    window.booru.ignoredTagList = [];
    window.booru.imagesWithDownvotingDisabled = [];

    window.booru.hiddenFilter = matchNone();
    window.booru.spoileredFilter = matchNone();
  });

  function makeMediaContainer() {
    const element = document.createElement('div');
    element.innerHTML = `
      <div class="image-container" data-image-id="1" data-image-tags="[1]">
        <div class="js-spoiler-info-overlay"></div>
        <picture><img src=""/></picture>
      </div>
    `;
    return [ element, assertNotNull($<HTMLDivElement>('.js-spoiler-info-overlay', element)) ];
  }

  it('should show image media boxes not matching any filter', () => {
    const [ container, spoilerOverlay ] = makeMediaContainer();

    filterNode(container);
    expect(spoilerOverlay).not.toContainHTML('(Complex Filter)');
    expect(spoilerOverlay).not.toContainHTML('(unknown tag)');
    expect(window.booru.imagesWithDownvotingDisabled).not.toContain('1');
  });

  it('should spoiler media boxes spoilered by a tag filter', () => {
    const [ container, spoilerOverlay ] = makeMediaContainer();
    window.booru.spoileredTagList = [1];

    filterNode(container);
    expect(spoilerOverlay).toContainHTML('(unknown tag)');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

  it('should spoiler media boxes spoilered by a complex filter', () => {
    const [ container, spoilerOverlay ] = makeMediaContainer();
    window.booru.spoileredFilter = parseSearch('id:1');

    filterNode(container);
    expect(spoilerOverlay).toContainHTML('(Complex Filter)');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

  it('should hide media boxes hidden by a tag filter', () => {
    const [ container, spoilerOverlay ] = makeMediaContainer();
    window.booru.hiddenTagList = [1];

    filterNode(container);
    expect(spoilerOverlay).toContainHTML('[HIDDEN]');
    expect(spoilerOverlay).toContainHTML('(unknown tag)');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

  it('should hide media boxes hidden by a complex filter', () => {
    const [ container, spoilerOverlay ] = makeMediaContainer();
    window.booru.hiddenFilter = parseSearch('id:1');

    filterNode(container);
    expect(spoilerOverlay).toContainHTML('[HIDDEN]');
    expect(spoilerOverlay).toContainHTML('(Complex Filter)');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

  function makeImageBlock(): HTMLElement[] {
    const element = document.createElement('div');
    element.innerHTML = `
      <div class="image-show-container" data-image-id="1" data-image-tags="[1]">
        <div class="image-filtered hidden">
          <img src=""/>
          <span class="filter-explanation"></span>
        </div>
        <div class="image-show hidden">
          <picture><img src=""/></picture>
        </div>
      </div>
    `;
    return [
      element,
      assertNotNull($<HTMLDivElement>('.image-filtered', element)),
      assertNotNull($<HTMLDivElement>('.image-show', element)),
      assertNotNull($<HTMLSpanElement>('.filter-explanation', element))
    ];
  }

  it('should show image blocks not matching any filter', () => {
    const [ container, imageFiltered, imageShow ] = makeImageBlock();

    filterNode(container);
    expect(imageFiltered).toHaveClass('hidden');
    expect(imageShow).not.toHaveClass('hidden');
    expect(window.booru.imagesWithDownvotingDisabled).not.toContain('1');
  });

  it('should spoiler image blocks spoilered by a tag filter', () => {
    const [ container, imageFiltered, imageShow, filterExplanation ] = makeImageBlock();
    window.booru.spoileredTagList = [1];

    filterNode(container);
    expect(imageFiltered).not.toHaveClass('hidden');
    expect(imageShow).toHaveClass('hidden');
    expect(filterExplanation).toContainHTML('spoilered by');
    expect(filterExplanation).toContainHTML('(unknown tag)');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

  it('should spoiler image blocks spoilered by a complex filter', () => {
    const [ container, imageFiltered, imageShow, filterExplanation ] = makeImageBlock();
    window.booru.spoileredFilter = parseSearch('id:1');

    filterNode(container);
    expect(imageFiltered).not.toHaveClass('hidden');
    expect(imageShow).toHaveClass('hidden');
    expect(filterExplanation).toContainHTML('spoilered by');
    expect(filterExplanation).toContainHTML('complex tag expression');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

  it('should hide image blocks hidden by a tag filter', () => {
    const [ container, imageFiltered, imageShow, filterExplanation ] = makeImageBlock();
    window.booru.hiddenTagList = [1];

    filterNode(container);
    expect(imageFiltered).not.toHaveClass('hidden');
    expect(imageShow).toHaveClass('hidden');
    expect(filterExplanation).toContainHTML('hidden by');
    expect(filterExplanation).toContainHTML('(unknown tag)');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

  it('should hide image blocks hidden by a complex filter', () => {
    const [ container, imageFiltered, imageShow, filterExplanation ] = makeImageBlock();
    window.booru.hiddenFilter = parseSearch('id:1');

    filterNode(container);
    expect(imageFiltered).not.toHaveClass('hidden');
    expect(imageShow).toHaveClass('hidden');
    expect(filterExplanation).toContainHTML('hidden by');
    expect(filterExplanation).toContainHTML('complex tag expression');
    expect(window.booru.imagesWithDownvotingDisabled).toContain('1');
  });

});

describe('initImagesClientside', () => {
  it('should initialize the imagesWithDownvotingDisabled array', () => {
    initImagesClientside();
    expect(window.booru.imagesWithDownvotingDisabled).toEqual([]);
  });
});
