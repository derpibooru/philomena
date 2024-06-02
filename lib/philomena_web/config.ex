defmodule PhilomenaWeb.Config do
  # Dialyzer only analyzes beam files directly and cannot see the compile-time variance in
  # the associated values, so it flags a false positive here.
  @dialyzer [:no_match]

  @reload_enabled Application.compile_env(:philomena, :vite_reload, false)
  @csp_relaxed Application.compile_env(:philomena, :csp_relaxed, false)

  defmacro vite_hmr?(do: do_clause, else: else_clause) do
    if(@reload_enabled, do: do_clause, else: else_clause)
  end

  defmacro csp_relaxed?(do: do_clause, else: else_clause) do
    if(@csp_relaxed, do: do_clause, else: else_clause)
  end
end
