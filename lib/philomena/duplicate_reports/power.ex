defmodule Philomena.DuplicateReports.Power do
  @moduledoc false

  defmacro power(left, right) do
    quote do
      fragment("power(?, ?)", unquote(left), unquote(right))
    end
  end
end
