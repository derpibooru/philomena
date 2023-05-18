type SpoilerType = 'click' | 'hover' | 'static' | 'off';

interface BooruObject {
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
   * SearchAST instance for hidden tags, converted from raw AST data in {@see import('../js/booru.js')}
   *
   * TODO Properly type after TypeScript migration
   *
   * @type {import('../js/match_query.js').SearchAST}
   */
  hiddenFilter: unknown;
  /**
   * SearchAST instance for spoilered tags, converted from raw AST data in {@see import('../js/booru.js')}
   *
   * TODO Properly type after TypeScript migration
   *
   * @type {import('../js/match_query.js').SearchAST}
   */
  spoileredFilter: unknown;
  tagsVersion: number;
}

interface Window {
  booru: BooruObject;
}
