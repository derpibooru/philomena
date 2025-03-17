/**
 * Matched string is represented as an array of parts that matched and parts that didn't.
 * It is designed to be this much generic to allow for matches in random places in case
 * if we decide to support more complex matching.
 *
 * String parts that didn't match are represented as primitive strings. String parts
 * that matched are represented as objects with a `matched` property.
 */
export type MatchPart = string | { matched: string };

interface CanonicalTagSuggestion {
  /**
   * No alias name is present for the canonical tag. It's declared here explicitly
   * to make TypeScript pick up this field as the tagged union discriminator.
   */
  alias?: undefined;

  /**
   * The canonical name of the tag (non-alias).
   */
  canonical: MatchPart[];

  /**
   * Number of images tagged with this tag.
   */
  images: number;
}

interface AliasTagSuggestion {
  /**
   * The alias name of the tag.
   */
  alias: MatchPart[];

  /**
   * The canonical tag the alias points to.
   */
  canonical: string;

  /**
   * Number of images tagged with this tag.
   */
  images: number;
}

export type TagSuggestion = CanonicalTagSuggestion | AliasTagSuggestion;

/**
 * Infers where the prefix match occurred in the target string according to
 * the given prefix. It assumes that `target` either starts with `prefix` or
 * contains the `prefix` after the namespace separator.
 */
export function prefixMatchParts(target: string, prefix: string): MatchPart[] {
  return prefixMatchPartsImpl(target, prefix).filter(part => typeof part !== 'string' || part.length > 0);
}

function prefixMatchPartsImpl(target: string, prefix: string): MatchPart[] {
  const targetLower = target.toLowerCase();
  const prefixLower = prefix.toLowerCase();

  if (targetLower.startsWith(prefixLower)) {
    const matched = target.slice(0, prefix.length);
    return [{ matched }, target.slice(matched.length)];
  }

  const separator = target.indexOf(':');
  if (separator < 0) {
    return [target];
  }

  const matchStart = separator + 1;

  return [
    target.slice(0, matchStart),
    { matched: target.slice(matchStart, matchStart + prefix.length) },
    target.slice(matchStart + prefix.length),
  ];
}
