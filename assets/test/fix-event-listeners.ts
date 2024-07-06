// Add helper to fix event listeners on a given target

export function fixEventListeners(t: EventTarget) {
  let eventListeners: Record<string, unknown[]>;

  /* eslint-disable @typescript-eslint/no-explicit-any */
  beforeAll(() => {
    eventListeners = {};
    const oldAddEventListener = t.addEventListener;

    t.addEventListener = function (type: string, listener: any, options: any): void {
      eventListeners[type] = eventListeners[type] || [];
      eventListeners[type].push(listener);
      return oldAddEventListener(type, listener, options);
    };
  });

  afterEach(() => {
    for (const key in eventListeners) {
      for (const listener of eventListeners[key]) {
        (t.removeEventListener as any)(key, listener);
      }
    }
    eventListeners = {};
  });
}
