/**
* booru.match_query: A port and modification of the search_parser library for
* performing client-side filtering.
*/

const tokenList = [
        ['fuzz', /^~(?:\d+(\.\d+)?|\.\d+)/],
        ['boost', /^\^[\-\+]?\d+(\.\d+)?/],
        ['quoted_lit', /^\s*"(?:(?:[^"]|\\")+)"/],
        ['lparen', /^\s*\(\s*/],
        ['rparen', /^\s*\)\s*/],
        ['and_op', /^\s*(?:\&\&|AND)\s+/],
        ['and_op', /^\s*,\s*/],
        ['or_op', /^\s*(?:\|\||OR)\s+/],
        ['not_op', /^\s*NOT(?:\s+|(?=\())/],
        ['not_op', /^\s*[\!\-]\s*/],
        ['space', /^\s+/],
        ['word', /^(?:[^\s,\(\)\^~]|\\[\s,\(\)\^~])+/],
        ['word', /^(?:[^\s,\(\)]|\\[\s,\(\)])+/]
      ],
      numberFields = ['id', 'width', 'height', 'aspect_ratio',
        'comment_count', 'score', 'upvotes', 'downvotes',
        'faves', 'tag_count'],
      dateFields = ['created_at'],
      literalFields = ['tags', 'orig_sha512_hash', 'sha512_hash',
        'score', 'uploader', 'source_url', 'description'],
      termSpaceToImageField = {
        tags: 'data-image-tag-aliases',
        score: 'data-score',
        upvotes: 'data-upvotes',
        downvotes: 'data-downvotes',
        uploader: 'data-uploader',
        // Yeah, I don't think this is reasonably supportable.
        // faved_by: 'data-faved-by',
        id: 'data-image-id',
        width: 'data-width',
        height: 'data-height',
        aspect_ratio: 'data-aspect-ratio',
        comment_count: 'data-comment-count',
        tag_count: 'data-tag-count',
        source_url: 'data-source-url',
        faves: 'data-faves',
        sha512_hash: 'data-sha512',
        orig_sha512_hash: 'data-orig-sha512',
        created_at: 'data-created-at'
      };


function SearchTerm(termStr, options) {
  this.term = termStr.trim();
  this.parsed = false;
}

SearchTerm.prototype.append = function(substr) {
  this.term += substr;
  this.parsed = false;
};

SearchTerm.prototype.parseRangeField = function(field) {
  let qual;

  if (numberFields.indexOf(field) !== -1) {
    return [field, 'eq', 'number'];
  }

  if (dateFields.indexOf(field) !== -1) {
    return [field, 'eq', 'date'];
  }

  qual = /^(\w+)\.([lg]te?|eq)$/.exec(field);

  if (qual) {
    if (numberFields.indexOf(qual[1]) !== -1) {
      return [qual[1], qual[2], 'number'];
    }

    if (dateFields.indexOf(qual[1]) !== -1) {
      return [qual[1], qual[2], 'date'];
    }
  }

  return null;
};

SearchTerm.prototype.parseRelativeDate = function(dateVal, qual) {
  const match = /(\d+) (second|minute|hour|day|week|month|year)s? ago/.exec(dateVal);
  const bounds = {
    second: 1000,
    minute: 60000,
    hour: 3600000,
    day: 86400000,
    week: 604800000,
    month: 2592000000,
    year: 31536000000
  };

  if (match) {
    const amount = parseInt(match[1], 10);
    const scale = bounds[match[2]];

    const now = new Date().getTime();
    const bottomDate = new Date(now - (amount * scale));
    const topDate = new Date(now - ((amount - 1) * scale));

    switch (qual) {
      case 'lte':
        return [bottomDate, 'lt'];
      case 'gte':
        return [bottomDate, 'gte'];
      case 'lt':
        return [bottomDate, 'lt'];
      case 'gt':
        return [bottomDate, 'gte'];
      default:
        return [[bottomDate, topDate], 'eq'];
    }
  }
  else {
    throw `Cannot parse date string: ${dateVal}`;
  }
};

