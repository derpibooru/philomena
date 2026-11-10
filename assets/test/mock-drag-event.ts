import { vi } from 'vitest';

// jsdom doesn't implement DragEvent
// This is a minimal implementation that allows us to test drag-and-drop
class MockDragEvent extends Event {
  dataTransfer: DataTransfer;

  constructor(type: string, options: DragEventInit = {}) {
    super(type, options);

    if ('dataTransfer' in options) {
      this.dataTransfer = options.dataTransfer as DataTransfer;
    } else {
      const items: Pick<DataTransferItem, 'type' | 'getAsString'>[] = [];
      this.dataTransfer = {
        items: items as unknown as DataTransferItemList,
        setData(format: string, data: string) {
          items.push({ type: format, getAsString: (callback: FunctionStringCallback) => callback(data) });
        },
      } as unknown as DataTransfer;
    }
  }
}

vi.stubGlobal('DragEvent', MockDragEvent);
