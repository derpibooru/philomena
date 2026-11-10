# Known oddities

This register tracks characterized behavior that is surprising enough to need
an explicit decision. The nearby `# NOTE:` comments in controller and context
tests remain the executable, fine-grained record; this file lists the issues
that affect context-boundary design or can produce a server error.

| Area                          | Characterized behavior                                                                                                                                     | Planned resolution                                                                                                                          |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Nested/member loading         | Several contexts still authorize a `nil` load, so an absent well-formed locator can be unauthorized for one role and not-found for another.                | Migrate each loader to `Philomena.Loader`; wave 0 fixes the shared primitive and exemplars, while waves 2–4 migrate the remaining contexts. |
| Forum/topic subscriptions     | Raw subscription helpers accept loaded structs and users, and some public-resource paths permit anonymous actors farther into the operation than expected. | Keep raw macro-generated functions internal and wrap every controller path in an actor-scoped context operation during waves 3–4.           |
| Nested resources              | Some post, poll, award, commission-item, and gallery-image paths load a child globally instead of proving membership in every route parent.                | Replace them with parent-constrained query loaders in waves 3–4.                                                                            |
| Missing parameter maps        | A few controller actions have only a destructuring clause; requests without the expected top-level key raise `Phoenix.ActionClauseError`.                  | Add explicit validation/fallback clauses in the owning context wave.                                                                        |
| Commission items              | An invalid item locator reaches a bang loader on an edit path.                                                                                             | Replace it with a parent-scoped safe query in wave 2.                                                                                       |
| Donation schema               | Every donation field is optional, so an empty submission creates a row.                                                                                    | Decide the intended minimum audit data before tightening validation; the current behavior remains covered by donation tests.                |
| Asynchronous destructive work | Some delete/wipe controller paths report success after enqueueing a worker and do not observe the eventual job result.                                     | Define job acceptance versus completed-deletion semantics in the owning context wave.                                                       |

When an oddity is resolved, remove its row only after updating the corresponding
`# NOTE:` assertion to the intended contract (or deleting the note when the new
behavior is no longer surprising).
