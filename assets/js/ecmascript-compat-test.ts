/**
 * @file This is a special file that isn't imported by our root `app.ts` in any
 * way, but it lives here to test that our build fails if we try to use any
 * features of the ECMAScript standard newer than our support target as
 * specified in the tsconfig.json.
 */

function _ecmascript2020() {
  // @ts-expect-error You may see an 'unused @ts-expect-error' squiggle here.
  // This is because your IDE is using the ES2020 library transitively included
  // from `vitest` via `@types/node`. However, our final build uses a different
  // config file (`tsconfig.build.json`) that doesn't include the ES2020
  // library, where this `@ts-expect-error` is valid.
  return Promise.allSettled;
}
