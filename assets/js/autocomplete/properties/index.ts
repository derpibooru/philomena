import { AutocompletableInput } from '../input';
import {
  moderationPropertiesSet,
  propertyTypeOperators,
  PropertyTypeOrValues,
  searchTypeToPropertiesMap,
  tagProperty,
} from './maps';
import { type LocalAutocompleter } from '../../utils/local-autocompleter';
import { type TagSuggestion } from '../../utils/suggestions-model';

const propertyNamesRegExp = /^[a-z\d_.]+$/;

export interface MatchedPropertyParts {
  propertyName: string;
  hasOperatorSyntax: boolean;
  hasValueSyntax: boolean;
  operator?: string;
  value?: string;
}

/**
 * Parse property parts from the single term.
 *
 * @since 1.3.0 Properties now could contain the dot in the name, confusing previous RegExp-based parsing.
 *
 * @param term Tern to parse.
 * @param propertiesMap Mapping of properties to match the names from.
 */
function parsePropertyParts(
  term: string,
  propertiesMap: Map<string, PropertyTypeOrValues>,
): MatchedPropertyParts | null {
  propertyNamesRegExp.lastIndex = 0;

  const valueSeparatorIndex = term.indexOf(':');
  const hasValueSyntax = valueSeparatorIndex >= 0;
  const namePart = hasValueSyntax ? term.slice(0, valueSeparatorIndex) : term;
  const value = hasValueSyntax ? term.slice(valueSeparatorIndex + 1) : undefined;

  if (!propertyNamesRegExp.test(namePart)) {
    return null;
  }

  if (propertiesMap.has(namePart)) {
    return { propertyName: namePart, hasOperatorSyntax: false, hasValueSyntax, value };
  }

  const lastDotIndex = namePart.lastIndexOf('.');

  if (lastDotIndex > 0) {
    const head = namePart.slice(0, lastDotIndex);
    const operator = namePart.slice(lastDotIndex + 1);

    if (propertiesMap.has(head)) {
      return { propertyName: head, hasOperatorSyntax: true, hasValueSyntax, operator, value };
    }
  }

  return { propertyName: namePart, hasOperatorSyntax: false, hasValueSyntax, value };
}

export class SuggestedProperty {
  readonly matchedParts: MatchedPropertyParts;
  /**
   * Name of the property.
   */
  readonly name: string;
  readonly type: symbol | null = null;
  operator: string | null;
  value: string | null;

  constructor(
    matchedParts: MatchedPropertyParts,
    name: string,
    type: symbol | null = null,
    operator: string | null = null,
    value: string | null = null,
  ) {
    this.matchedParts = matchedParts;
    this.name = name;
    this.type = type;
    this.operator = operator;
    this.value = value;
  }

  /**
   * Check if this suggested property contains colon (`:`) character. This usually means that user started typing value
   * or typed the colon itself.
   */
  containsColon(): boolean {
    return this.operator !== null || this.value !== null;
  }

  calculateMatchedLength(): number {
    let matchedLength = this.matchedParts.propertyName.length;

    if (this.matchedParts.hasOperatorSyntax && this.operator) {
      // Include "." into matched highlighted part.
      matchedLength += 1;

      if (this.matchedParts.operator) {
        matchedLength += this.matchedParts.operator.length;
      }
    }

    if (this.matchedParts.hasValueSyntax && (this.containsColon() || this.value)) {
      // Include ":" into matched highlighted part.
      matchedLength += 1;

      if (this.matchedParts.value) {
        matchedLength += this.matchedParts.value.length;
      }
    }

    return matchedLength;
  }

  toString(): string {
    let resultValue = this.name;

    if (this.operator) {
      resultValue += `.${this.operator}`;
    }

    // Making sure to include the colon when operator or value is provided. When empty operator is passed, then it
    // indicates that colon should be included.
    if (this.containsColon()) {
      resultValue += ':';
    }

    if (this.value) {
      resultValue += this.value;
    }

    return resultValue;
  }
}

function resolveCanonicalTagNameFromSuggestion(suggestion: TagSuggestion): string {
  if (typeof suggestion.canonical === 'string') {
    return suggestion.canonical;
  }

  return suggestion.canonical
    .map(matchPart => (typeof matchPart === 'string' ? matchPart : matchPart.matched))
    .join('');
}

const moderationRoles = ['admin', 'moderator', 'assistant'];
const filteredMaps = new Map<Map<string, PropertyTypeOrValues>, Map<string, PropertyTypeOrValues>>();

/**
 * Check the current user role and remove the moderation-related properties from suggestions if user has no access to
 * them.
 *
 * @param originalPropertiesMap Map of properties resolved from the input field. Contains both usual and moderation-only
 * properties.
 */