SearchTerm.prototype.parseAbsoluteDate = function(dateVal, qual) {
  let parseRes = [
        /^(\d{4})/,
        /^\-(\d{2})/,
        /^\-(\d{2})/,
        /^(?:\s+|T|t)(\d{2})/,
        /^:(\d{2})/,
        /^:(\d{2})/
      ],
      timeZoneOffset = [0, 0],
      timeData = [0, 0, 1, 0, 0, 0],
      bottomDate = null,
      topDate = null,
      i,
      match,
      origDateVal = dateVal;

  match = /([\+\-])(\d{2}):(\d{2})$/.exec(dateVal);
  if (match) {
    timeZoneOffset[0] = parseInt(match[2], 10);
    timeZoneOffset[1] = parseInt(match[3], 10);
    if (match[1] === '-') {
      timeZoneOffset[0] *= -1;
      timeZoneOffset[1] *= -1;
    }
    dateVal = dateVal.substr(0, dateVal.length - 6);
  }
  else {
    dateVal = dateVal.replace(/[Zz]$/, '');
  }

  for (i = 0; i < parseRes.length; i += 1) {
    if (dateVal.length === 0) {
      break;
    }

    match = parseRes[i].exec(dateVal);
    if (match) {
      if (i === 1) {
        timeData[i] = parseInt(match[1], 10) - 1;
      }
      else {
        timeData[i] = parseInt(match[1], 10);
      }
      dateVal = dateVal.substr(
        match[0].length, dateVal.length - match[0].length
      );
    }
    else {
      throw `Cannot parse date string: ${origDateVal}`;
    }
  }

  if (dateVal.length > 0) {
    throw `Cannot parse date string: ${origDateVal}`;
  }

  // Apply the user-specified time zone offset. The JS Date constructor
  // is very flexible here.
  timeData[3] -= timeZoneOffset[0];
  timeData[4] -= timeZoneOffset[1];

  switch (qual) {
    case 'lte':
      timeData[i - 1] += 1;
      return [Date.UTC.apply(Date, timeData), 'lt'];
    case 'gte':
      return [Date.UTC.apply(Date, timeData), 'gte'];
    case 'lt':
      return [Date.UTC.apply(Date, timeData), 'lt'];
    case 'gt':
      timeData[i - 1] += 1;
      return [Date.UTC.apply(Date, timeData), 'gte'];
    default:
      bottomDate = Date.UTC.apply(Date, timeData);
      timeData[i - 1] += 1;
      topDate = Date.UTC.apply(Date, timeData);
      return [[bottomDate, topDate], 'eq'];
  }
};

SearchTerm.prototype.parseDate = function(dateVal, qual) {
  try {
    return this.parseAbsoluteDate(dateVal, qual);
  }
  catch (_) {
    return this.parseRelativeDate(dateVal, qual);
  }
};

SearchTerm.prototype.parse = function(substr) {
  let matchArr,
      rangeParsing,
      candidateTermSpace,
      termCandidate;

  this.wildcardable = !this.fuzz && !/^"([^"]|\\")+"$/.test(this.term);

  if (!this.wildcardable && !this.fuzz) {
    this.term = this.term.substr(1, this.term.length - 2);
  }

  this.term = this._normalizeTerm();

  // N.B.: For the purposes of this parser, boosting effects are ignored.

  // Default.
  this.termSpace = 'tags';
  this.termType = 'literal';

  matchArr = this.term.split(':');

  if (matchArr.length > 1) {
    candidateTermSpace = matchArr[0];
    termCandidate = matchArr.slice(1).join(':');
    rangeParsing = this.parseRangeField(candidateTermSpace);

    if (rangeParsing) {
      this.termSpace = rangeParsing[0];
      this.termType = rangeParsing[2];

      if (this.termType === 'date') {
        rangeParsing = this.parseDate(termCandidate, rangeParsing[1]);
        this.term = rangeParsing[0];
        this.compare = rangeParsing[1];
      }
      else {
        this.term = parseFloat(termCandidate);
        this.compare = rangeParsing[1];
      }

      this.wildcardable = false;
    }
    else if (literalFields.indexOf(candidateTermSpace) !== -1) {
      this.termType = 'literal';
      this.term = termCandidate;
      this.termSpace = candidateTermSpace;
    }
    else if (candidateTermSpace == 'my') {
      this.termType = 'my';
      this.termSpace = termCandidate;
    }
  }

  if (this.wildcardable) {
    // Transforms wildcard match into regular expression.
    // A custom NFA with caching may be more sophisticated but not
    // likely to be faster.
    this.term = new RegExp(
      `^${
        this.term.replace(/([.+^$[\]\\(){}|-])/g, '\\$1')
          .replace(/([^\\]|[^\\](?:\\\\)+)\*/g, '$1.*')
          .replace(/^(?:\\\\)*\*/g, '.*')
          .replace(/([^\\]|[^\\](?:\\\\)+)\?/g, '$1.?')
          .replace(/^(?:\\\\)*\?/g, '.?')
      }$`, 'i'
    );
  }

  // Update parse status flag to indicate the new properties are ready.
  this.parsed = true;
};

