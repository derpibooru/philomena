export {};

declare global {
  interface FetchcompleteEvent extends CustomEvent<Response> {
    target: HTMLElement,
  }

  interface GlobalEventHandlersEventMap {
    fetchcomplete: FetchcompleteEvent;
  }
}
