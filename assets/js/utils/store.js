/**
 * localStorage utils
 */

const lastUpdatedSuffix = '__lastUpdated';

export default {

  set(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
      return true;
    }
    catch (err) {
      return false;
    }
  },

  get(key) {
    const value = localStorage.getItem(key);
    try {
      return JSON.parse(value);
    }
    catch (err) {
      return value;
    }
  },

  remove(key) {
    try {
      localStorage.removeItem(key);
      return true;
    }
    catch (err) {
      return false;
    }
  },

  // Watch changes to a specified key - returns value on change
  watch(key, callback) {
    window.addEventListener('storage', event => {
      if (event.key === key) callback(this.get(key));
    });
  },

  // set() with an additional key containing the current time + expiration time
  setWithExpireTime(key, value, maxAge) {
    const lastUpdatedKey = key + lastUpdatedSuffix;
    const lastUpdatedTime = Date.now() + maxAge;

    this.set(key, value) && this.set(lastUpdatedKey, lastUpdatedTime);
  },

  // Whether the value of a key set with setWithExpireTime() has expired
  hasExpired(key) {
    const lastUpdatedKey = key + lastUpdatedSuffix;
    const lastUpdatedTime = this.get(lastUpdatedKey);

    if (Date.now() > lastUpdatedTime) {
      return true;
    }

    return false;
  },

};