SearchTerm.prototype._normalizeTerm = function() {
  if (!this.wildcardable) {
    return this.term.replace('\"', '"');
  }
  return this.term.replace(/\\([^\*\?])/g, '$1');
};

SearchTerm.prototype.fuzzyMatch = function(targetStr) {
  let targetDistance,
      i,
      j,
      // Work vectors, representing the last three populated
      // rows of the dynamic programming matrix of the iterative
      // optimal string alignment calculation.
      v0 = [],
      v1 = [],
      v2 = [],
      temp;

  if (this.fuzz < 1.0) {
    targetDistance = targetStr.length * (1.0 - this.fuzz);
  }
  else {
    targetDistance = this.fuzz;
  }

  targetStr = targetStr.toLowerCase();

  for (i = 0; i <= targetStr.length; i += 1) {
    v1.push(i);
  }

  for (i = 0; i < this.term.length; i += 1) {
    v2[0] = i;
    for (j = 0; j < targetStr.length; j += 1) {
      const cost = this.term[i] === targetStr[j] ? 0 : 1;
      v2[j + 1] = Math.min(
        // Deletion.
        v1[j + 1] + 1,
        // Insertion.
        v2[j] + 1,
        // Substitution or No Change.
        v1[j] + cost
      );
      if (i > 1 && j > 1 && this.term[i] === targetStr[j - 1] &&
                    targetStr[i - 1] === targetStr[j]) {
        v2[j + 1] = Math.min(v2[j], v0[j - 1] + cost);
      }
    }
    // Rotate dem vec pointers bra.
    temp = v0;
    v0 = v1;
    v1 = v2;
    v2 = temp;
  }

  return v1[targetStr.length] <= targetDistance;
};

SearchTerm.prototype.exactMatch = function(targetStr) {
  return this.term.toLowerCase() === targetStr.toLowerCase();
};

SearchTerm.prototype.wildcardMatch = function(targetStr) {
  return this.term.test(targetStr);
};

SearchTerm.prototype.interactionMatch = function(imageID, type, interaction, interactions) {
  let ret = false;

  interactions.forEach(v => {
    if (v.image_id == imageID && v.interaction_type == type && (interaction == null || v.value == interaction)) {
      ret = true;

      return;
    }
  });

  return ret;
};