function filterPropertiesMapByCurrentRole(
  originalPropertiesMap: Map<string, PropertyTypeOrValues>,
): Map<string, PropertyTypeOrValues> {
  if (window.booru.userRole && moderationRoles.includes(window.booru.userRole) && !window.booru.hideStaffTools) {
    return originalPropertiesMap;
  }

  const storedPropertiesMap = filteredMaps.get(originalPropertiesMap);

  if (storedPropertiesMap) {
    return storedPropertiesMap;
  }

  const resultPropertiesMap = new Map(
    Array.from(originalPropertiesMap.entries()).filter(([propertyName]) => !moderationPropertiesSet.has(propertyName)),
  );

  filteredMaps.set(originalPropertiesMap, resultPropertiesMap);

  return resultPropertiesMap;
}

/**
 * Create the list of suggested properties from an active term.
 *
 * @param input Input matching was called from. Input is required to determine which list of properties should be
 * suggested. It's also used for suggesting tags inside tag-properties.
 * @param activeTerm Actual term parsed from the search query. This is the string which will be used to find relevant
 * properties.
 * @param autocomplete Instance of {@link LocalAutocompleter} used for several properties related to tags.
 *
 * @return List of suggested properties for displaying to the user.
 */
export function matchProperties(
  input: AutocompletableInput,
  activeTerm: string,
  autocomplete: LocalAutocompleter,
): SuggestedProperty[] {
  const foundPropertiesMap = searchTypeToPropertiesMap.get(input.element.name);

  if (!foundPropertiesMap) {
    return [];
  }

  const propertiesMap = filterPropertiesMapByCurrentRole(foundPropertiesMap);
  const parsedTermParts = parsePropertyParts(activeTerm, propertiesMap);

  if (!parsedTermParts) {
    return [];
  }

  const { hasOperatorSyntax, hasValueSyntax, propertyName, operator, value } = parsedTermParts;

  // If both operator and value aren't typed by the user yet, then we just need to find all prefix-matched property
  // names from the mapping.
  if (!hasOperatorSyntax && !hasValueSyntax) {
    return Array.from(propertiesMap.keys())
      .filter(suggestedPropertyName => suggestedPropertyName.startsWith(propertyName))
      .map(suggestedPropertyName => new SuggestedProperty(parsedTermParts, suggestedPropertyName));
  }

  const targetPropertyTypeOrValues = propertiesMap.get(propertyName);

  // No properties matched, nothing to suggest.
  if (!targetPropertyTypeOrValues) {
    return [];
  }

  // First, we need to handle simple case of property having limited list of values it could query.
  if (Array.isArray(targetPropertyTypeOrValues)) {
    // Properties which only could contain specific list of values (like special values in my:* property or boolean
    // properties) could not use any operators. In this case we just don't suggest anything, since property is likely
    // to be invalid.
    if (hasOperatorSyntax) {
      return [];
    }

    return targetPropertyTypeOrValues
      .filter(suggestedValue => !value || suggestedValue.startsWith(value))
      .map(suggestedValue => new SuggestedProperty(parsedTermParts, propertyName, null, null, suggestedValue));
  }

  // For the properties which accept tags as values, make additional autocomplete call.
  if (targetPropertyTypeOrValues === tagProperty && value) {
    const matchedTagsResult = autocomplete
      .matchPrefix(value, input.maxSuggestions)
      .map(
        tagSuggestion =>
          new SuggestedProperty(
            parsedTermParts,
            propertyName,
            targetPropertyTypeOrValues,
            null,
            resolveCanonicalTagNameFromSuggestion(tagSuggestion),
          ),
      );

    if (!matchedTagsResult.length) {
      matchedTagsResult.push(
        new SuggestedProperty(parsedTermParts, propertyName, targetPropertyTypeOrValues, null, value),
      );
    }

    return matchedTagsResult;
  }

  const availableOperators = propertyTypeOperators.get(targetPropertyTypeOrValues) || [];

  // In case we have operators to suggest, try to find and show them first.
  const suggestionsWithOperators = availableOperators
    .filter(suggestedOperator => !operator || suggestedOperator.startsWith(operator))
    .map(
      suggestedOperator =>
        new SuggestedProperty(
          parsedTermParts,
          propertyName,
          targetPropertyTypeOrValues,
          suggestedOperator,
          value || '',
        ),
    );

  // If user haven't started typing operator yet, then also suggest the variant without any operators.
  if (!hasOperatorSyntax) {
    suggestionsWithOperators.unshift(
      new SuggestedProperty(parsedTermParts, propertyName, targetPropertyTypeOrValues, '', value || ''),
    );
  }

  return suggestionsWithOperators;
}
