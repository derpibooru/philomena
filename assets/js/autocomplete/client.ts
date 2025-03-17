import { HttpClient } from '../utils/http-client.ts';

export interface TagSuggestion {
  /**
   * If present, then this suggestion is for a tag alias.
   * If absent, then this suggestion is for the `canonical` tag name.
   */
  alias?: null | string;

  /**
   * The canonical name of the tag (non-alias).
   */
  canonical: string;

  /**
   * Number of images tagged with this tag.
   */
  images: number;
}

export interface GetTagSuggestionsResponse {
  suggestions: TagSuggestion[];
}

export interface GetTagSuggestionsRequest {
  /**
   * Term to complete.
   */
  term: string;

  /**
   * Maximum number of suggestions to return.
   */
  limit: number;
}

/**
 * Autocomplete API client for Philomena backend.
 */
export class AutocompleteClient {
  private http: HttpClient = new HttpClient();

  /**
   * Fetches server-side tag suggestions for the given term. The provided incomplete
   * term is expected to be normalized by the caller (i.e. lowercased and trimmed).
   * This is because the caller is responsible for caching the normalized term.
   */
  async getTagSuggestions(request: GetTagSuggestionsRequest): Promise<GetTagSuggestionsResponse> {
    return this.http.fetchJson('/autocomplete/tags', {
      query: {
        vsn: '2',
        term: request.term,
        limit: request.limit.toString(),
      },
    });
  }

  /**
   * Issues a GET request to fetch the compiled autocomplete index.
   */
  async getCompiledAutocomplete(): Promise<ArrayBuffer> {
    const now = new Date();
    const key = `${now.getUTCFullYear()}-${now.getUTCMonth()}-${now.getUTCDate()}`;

    const response = await this.http.fetch(`/autocomplete/compiled`, {
      query: { vsn: '2', key },
      credentials: 'omit',
      cache: 'force-cache',
    });

    return response.arrayBuffer();
  }
}