SearchTerm.prototype.match = function(target) {
  let ret = false,
      ohffs = this,
      compFunc,
      numbuh,
      date;

  if (!this.parsed) {
    this.parse();
  }

  if (this.termType === 'literal') {
    // Literal matching.
    if (this.fuzz) {
      compFunc = this.fuzzyMatch;
    }
    else if (this.wildcardable) {
      compFunc = this.wildcardMatch;
    }
    else {
      compFunc = this.exactMatch;
    }

    if (this.termSpace === 'tags') {
      target.getAttribute('data-image-tag-aliases').split(', ').every(
        str => {
          if (compFunc.call(ohffs, str)) {
            ret = true;
            return false;
          }
          return true;
        }
      );
    }
    else {
      ret = compFunc.call(
        this, target.getAttribute(termSpaceToImageField[this.termSpace])
      );
    }
  }
  else if (this.termType === 'my' && window.booru.interactions.length > 0) {
    // Should work with most my:conditions except watched.
    switch (this.termSpace) {
      case 'faves':
        ret = this.interactionMatch(target.getAttribute('data-image-id'), 'faved', null, window.booru.interactions);

        break;
      case 'upvotes':
        ret = this.interactionMatch(target.getAttribute('data-image-id'), 'voted', 'up', window.booru.interactions);

        break;
      case 'downvotes':
        ret = this.interactionMatch(target.getAttribute('data-image-id'), 'voted', 'down', window.booru.interactions);

        break;
      default:
        ret = false; // Other my: interactions aren't supported, return false to prevent them from triggering spoiler.

        break;
    }
  }
  else if (this.termType === 'date') {
    // Date matching.
    date = (new Date(
      target.getAttribute(termSpaceToImageField[this.termSpace])
    )).getTime();

    switch (this.compare) {
      // The open-left, closed-right date range specified by the
      // date/time format limits the types of comparisons that are
      // done compared to numeric ranges.
      case 'lt':
        ret = this.term > date;
        break;
      case 'gte':
        ret = this.term <= date;
        break;
      default:
        ret = this.term[0] <= date && this.term[1] > date;
    }
  }
  else {
    // Range matching.
    numbuh = parseFloat(
      target.getAttribute(termSpaceToImageField[this.termSpace])
    );

    if (isNaN(this.term)) {
      ret = false;
    }
    else if (this.fuzz) {
      ret = this.term <= numbuh + this.fuzz &&
                  this.term + this.fuzz >= numbuh;
    }
    else {
      switch (this.compare) {
        case 'lt':
          ret = this.term > numbuh;
          break;
        case 'gt':
          ret = this.term < numbuh;
          break;
        case 'lte':
          ret = this.term >= numbuh;
          break;
        case 'gte':
          ret = this.term <= numbuh;
          break;
        default:
          ret = this.term === numbuh;
      }
    }
  }

  return ret;
};

