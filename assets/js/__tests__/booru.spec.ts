import { beforeEach, describe, expect, it, vi } from 'vitest';
import { tagsVersion, loadBooruData, getTag, type TagData } from '../booru';
import store from '../utils/store';
import * as matchQuery from '../match-query';
import type { AstMatcher } from '../query/types';

vi.mock('../utils/store');
vi.mock('../match-query');

describe('booru', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    document.body.innerHTML = '';
    window.booru = {
      timeAgo: () => {},
      csrfToken: '',
      spoilerType: 'off',
      imagesWithDownvotingDisabled: [],
      watchedTagList: [],
      spoileredTagList: [],
      ignoredTagList: [],
      hiddenTagList: [],
      userRole: undefined,
      userIsSignedIn: false,
      userCanEditFilter: false,
      hiddenFilter: (() => false) as AstMatcher,
      spoileredFilter: (() => false) as AstMatcher,
      interactions: [],
      hideStaffTools: false,
      fancyTagUpload: false,
      fancyTagEdit: false,
    };
  });

  describe('getTag', () => {
    it('returns stored tag when valid', () => {
      const mockTag: TagData = {
        id: 123,
        name: 'test tag',
        images: 50,
        spoiler_image_uri: 'http://example.com/spoiler.png',
        fetchedAt: Date.now() / 1000,
      };

      vi.mocked(store.get).mockReturnValue(mockTag);

      const result = getTag(123);

      expect(store.get).toHaveBeenCalledWith('bor_tags_123');
      expect(result).toEqual(mockTag);
    });

    it('returns dummy tag when not found in store', () => {
      vi.mocked(store.get).mockReturnValue(undefined);

      const result = getTag(456);

      expect(result).toEqual({
        id: 456,
        name: '(unknown tag)',
        images: 0,
        spoiler_image_uri: null,
        fetchedAt: null,
      });
    });

    it('returns dummy tag when stored data is invalid (missing properties)', () => {
      vi.mocked(store.get).mockReturnValue({ id: 789 });

      const result = getTag(789);

      expect(result).toEqual({
        id: 789,
        name: '(unknown tag)',
        images: 0,
        spoiler_image_uri: null,
        fetchedAt: null,
      });
    });

    it('returns dummy tag when stored data has wrong types', () => {
      vi.mocked(store.get).mockReturnValue({
        id: 'not a number',
        name: 123,
        images: 'not a number',
        spoiler_image_uri: 123,
        fetchedAt: 'not a number',
      });

      const result = getTag(999);

      expect(result).toEqual({
        id: 999,
        name: '(unknown tag)',
        images: 0,
        spoiler_image_uri: null,
        fetchedAt: null,
      });
    });
  });

  describe('loadBooruData', () => {
    it('does nothing when datastore element is missing', () => {
      loadBooruData();

      expect(window.booru.csrfToken).toBe('');
    });

    it('loads booru data from dataset', () => {
      document.body.innerHTML = `
        <div class="js-datastore"
          data-spoiler-type="click"
          data-images-with-downvoting-disabled='["1","2","3"]'
          data-watched-tag-list="[10,20,30]"
          data-spoilered-tag-list="[40,50]"
          data-ignored-tag-list="[60]"
          data-hidden-tag-list="[70,80]"
          data-user-role="admin"
          data-user-is-signed-in="true"
          data-user-can-edit-filter="true"
          data-hidden-filter="safe"
          data-spoilered-filter="suggestive"
          data-tags-version="7"
          data-interactions='[{"image_id":1,"user_id":1,"interaction_type":"voted","value":"up"}]'
          data-hide-staff-tools=""
          data-fancy-tag-upload="true"
          data-fancy-tag-edit="true"
        ></div>
        <meta name="csrf-token" content="test-csrf-token">
      `;

      const mockHiddenMatcher = vi.fn() as AstMatcher;
      const mockSpoileredMatcher = vi.fn() as AstMatcher;

      vi.mocked(matchQuery.parseSearch)
        .mockReturnValueOnce(mockHiddenMatcher)
        .mockReturnValueOnce(mockSpoileredMatcher);

      vi.mocked(store.get)
        .mockReturnValueOnce(7) // tags version matches
        .mockReturnValue(undefined); // no stored tags

      // Mock fetch for tag fetching
      global.fetch = vi.fn().mockResolvedValue({
        json: () => Promise.resolve({ tags: [] }),
      });

      loadBooruData();

      expect(window.booru.spoilerType).toBe('click');
      expect(window.booru.imagesWithDownvotingDisabled).toEqual(['1', '2', '3']);
      expect(window.booru.watchedTagList).toEqual([10, 20, 30]);
      expect(window.booru.spoileredTagList).toEqual([40, 50]);
      expect(window.booru.ignoredTagList).toEqual([60]);
      expect(window.booru.hiddenTagList).toEqual([70, 80]);
      expect(window.booru.userRole).toBe('admin');
      expect(window.booru.userIsSignedIn).toBe(true);
      expect(window.booru.userCanEditFilter).toBe(true);
      expect(window.booru.interactions).toEqual([{ image_id: 1, user_id: 1, interaction_type: 'voted', value: 'up' }]);
      expect(window.booru.hideStaffTools).toBe(false);
      expect(window.booru.fancyTagUpload).toBe(true);
      expect(window.booru.fancyTagEdit).toBe(true);
      expect(window.booru.csrfToken).toBe('test-csrf-token');
      expect(window.booru.hiddenFilter).toBe(mockHiddenMatcher);
      expect(window.booru.spoileredFilter).toBe(mockSpoileredMatcher);
    });

    it('handles hideStaffTools set to true', () => {
      document.body.innerHTML = `
        <div class="js-datastore"
          data-hide-staff-tools="true"
          data-hidden-filter="safe"
          data-spoilered-filter="safe"
        ></div>
      `;

      vi.mocked(matchQuery.parseSearch).mockReturnValue((() => false) as AstMatcher);
      vi.mocked(store.get).mockReturnValue(6);

      loadBooruData();

      expect(window.booru.hideStaffTools).toBe(true);
    });

    it('handles missing CSRF token gracefully', () => {
      document.body.innerHTML = `
        <div class="js-datastore"
          data-hidden-filter="safe"
          data-spoilered-filter="safe"
        ></div>
      `;

      vi.mocked(matchQuery.parseSearch).mockReturnValue((() => false) as AstMatcher);
      vi.mocked(store.get).mockReturnValue(6);

      loadBooruData();

      expect(window.booru.csrfToken).toBe('');
    });

    it('handles null content attribute on CSRF token', () => {
      document.body.innerHTML = `
        <div class="js-datastore"
          data-hidden-filter="safe"
          data-spoilered-filter="safe"
        ></div>
        <meta name="csrf-token">
      `;

      vi.mocked(matchQuery.parseSearch).mockReturnValue((() => false) as AstMatcher);
      vi.mocked(store.get).mockReturnValue(6);

      loadBooruData();

      expect(window.booru.csrfToken).toBe('');
    });

    it('clears tags when version mismatch', () => {
      document.body.innerHTML = `
        <div class="js-datastore"
          data-tags-version="8"
          data-watched-tag-list="[1,2,3]"
          data-spoilered-tag-list="[4,5]"
          data-hidden-tag-list="[6]"
          data-hidden-filter="safe"
          data-spoilered-filter="safe"
        ></div>
      `;

      vi.mocked(matchQuery.parseSearch).mockReturnValue((() => false) as AstMatcher);
      vi.mocked(store.get).mockReturnValueOnce(7); // Old version
      vi.mocked(store.set).mockReturnValue(true);
      vi.mocked(store.remove).mockReturnValue(true);

      // Mock localStorage keys
      const mockKeys = ['bor_tags_1', 'bor_tags_2', 'other_key'];
      vi.spyOn(Object, 'keys').mockReturnValueOnce(mockKeys);

      global.fetch = vi.fn().mockResolvedValue({
        json: () => Promise.resolve({ tags: [] }),
      });

      loadBooruData();

      expect(store.remove).toHaveBeenCalledWith('bor_tags_1');
      expect(store.remove).toHaveBeenCalledWith('bor_tags_2');
      expect(store.set).toHaveBeenCalledWith('bor_tags_version', tagsVersion);
    });

    it('fetches new and stale tags', async () => {
      document.body.innerHTML = `
        <div class="js-datastore"
          data-tags-version="6"
          data-watched-tag-list="[]"
          data-spoilered-tag-list="[1,2]"
          data-hidden-tag-list="[3]"
          data-hidden-filter="safe"
          data-spoilered-filter="safe"
        ></div>
      `;

      const now = Date.now() / 1000;
      const twoWeeksAgo = now - 1209600;

      // Mock stored tags: one fresh, one stale, one missing
      vi.mocked(store.get)
        .mockReturnValueOnce(6) // tags version matches
        .mockReturnValueOnce({
          // tag 1 - fresh
          id: 1,
          name: 'fresh tag',
          images: 10,
          spoiler_image_uri: null,
          fetchedAt: now - 1000,
        })
        .mockReturnValueOnce({
          // tag 2 - stale
          id: 2,
          name: 'stale tag',
          images: 20,
          spoiler_image_uri: null,
          fetchedAt: twoWeeksAgo,
        })
        .mockReturnValueOnce(undefined); // tag 3 - missing

      const mockFetch = vi.fn().mockResolvedValue({
        json: () =>
          Promise.resolve({
            tags: [
              { id: 2, name: 'updated tag 2', images: 25, spoiler_image_uri: null },
              { id: 3, name: 'new tag 3', images: 30, spoiler_image_uri: null },
            ],
          }),
      });

      global.fetch = mockFetch;

      vi.mocked(matchQuery.parseSearch).mockReturnValue((() => false) as AstMatcher);

      loadBooruData();

      // Wait for async fetch to complete
      await vi.waitFor(() => {
        expect(mockFetch).toHaveBeenCalledWith('/fetch/tags?ids[]=2&ids[]=3');
      });
    });

    it('fetches tags in batches of 40', async () => {
      const tagIds = Array.from({ length: 50 }, (_, i) => i + 1);

      document.body.innerHTML = `
        <div class="js-datastore"
          data-tags-version="6"
          data-watched-tag-list="[]"
          data-spoilered-tag-list="${JSON.stringify(tagIds)}"
          data-hidden-tag-list="[]"
          data-hidden-filter="safe"
          data-spoilered-filter="safe"
        ></div>
      `;

      // All tags are missing from store
      vi.mocked(store.get)
        .mockReturnValueOnce(6) // tags version
        .mockReturnValue(undefined); // all tags missing

      const mockFetch = vi.fn().mockResolvedValue({
        json: () => Promise.resolve({ tags: [] }),
      });

      global.fetch = mockFetch;

      vi.mocked(matchQuery.parseSearch).mockReturnValue((() => false) as AstMatcher);

      loadBooruData();

      // Wait for async fetches to complete
      await vi.waitFor(() => {
        expect(mockFetch).toHaveBeenCalledTimes(2);
      });

      // First batch: tags 1-40
      const firstCall = mockFetch.mock.calls[0][0] as string;
      expect(firstCall).toContain('ids[]=1');
      expect(firstCall).toContain('ids[]=40');

      // Check that it doesn't contain tag 41 in first batch
      expect(firstCall).not.toContain('ids[]=41');
    });

    it('removes duplicate tags from watched, spoilered, and hidden lists', () => {
      document.body.innerHTML = `
        <div class="js-datastore"
          data-tags-version="6"
          data-watched-tag-list="[]"
          data-spoilered-tag-list="[1,2,2]"
          data-hidden-tag-list="[2,3,3]"
          data-hidden-filter="safe"
          data-spoilered-filter="safe"
        ></div>
      `;

      vi.mocked(store.get)
        .mockReturnValueOnce(6) // tags version
        .mockReturnValue(undefined); // all tags missing

      const mockFetch = vi.fn().mockResolvedValue({
        json: () => Promise.resolve({ tags: [] }),
      });

      global.fetch = mockFetch;

      vi.mocked(matchQuery.parseSearch).mockReturnValue((() => false) as AstMatcher);

      loadBooruData();

      // The combined unique list should be [1, 2, 3]
      expect(mockFetch).toHaveBeenCalledWith('/fetch/tags?ids[]=1&ids[]=2&ids[]=3');
    });
  });
});
