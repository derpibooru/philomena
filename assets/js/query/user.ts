import { Interaction, InteractionType, InteractionValue } from '../../types/booru-object';
import { FieldMatcher } from './types';

function interactionMatch(
  imageId: number,
  type: InteractionType,
  value: InteractionValue,
  interactions: Interaction[],
): boolean {
  return interactions.some(
    v => v.image_id === imageId && v.interaction_type === type && (value === null || v.value === value),
  );
}

export function makeUserMatcher(term: string): FieldMatcher {
  // Should work with most my:conditions except watched.
  return (_value, _field, documentId) => {
    switch (term) {
      case 'faves':
        return interactionMatch(documentId, 'faved', null, window.booru.interactions);
      case 'upvotes':
        return interactionMatch(documentId, 'voted', 'up', window.booru.interactions);
      case 'downvotes':
        return interactionMatch(documentId, 'voted', 'down', window.booru.interactions);
      case 'watched':
      case 'hidden':
      default:
        // Other my: interactions aren't supported, return false to prevent them from triggering spoiler.
        return false;
    }
  };
}