function generateLexArray(searchStr, options) {
  let opQueue = [],
      searchTerm = null,
      boost = null,
      fuzz = null,
      lparenCtr = 0,
      negate = false,
      groupNegate = [],
      tokenStack = [],
      boostFuzzStr = '';

  while (searchStr.length > 0) {
    tokenList.every(tokenArr => {
      let tokenName = tokenArr[0],
          tokenRE = tokenArr[1],
          match = tokenRE.exec(searchStr),
          balanced, op;

      if (match) {
        match = match[0];

        if (Boolean(searchTerm) && (
          ['and_op', 'or_op'].indexOf(tokenName) !== -1 ||
                        tokenName === 'rparen' && lparenCtr === 0)) {
          // Set options.
          searchTerm.boost = boost;
          searchTerm.fuzz = fuzz;
          // Push to stack.
          tokenStack.push(searchTerm);
          // Reset term and options data.
          searchTerm = fuzz = boost = null;
          boostFuzzStr = '';
          lparenCtr = 0;

          if (negate) {
            tokenStack.push('not_op');
            negate = false;
          }
        }

        switch (tokenName) {
          case 'and_op':
            while (opQueue[0] === 'and_op') {
              tokenStack.push(opQueue.shift());
            }
            opQueue.unshift('and_op');
            break;
          case 'or_op':
            while (opQueue[0] === 'and_op' || opQueue[0] === 'or_op') {
              tokenStack.push(opQueue.shift());
            }
            opQueue.unshift('or_op');
            break;
          case 'not_op':
            if (searchTerm) {
              // We're already inside a search term, so it does
              // not apply, obv.
              searchTerm.append(match);
            }
            else {
              negate = !negate;
            }
            break;
          case 'lparen':
            if (searchTerm) {
              // If we are inside the search term, do not error
              // out just yet; instead, consider it as part of
              // the search term, as a user convenience.
              searchTerm.append(match);
              lparenCtr += 1;
            }
            else {
              opQueue.unshift('lparen');
              groupNegate.push(negate);
              negate = false;
            }
            break;
          case 'rparen':
            if (lparenCtr > 0) {
              searchTerm.append(match);
              lparenCtr -= 1;
            }
            else {
              balanced = false;
              while (opQueue.length) {
                op = opQueue.shift();
                if (op === 'lparen') {
                  balanced = true;
                  break;
                }
                tokenStack.push(op);
              }
              if (groupNegate.length > 0 && groupNegate.pop()) {
                tokenStack.push('not_op');
              }
            }
            break;
          case 'fuzz':
            if (searchTerm) {
              // For this and boost operations, we store the
              // current match so far to a temporary string in
              // case this is actually inside the term.
              fuzz = parseFloat(match.substr(1));
              boostFuzzStr += match;
            }
            else {
              searchTerm = new SearchTerm(match, options);
            }
            break;
          case 'boost':
            if (searchTerm) {
              boost = match.substr(1);
              boostFuzzStr += match;
            }
            else {
              searchTerm = new SearchTerm(match, options);
            }
            break;
          case 'quoted_lit':
            if (searchTerm) {
              searchTerm.append(match);
            }
            else {
              searchTerm = new SearchTerm(match, options);
            }
            break;
          case 'word':
            if (searchTerm) {
              if (fuzz || boost) {
                boost = fuzz = null;
                searchTerm.append(boostFuzzStr);
                boostFuzzStr = '';
              }
              searchTerm.append(match);
            }
            else {
              searchTerm = new SearchTerm(match, options);
            }
            break;
          default:
            // Append extra spaces within search terms.
            if (searchTerm) {
              searchTerm.append(match);
            }
        }

        // Truncate string and restart the token tests.
        searchStr = searchStr.substr(
          match.length, searchStr.length - match.length
        );

        // Break since we have found a match.
        return false;
      }

      return true;
    });
  }

  // Append final tokens to the stack, starting with the search term.
  if (searchTerm) {
    searchTerm.boost = boost;
    searchTerm.fuzz = fuzz;
    tokenStack.push(searchTerm);
  }
  if (negate) {
    tokenStack.push('not_op');
  }

  if (opQueue.indexOf('rparen') !== -1 ||
            opQueue.indexOf('lparen') !== -1) {
    throw 'Mismatched parentheses.';
  }

  // Memory-efficient concatenation of remaining operators queue to the
  // token stack.
  tokenStack.push.apply(tokenStack, opQueue);

  return tokenStack;
}

function parseTokens(lexicalArray) {
  let operandStack = [],
      negate, op1, op2, parsed;
  lexicalArray.forEach((token, i) => {
    if (token !== 'not_op') {
      negate = lexicalArray[i + 1] === 'not_op';

      if (typeof token === 'string') {
        op2 = operandStack.pop();
        op1 = operandStack.pop();

        if (typeof op1 === 'undefined' || typeof op2 === 'undefined') {
          throw 'Missing operand.';
        }

        operandStack.push(new SearchAST(token, negate, op1, op2));
      }
      else {
        if (negate) {
          operandStack.push(new SearchAST(null, true, token));
        }
        else {
          operandStack.push(token);
        }
      }
    }
  });

  if (operandStack.length > 1) {
    throw 'Missing operator.';
  }

  op1 = operandStack.pop();

  if (typeof op1 === 'undefined') {
    return new SearchAST();
  }

  if (isTerminal(op1)) {
    return new SearchAST(null, false, op1);
  }

  return op1;
}

function parseSearch(searchStr, options) {
  return parseTokens(generateLexArray(searchStr, options));
}

function isTerminal(operand) {
  // Whether operand is a terminal SearchTerm.
  return typeof operand.term !== 'undefined';
}

function SearchAST(op, negate, leftOperand, rightOperand) {
  this.negate = Boolean(negate);
  this.leftOperand = leftOperand || null;
  this.op = op || null;
  this.rightOperand = rightOperand || null;
}

