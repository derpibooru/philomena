/**
 * localStorage utils
 */

export const lastUpdatedSuffix = '__lastUpdated';

export default {

  set(key: string, value: unknown) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    }
    catch (err) {
      return false;
    }
  },

  get<Value = unknown>(key: string): Value | null {
    const value = localStorage.getItem(key);
    if (value === null) return null;
    try {
      return JSON.parse(value);
    }
    catch (err) {
      return value as unknown as Value;
    }
  },

  remove(key: string) {
    try {
      localStorage.removeItem(key);
      return true;
    }
    catch (err) {
      return false;
    }
  },

  // Watch changes to a specified key - returns value on change
  watch(key: string, callback: (value: unknown) => void) {
    const handler = (event: StorageEvent) => {
      if (event.key === key) callback(this.get(key));
    };
    window.addEventListener('storage', handler);
    return () => window.removeEventListener('storage', handler);
  },

  // set() with an additional key containing the current time + expiration time
  setWithExpireTime(key: string, value: unknown, maxAge: number) {
    const lastUpdatedKey = key + lastUpdatedSuffix;
    const lastUpdatedTime = Date.now() + maxAge;

    this.set(key, value) && this.set(lastUpdatedKey, lastUpdatedTime);
  },

  // Whether the value of a key set with setWithExpireTime() has expired
  hasExpired(key: string) {
    const lastUpdatedKey = key + lastUpdatedSuffix;
    const lastUpdatedTime = this.get<number>(lastUpdatedKey);

    return lastUpdatedTime !== null && Date.now() > lastUpdatedTime;
  },

};
