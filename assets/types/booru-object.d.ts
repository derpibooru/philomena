import { AstMatcher } from 'query/types';

type SpoilerType = 'click' | 'hover' | 'static' | 'off';

type InteractionType = 'voted' | 'faved' | 'hidden';
type InteractionValue = 'up' | 'down' | null;

interface Interaction {
  image_id: number;
  user_id: number;
  interaction_type: InteractionType;
  value: 'up' | 'down' | null;
}

interface BooruObject {
  /**
   * Automatic timestamp recalculation function for userscript use
   */
  timeAgo: (args: HTMLTimeElement[]) => void;
  /**
   * Anti-forgery token sent by the server
   */
  csrfToken: string;
  /**
   * One of the specified values, based on user setting
   */
  spoilerType: SpoilerType;
  /**
   * List of numeric image IDs as strings
   */
  imagesWithDownvotingDisabled: string[];
  /**
   * Array of watched tag IDs as numbers
   */
  watchedTagList: number[];
  /**
   * Array of spoilered tag IDs as numbers
   */
  spoileredTagList: number[];
  /**
   * Array of ignored tag IDs as numbers
   */
  ignoredTagList: number[];
  /**
   * Array of hidden tag IDs as numbers
   */
  hiddenTagList: number[];
  /**
   * Stores the URL of the default "tag blocked" image
   */
  hiddenTag: string;
  userIsSignedIn: boolean;
  /**
   * Indicates if the current user has edit rights to the currently selected filter
   */
  userCanEditFilter: boolean;
  /**
   * AST matcher instance for filter hidden query
   *
   */
  hiddenFilter: AstMatcher;
  /**
   * AST matcher instance for filter spoilered query
   */
  spoileredFilter: AstMatcher;
  tagsVersion: number;
  interactions: Interaction[];
  /**
   * Indicates whether sensitive staff-only info should be hidden or not.
   */
  hideStaffTools: string;
  /**
   * List of image IDs in the current gallery.
   */
  galleryImages?: number[];
}

declare global {
  interface Window {
    booru: BooruObject;
  }
}
