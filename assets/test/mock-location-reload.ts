import { Mock } from 'vitest';

interface WritableWindow {
  location: Location;
}

// Replaces window.location with a stand-in whose reload is a mock. jsdom's Location
// accessors reject any receiver but the real object, so every other property is bound to it.
export function mockLocationReload(): void {
  let realLocation: Location;

  beforeAll(() => {
    realLocation = window.location;

    const descriptors = Object.getOwnPropertyDescriptors(realLocation);
    const bound: PropertyDescriptorMap = {};

    for (const [key, descriptor] of Object.entries(descriptors)) {
      bound[key] = {
        ...descriptor,
        ...(descriptor.get && { get: descriptor.get.bind(realLocation) }),
        ...(descriptor.set && { set: descriptor.set.bind(realLocation) }),
        ...(typeof descriptor.value === 'function' && { value: descriptor.value.bind(realLocation) }),
      };
    }

    bound.reload = { configurable: true, value: vi.fn() };

    delete (window as Partial<WritableWindow>).location;
    (window as WritableWindow).location = Object.defineProperties({}, bound) as Location;
  });

  beforeEach(() => {
    (window.location.reload as Mock).mockReset();
  });

  afterAll(() => {
    delete (window as Partial<WritableWindow>).location;
    (window as WritableWindow).location = realLocation;
  });
}
