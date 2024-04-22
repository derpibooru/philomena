import JSDOMEnvironment from 'jest-environment-jsdom';

export default class FixJSDOMEnvironment extends JSDOMEnvironment {
  constructor(...args: ConstructorParameters<typeof JSDOMEnvironment>) {
    super(...args);

    // https://github.com/jsdom/jsdom/issues/1721#issuecomment-1484202038
    // jsdom URL and Blob are missing most of the implementation
    // Use the node version of these types instead
    this.global.URL = URL;
    this.global.Blob = Blob;
  }
}
