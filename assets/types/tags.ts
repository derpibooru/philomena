export {};

declare global {
  interface Addtag {
    name: string;
  }

  interface AddtagEvent extends CustomEvent<Addtag> {
    target: HTMLInputElement | HTMLTextAreaElement;
  }

  interface ReloadEvent extends CustomEvent {
    target: HTMLInputElement | HTMLTextAreaElement;
  }

  interface GlobalEventHandlersEventMap {
    addtag: AddtagEvent;
    reload: ReloadEvent;
  }
}
