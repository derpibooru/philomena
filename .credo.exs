%{
  configs: %{
    name: "default",
    checks: %{
      disabled: [
        {Credo.Check.Refactor.CondStatements, false},
        {Credo.Check.Refactor.NegatedConditionsWithElse, false}
      ]
    }
  }
}
