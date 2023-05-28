import { displayTags, getHiddenTags, getSpoileredTags, imageHitsComplex, imageHitsTags, TagData } from '../tag';
import { mockStorage } from '../../../test/mock-storage';
import { getRandomArrayItem } from '../../../test/randomness';
import parseSearch from '../../match_query';

describe('Tag utilities', () => {
  const tagStorageKeyPrefix = 'bor_tags_';
  const mockTagInfo: Record<string, TagData> = {
    1: {
      id: 1,
      name: 'safe',
      images: 69,
      spoiler_image_uri: null,
      fetchedAt: null,
    },
    2: {
      id: 2,
      name: 'fox',
      images: 1,
      spoiler_image_uri: '/mock-fox-spoiler-image.svg',
      fetchedAt: null,
    },
    3: {
      id: 3,
      name: 'paw pads',
      images: 42,
      spoiler_image_uri: '/mock-paw-pads-spoiler-image.svg',
      fetchedAt: null,
    },
    4: {
      id: 4,
      name: 'whiskers',
      images: 42,
      spoiler_image_uri: null,
      fetchedAt: null,
    },
    5: {
      id: 5,
      name: 'lilo & stitch',
      images: 6,
      spoiler_image_uri: null,
      fetchedAt: null,
    },
  };
  const getEnabledSpoilerType = () => getRandomArrayItem<SpoilerType>(['click', 'hover', 'static']);

  mockStorage({
    getItem(key: string): string | null {
      if (key.startsWith(tagStorageKeyPrefix)) {
        const tagId = key.substring(tagStorageKeyPrefix.length);
        const tagInfo = mockTagInfo[tagId];
        return tagInfo ? JSON.stringify(tagInfo) : null;
      }
      return null;
    },
  });

  describe('getHiddenTags', () => {
    it('should get a single hidden tag\'s information', () => {
      window.booru.hiddenTagList = [1, 1];

      const result = getHiddenTags();

      expect(result).toHaveLength(1);
      expect(result).toEqual([mockTagInfo[1]]);
    });

    it('should get the list of multiple hidden tags in the correct order', () => {
      window.booru.hiddenTagList = [1, 2, 2, 2, 3, 4, 4];

      const result = getHiddenTags();

      expect(result).toHaveLength(4);
      expect(result).toEqual([
        mockTagInfo[3],
        mockTagInfo[2],
        mockTagInfo[1],
        mockTagInfo[4],
      ]);
    });
  });

  describe('getSpoileredTags', () => {
    it('should return an empty array if spoilers are off', () => {
      window.booru.spoileredTagList = [1, 2, 3, 4];
      window.booru.spoilerType = 'off';

      const result = getSpoileredTags();

      expect(result).toHaveLength(0);
    });

    it('should get a single spoilered tag\'s information', () => {
      window.booru.spoileredTagList = [1, 1];
      window.booru.ignoredTagList = [];
      window.booru.spoilerType = getEnabledSpoilerType();

      const result = getSpoileredTags();

      expect(result).toHaveLength(1);
      expect(result).toEqual([mockTagInfo[1]]);
    });

    it('should get the list of multiple spoilered tags in the correct order', () => {
      window.booru.spoileredTagList = [1, 1, 2, 2, 3, 4, 4];
      window.booru.ignoredTagList = [];
      window.booru.spoilerType = getEnabledSpoilerType();

      const result = getSpoileredTags();

      expect(result).toHaveLength(4);
      expect(result).toEqual([
        mockTagInfo[2],
        mockTagInfo[3],
        mockTagInfo[1],
        mockTagInfo[4],
      ]);
    });

    it('should omit ignored tags from the list', () => {
      window.booru.spoileredTagList = [1, 2, 2, 3, 4, 4, 4];
      window.booru.ignoredTagList = [2, 3];
      window.booru.spoilerType = getEnabledSpoilerType();
      const result = getSpoileredTags();

      expect(result).toHaveLength(2);
      expect(result).toEqual([
        mockTagInfo[1],
        mockTagInfo[4],
      ]);
    });
  });

  describe('imageHitsTags', () => {
    it('should return the list of tags that apply to the image', () => {
      const mockImageTags = [1, 4];
      const mockImage = new Image();
      mockImage.dataset.imageTags = JSON.stringify(mockImageTags);

      const result = imageHitsTags(mockImage, [mockTagInfo[1], mockTagInfo[2], mockTagInfo[3], mockTagInfo[4]]);
      expect(result).toHaveLength(mockImageTags.length);
      expect(result).toEqual([
        mockTagInfo[1],
        mockTagInfo[4],
      ]);
    });

    it('should return empty array if data attribute is missing', () => {
      const mockImage = new Image();
      const result = imageHitsTags(mockImage, []);
      expect(result).toEqual([]);
    });
  });

  describe('imageHitsComplex', () => {
    it('should return true if image matches the complex filter', () => {
      const mockSearchAST = parseSearch('safe || solo');

      const mockImageTagAliases = mockTagInfo[1].name;
      const mockImage = new Image();
      mockImage.dataset.imageTagAliases = mockImageTagAliases;

      const result = imageHitsComplex(mockImage, mockSearchAST);
      expect(result).toBe(true);
    });
  });

  describe('displayTags', () => {
    it('should return the correct value for a single tag', () => {
      const result = displayTags([mockTagInfo[1]]);
      expect(result).toEqual(mockTagInfo[1].name);
    });

    it('should return the correct value for two tags', () => {
      const result = displayTags([mockTagInfo[1], mockTagInfo[4]]);
      expect(result).toEqual(`${mockTagInfo[1].name}<span title="${mockTagInfo[4].name}">, ${mockTagInfo[4].name}</span>`);
    });

    it('should return the correct value for three tags', () => {
      const result = displayTags([mockTagInfo[1], mockTagInfo[4], mockTagInfo[3]]);
      expect(result).toEqual(`${mockTagInfo[1].name}<span title="${mockTagInfo[4].name}, ${mockTagInfo[3].name}">, ${mockTagInfo[4].name}, ${mockTagInfo[3].name}</span>`);
    });

    it('should escape HTML in the tag name', () => {
      const result = displayTags([mockTagInfo[5]]);
      expect(result).toEqual('lilo &amp; stitch');
    });
  });
});
