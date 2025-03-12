import store, { lastUpdatedSuffix } from '../store';
import { mockStorageImpl } from '../../../test/mock-storage';
import { getRandomIntBetween } from '../../../test/randomness';
import { fireEvent } from '@testing-library/dom';
import { mockDateNow } from '../../../test/mock';

describe('Store utilities', () => {
  const { setItemSpy, getItemSpy, removeItemSpy, forceStorageError, setStorageValue } = mockStorageImpl();
  const initialDateNow = 1640645432942;

  describe('set', () => {
    it('should be able to set various types of items correctly', () => {
      const mockKey = `mock-set-key-${getRandomIntBetween(1, 10)}`;
      const mockValues = [
        1,
        false,
        null,
        Math.random(),
        'some string\n value\twith trailing whitespace    ',
        { complex: { value: true, key: 'string' } },
      ];

      mockValues.forEach((mockValue, i) => {
        const result = store.set(mockKey, mockValue);

        expect(setItemSpy).toHaveBeenNthCalledWith(i + 1, mockKey, JSON.stringify(mockValue));
        expect(result).toBe(true);
      });
      expect(setItemSpy).toHaveBeenCalledTimes(mockValues.length);
    });

    it('should gracefully handle failure to set key', () => {
      const mockKey = 'mock-set-key';
      const mockValue = Math.random();
      let result: boolean | undefined;
      forceStorageError(() => {
        result = store.set(mockKey, mockValue);
      });

      expect(result).toBe(false);
    });
  });

  describe('get', () => {
    it('should be able to get various types of items correctly', () => {
      const initialValues = {
        int: 1,
        boolean: false,
        null: null,
        float: Math.random(),
        string: '\t\t\thello\nthere\n    ',
        object: {
          rolling: {
            in: {
              the: {
                deep: true,
              },
            },
          },
        },
      };
      const initialValueKeys = Object.keys(initialValues) as (keyof typeof initialValues)[];
      setStorageValue(
        initialValueKeys.reduce((acc, key) => {
          return { ...acc, [key]: JSON.stringify(initialValues[key]) };
        }, {}),
      );

      initialValueKeys.forEach((key, i) => {
        const result = store.get(key);

        expect(getItemSpy).toHaveBeenNthCalledWith(i + 1, key);
        expect(result).toEqual(initialValues[key]);
      });
      expect(getItemSpy).toHaveBeenCalledTimes(initialValueKeys.length);
    });

    it('should return original value if item cannot be parsed', () => {
      const mockKey = 'mock-get-key';
      const malformedValue = '({[+:"`';
      setStorageValue({
        [mockKey]: malformedValue,
      });
      const result = store.get(mockKey);
      expect(getItemSpy).toHaveBeenCalledTimes(1);
      expect(getItemSpy).toHaveBeenNthCalledWith(1, mockKey);
      expect(result).toBe(malformedValue);
    });

    it('should return null if item is not set', () => {
      const mockKey = `mock-get-key-${getRandomIntBetween(1, 10)}`;
      const result = store.get(mockKey);
      expect(getItemSpy).toHaveBeenCalledTimes(1);
      expect(getItemSpy).toHaveBeenNthCalledWith(1, mockKey);
      expect(result).toBe(null);
    });
  });

  describe('remove', () => {
    it('should remove the provided key', () => {
      const mockKey = `mock-remove-key-${getRandomIntBetween(1, 10)}`;
      const result = store.remove(mockKey);
      expect(removeItemSpy).toHaveBeenCalledTimes(1);
      expect(removeItemSpy).toHaveBeenNthCalledWith(1, mockKey);
      expect(result).toBe(true);
    });

    it('should gracefully handle failure to remove key', () => {
      const mockKey = `mock-remove-key-${getRandomIntBetween(1, 10)}`;
      let result: boolean | undefined;
      forceStorageError(() => {
        result = store.remove(mockKey);
      });
      expect(result).toBe(false);
    });
  });

  describe('watch', () => {
    it('should attach a storage event listener and fire when the provide key changes', () => {
      const mockKey = `mock-watch-key-${getRandomIntBetween(1, 10)}`;
      const mockValue = Math.random();
      const mockCallback = vi.fn();
      setStorageValue({
        [mockKey]: JSON.stringify(mockValue),
      });
      const addEventListenerSpy = vi.spyOn(window, 'addEventListener');

      const cleanup = store.watch(mockKey, mockCallback);

      // Should not get the item just yet, only register the event handler
      expect(getItemSpy).not.toHaveBeenCalled();
      expect(addEventListenerSpy).toHaveBeenCalledTimes(1);
      expect(addEventListenerSpy.mock.calls[0][0]).toEqual('storage');

      // Should not call callback for unknown key
      let storageEvent = new StorageEvent('storage', { key: 'unknown-key' });
      fireEvent(window, storageEvent);
      expect(getItemSpy).not.toHaveBeenCalled();
      expect(mockCallback).not.toHaveBeenCalled();

      // Should call callback with the value from the store
      storageEvent = new StorageEvent('storage', { key: mockKey });
      fireEvent(window, storageEvent);
      expect(getItemSpy).toHaveBeenCalledTimes(1);
      expect(mockCallback).toHaveBeenCalledTimes(1);
      expect(mockCallback).toHaveBeenNthCalledWith(1, mockValue);

      // Remove the listener
      cleanup();
      storageEvent = new StorageEvent('storage', { key: mockKey });
      fireEvent(window, storageEvent);

      // Expect unchanged call counts due to removed handler
      expect(getItemSpy).toHaveBeenCalledTimes(1);
      expect(mockCallback).toHaveBeenCalledTimes(1);
      expect(mockCallback).toHaveBeenNthCalledWith(1, mockValue);
    });
  });

  describe('setWithExpireTime', () => {
    mockDateNow(initialDateNow);

    it('should set both original and last update key', () => {
      const mockKey = `mock-setWithExpireTime-key-${getRandomIntBetween(1, 10)}`;
      const mockValue = 'mock value';
      const mockMaxAge = 3600;
      store.setWithExpireTime(mockKey, mockValue, mockMaxAge);

      expect(setItemSpy).toHaveBeenCalledTimes(2);
      expect(setItemSpy).toHaveBeenNthCalledWith(1, mockKey, JSON.stringify(mockValue));
      expect(setItemSpy).toHaveBeenNthCalledWith(
        2,
        mockKey + lastUpdatedSuffix,
        JSON.stringify(initialDateNow + mockMaxAge),
      );
    });
  });

  describe('hasExpired', () => {
    mockDateNow(initialDateNow);
    const mockKey = `mock-hasExpired-key-${getRandomIntBetween(1, 10)}`;
    const mockLastUpdatedKey = mockKey + lastUpdatedSuffix;

    it('should return true for values that have no expiration key', () => {
      const result = store.hasExpired('undefined-key');
      expect(result).toBe(true);
    });

    it('should return true for keys with last update timestamp smaller than the current time', () => {
      setStorageValue({
        [mockLastUpdatedKey]: JSON.stringify(initialDateNow - 1),
      });

      const result = store.hasExpired(mockKey);

      expect(getItemSpy).toHaveBeenCalledTimes(1);
      expect(result).toBe(true);
    });

    it('should return false for keys with last update timestamp equal to the current time', () => {
      setStorageValue({
        [mockLastUpdatedKey]: JSON.stringify(initialDateNow),
      });

      const result = store.hasExpired(mockKey);

      expect(getItemSpy).toHaveBeenCalledTimes(1);
      expect(result).toBe(false);
    });

    it('should return false for keys with last update timestamp greater than the current time', () => {
      setStorageValue({
        [mockLastUpdatedKey]: JSON.stringify(initialDateNow + 1),
      });

      const result = store.hasExpired(mockKey);

      expect(getItemSpy).toHaveBeenCalledTimes(1);
      expect(result).toBe(false);
    });
  });
});
