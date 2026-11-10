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

const propertiesSyntaxRegExp =
  /^(?<property_name>[a-z\d_]+)(?<operator_syntax>\.(?<operator>[a-z]*))?(?<value_syntax>:(?<value>.*))?$/;

export interface MatchedPropertyParts {
  propertyName: string;
  hasOperatorSyntax: boolean;
  hasValueSyntax: boolean;
  operator?: string;
  value?: string;
}

function parsePropertyParts(term: string): MatchedPropertyParts | null {
  propertiesSyntaxRegExp.lastIndex = 0;

  const match = propertiesSyntaxRegExp.exec(term);

  if (!match?.groups) {
    return null;
  }

  return {
    propertyName: match.groups.property_name,
    hasOperatorSyntax: Boolean(match.groups.operator_syntax),
    hasValueSyntax: Boolean(match.groups.value_syntax),
    operator: match.groups.operator,
    value: match.groups.value,
  };
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
  let propertiesMap = searchTypeToPropertiesMap.get(input.element.name);
  const parsedTermParts = propertiesMap && parsePropertyParts(activeTerm);

  if (!propertiesMap || !parsedTermParts) {
    return [];
  }

  propertiesMap = filterPropertiesMapByCurrentRole(propertiesMap);

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