function combineOperands(ast1, ast2, parentAST) {
  if (parentAST.op === 'and_op') {
    ast1 = ast1 && ast2;
  }
  else {
    ast1 = ast1 || ast2;
  }

  if (parentAST.negate) {
    return !ast1;
  }

  return ast1;
}

// Evaluation of the AST in regard to a target image
SearchAST.prototype.hitsImage = function(image) {
  let treeStack = [],
      // Left side node.
      ast1 = this,
      // Right side node.
      ast2,
      // Parent node of the current subtree.
      parentAST;

  // Build the initial tree node traversal stack, of the "far left" side.
  // The general idea is to accumulate from the bottom and make stacks
  // of right-hand subtrees that themselves accumulate upward. The left
  // side node, ast1, will always be a Boolean representing the left-side
  // evaluated value, up to the current subtree (parentAST).
  while (!isTerminal(ast1)) {
    treeStack.push(ast1);
    ast1 = ast1.leftOperand;

    if (!ast1) {
      // Empty tree.
      return false;
    }
  }

  ast1 = ast1.match(image);
  treeStack.push(ast1);

  while (treeStack.length > 0) {
    parentAST = treeStack.pop();

    if (parentAST === null) {
      // We are at the end of a virtual stack for a right node
      // subtree. We switch the result of this stack from left
      // (ast1) to right (ast2), pop the original left node,
      // and finally pop the parent subtree itself. See near the
      // end of this function to view how this is populated.
      ast2 = ast1;
      ast1 = treeStack.pop();
      parentAST = treeStack.pop();
    }
    else {
      // First, check to see if we can do a short-circuit
      // evaluation to skip evaluating the right side entirely.
      if (!ast1 && parentAST.op === 'and_op') {
        ast1 = parentAST.negate;
        continue;
      }

      if (ast1 && parentAST.op === 'or_op') {
        ast1 = !parentAST.negate;
        continue;
      }

      // If we are not at the end of a stack, grab the right
      // node. The left node (ast1) is currently a terminal Boolean.
      ast2 = parentAST.rightOperand;
    }

    if (typeof ast2 === 'boolean') {
      ast1 = combineOperands(ast1, ast2, parentAST);
    }
    else if (!ast2) {
      // A subtree with a single node. This is generally the case
      // for negated tokens.
      if (parentAST.negate) {
        ast1 = !ast1;
      }
    }
    else if (isTerminal(ast2)) {
      // We are finally at a leaf and can evaluate.
      ast2 = ast2.match(image);
      ast1 = combineOperands(ast1, ast2, parentAST);
    }
    else {
      // We are at a node whose right side is a new subtree.
      // We will build a new "virtual" stack, but instead of
      // building a new Array, we can insert a null object as a
      // marker.
      treeStack.push(parentAST, ast1, null);

      do {
        treeStack.push(ast2);
        ast2 = ast2.leftOperand;
      } while (!isTerminal(ast2));

      ast1 = ast2.match(image);
    }
  }

  return ast1;
};

SearchAST.prototype.dumpTree = function() {
  // Dumps to string a simple diagram of the syntax tree structure
  // (starting with this object as the root) for debugging purposes.
  let retStrArr = [],
      treeQueue = [['', this]],
      treeArr,
      prefix,
      tree;

  while (treeQueue.length > 0) {
    treeArr = treeQueue.shift();
    prefix = treeArr[0];
    tree = treeArr[1];

    if (isTerminal(tree)) {
      retStrArr.push(`${prefix}-> ${tree.term}`);
    }
    else {
      if (tree.negate) {
        retStrArr.push(`${prefix}+ NOT_OP`);
        prefix += '\t';
      }
      if (tree.op) {
        retStrArr.push(`${prefix}+ ${tree.op.toUpperCase()}`);
        prefix += '\t';
        treeQueue.unshift([prefix, tree.rightOperand]);
        treeQueue.unshift([prefix, tree.leftOperand]);
      }
      else {
        treeQueue.unshift([prefix, tree.leftOperand]);
      }
    }
  }

  return retStrArr.join('\n');
};

export default parseSearch;
