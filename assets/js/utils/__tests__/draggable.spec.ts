import { initDraggables } from '../draggable';
import { fireEvent } from '@testing-library/dom';
import { getRandomArrayItem } from '../../../test/randomness';

describe('Draggable Utilities', () => {
  // jsdom lacks proper support for window.DragEvent so this is an attempt at a minimal recreation
  const createDragEvent = (name: string, init?: DragEventInit): DragEvent => {
    const mockEvent = new Event(name, { bubbles: true, cancelable: true }) as unknown as DragEvent;
    let dataTransfer = init?.dataTransfer;
    if (!dataTransfer) {
      const items: Pick<DataTransferItem, 'type' | 'getAsString'>[] = [];
      dataTransfer = {
        items: items as unknown as DataTransferItemList,
        setData(format: string, data: string) {
          items.push({ type: format, getAsString: (callback: FunctionStringCallback) => callback(data) });
        }
      } as unknown as DataTransfer;
    }
    Object.assign(mockEvent, { dataTransfer });
    return mockEvent;
  };

  const createDraggableElement = (): HTMLDivElement => {
    const el = document.createElement('div');
    el.setAttribute('draggable', 'true');
    return el;
  };

  describe('initDraggables', () => {
    const draggingClass = 'dragging';
    const dragContainerClass = 'drag-container';
    const dragOverClass = 'over';
    let documentEventListenerSpy: jest.SpyInstance;

    let mockDragContainer: HTMLDivElement;
    let mockDraggable: HTMLDivElement;

    beforeEach(() => {
      mockDragContainer = document.createElement('div');
      mockDragContainer.classList.add(dragContainerClass);
      document.body.appendChild(mockDragContainer);

      mockDraggable = createDraggableElement();
      mockDragContainer.appendChild(mockDraggable);


      // Redirect all document event listeners to this element for easier cleanup
      documentEventListenerSpy = jest.spyOn(document, 'addEventListener').mockImplementation((...params) => {
        mockDragContainer.addEventListener(...params);
      });
    });

    afterEach(() => {
      document.body.removeChild(mockDragContainer);
      documentEventListenerSpy.mockRestore();
    });

    describe('dragStart', () => {
      it('should add the dragging class to the element that starts moving', () => {
        initDraggables();

        const mockEvent = createDragEvent('dragstart');

        fireEvent(mockDraggable, mockEvent);

        expect(mockDraggable).toHaveClass(draggingClass);
      });

      it('should add dummy data to the dragstart event if it\'s empty', () => {
        initDraggables();

        const mockEvent = createDragEvent('dragstart');
        expect(mockEvent.dataTransfer?.items).toHaveLength(0);

        fireEvent(mockDraggable, mockEvent);

        expect(mockEvent.dataTransfer?.items).toHaveLength(1);

        const dataTransferItem = (mockEvent.dataTransfer as DataTransfer).items[0];
        expect(dataTransferItem.type).toEqual('text/plain');

        let stringValue: string | undefined;
        dataTransferItem.getAsString(value => {
          stringValue = value;
        });
        expect(stringValue).toEqual('');
      });

      it('should keep data in the dragstart event if it\'s present', () => {
        initDraggables();

        const mockTransferItemType = getRandomArrayItem(['text/javascript', 'image/jpg', 'application/json']);
        const mockDataTransferItem: DataTransferItem = {
          type: mockTransferItemType,
        } as unknown as DataTransferItem;

        const mockEvent = createDragEvent('dragstart', { dataTransfer: { items: [mockDataTransferItem] as unknown as DataTransferItemList } } as DragEventInit);
        expect(mockEvent.dataTransfer?.items).toHaveLength(1);

        fireEvent(mockDraggable, mockEvent);

        expect(mockEvent.dataTransfer?.items).toHaveLength(1);

        const dataTransferItem = (mockEvent.dataTransfer as DataTransfer).items[0];
        expect(dataTransferItem.type).toEqual(mockTransferItemType);
      });

      it('should set the allowed effect to move on the data transfer', () => {
        initDraggables();

        const mockEvent = createDragEvent('dragstart');
        expect(mockEvent.dataTransfer?.effectAllowed).toBeFalsy();

        fireEvent(mockDraggable, mockEvent);

        expect(mockEvent.dataTransfer?.effectAllowed).toEqual('move');
      });
    });

    describe('dragOver', () => {
      it('should cancel event and set the drop effect to move on the data transfer', () => {
        initDraggables();

        const mockEvent = createDragEvent('dragover');

        fireEvent(mockDraggable, mockEvent);

        expect(mockEvent.defaultPrevented).toBe(true);
        expect(mockEvent.dataTransfer?.dropEffect).toEqual('move');
      });
    });

    describe('dragEnter', () => {
      it('should add the over class to the target', () => {
        initDraggables();

        const mockEvent = createDragEvent('dragenter');

        fireEvent(mockDraggable, mockEvent);

        expect(mockDraggable).toHaveClass(dragOverClass);
      });
    });

    describe('dragLeave', () => {
      it('should remove the over class from the target', () => {
        initDraggables();

        mockDraggable.classList.add(dragOverClass);
        const mockEvent = createDragEvent('dragleave');

        fireEvent(mockDraggable, mockEvent);

        expect(mockDraggable).not.toHaveClass(dragOverClass);
      });
    });

    describe('drop', () => {
      it('should cancel the event and remove dragging class if dropped on same element', () => {
        initDraggables();

        const mockStartEvent = createDragEvent('dragstart');
        fireEvent(mockDraggable, mockStartEvent);

        expect(mockDraggable).toHaveClass(draggingClass);

        const mockDropEvent = createDragEvent('drop');
        fireEvent(mockDraggable, mockDropEvent);

        expect(mockDropEvent.defaultPrevented).toBe(true);
        expect(mockDraggable).not.toHaveClass(draggingClass);
      });

      it('should cancel the event and insert source before target if dropped on left side', () => {
        initDraggables();

        const mockSecondDraggable = createDraggableElement();
        mockDragContainer.appendChild(mockSecondDraggable);

        const mockStartEvent = createDragEvent('dragstart');
        fireEvent(mockSecondDraggable, mockStartEvent);

        expect(mockSecondDraggable).toHaveClass(draggingClass);

        const mockDropEvent = createDragEvent('drop');
        Object.assign(mockDropEvent, { clientX: 124 });
        const boundingBoxSpy = jest.spyOn(mockDraggable, 'getBoundingClientRect').mockReturnValue({
          left: 100,
          width: 50,
        } as unknown as DOMRect);
        fireEvent(mockDraggable, mockDropEvent);

        try {
          expect(mockDropEvent.defaultPrevented).toBe(true);
          expect(mockSecondDraggable).not.toHaveClass(draggingClass);
          expect(mockSecondDraggable.nextElementSibling).toBe(mockDraggable);
        }
        finally {
          boundingBoxSpy.mockRestore();
        }
      });

      it('should cancel the event and insert source after target if dropped on right side', () => {
        initDraggables();

        const mockSecondDraggable = createDraggableElement();
        mockDragContainer.appendChild(mockSecondDraggable);

        const mockStartEvent = createDragEvent('dragstart');
        fireEvent(mockSecondDraggable, mockStartEvent);

        expect(mockSecondDraggable).toHaveClass(draggingClass);

        const mockDropEvent = createDragEvent('drop');
        Object.assign(mockDropEvent, { clientX: 125 });
        const boundingBoxSpy = jest.spyOn(mockDraggable, 'getBoundingClientRect').mockReturnValue({
          left: 100,
          width: 50,
        } as unknown as DOMRect);
        fireEvent(mockDraggable, mockDropEvent);

        try {
          expect(mockDropEvent.defaultPrevented).toBe(true);
          expect(mockSecondDraggable).not.toHaveClass(draggingClass);
          expect(mockDraggable.nextElementSibling).toBe(mockSecondDraggable);
        }
        finally {
          boundingBoxSpy.mockRestore();
        }
      });
    });

    describe('dragEnd', () => {
      it('should remove dragging class from source and over class from target\'s descendants', () => {
        initDraggables();

        const mockStartEvent = createDragEvent('dragstart');
        fireEvent(mockDraggable, mockStartEvent);

        expect(mockDraggable).toHaveClass(draggingClass);

        const mockOverElement = createDraggableElement();
        mockOverElement.classList.add(dragOverClass);
        mockDraggable.parentNode?.appendChild(mockOverElement);
        const mockOverEvent = createDragEvent('dragend');
        fireEvent(mockOverElement, mockOverEvent);

        const mockDropEvent = createDragEvent('dragend');
        fireEvent(mockDraggable, mockDropEvent);

        expect(mockDraggable).not.toHaveClass(draggingClass);
        expect(mockOverElement).not.toHaveClass(dragOverClass);
      });
    });

    describe('wrapper', () => {
      it('should do nothing when event target has no closest method', () => {
        initDraggables();

        const mockEvent = createDragEvent('dragstart');
        Object.assign(mockDraggable, { closest: undefined });

        fireEvent(mockDraggable, mockEvent);

        expect(mockEvent.dataTransfer?.effectAllowed).toBeFalsy();
      });

      it('should do nothing when event target does not have a parent matching the predefined selector', () => {
        initDraggables();

        const mockEvent = createDragEvent('dragstart');
        const documentClosestSpy = jest.spyOn(mockDraggable, 'closest').mockReturnValue(null);

        try {
          fireEvent(mockDraggable, mockEvent);

          expect(mockEvent.dataTransfer?.effectAllowed).toBeFalsy();
        }
        finally {
          documentClosestSpy.mockRestore();
        }
      });
    });
  });
});
