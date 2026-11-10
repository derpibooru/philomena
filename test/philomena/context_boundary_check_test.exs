defmodule Philomena.ContextBoundaryCheckTest do
  use ExUnit.Case, async: true

  alias Philomena.ContextBoundaryCheck

  test "all application sources respect context boundaries" do
    violations = ContextBoundaryCheck.violations(File.cwd!())

    assert violations == [], format_violations(violations)
  end

  test "reports direct Canada calls and undocumented context functions" do
    with_fixture(fn root ->
      write_fixture(root, "lib/philomena/new_context.ex", """
      defmodule Philomena.NewContext do
        def visible?(actor, image), do: Canada.Can.can?(actor, :show, image)
      end
      """)

      assert [canada, docs] = ContextBoundaryCheck.violations(root)
      assert canada.message == "contexts must call Philomena.Authorization.authorize/3"
      assert docs.message == "public context function visible?/2 has no @doc"
    end)
  end

  test "reports controller Repo calls and context bang loaders" do
    with_fixture(fn root ->
      write_fixture(root, "lib/philomena_web/controllers/image_controller.ex", """
      defmodule PhilomenaWeb.ImageController do
        alias Philomena.Images
        alias Philomena.Repo, as: Database

        def show(id) do
          Database.get(Philomena.Images.Image, id)
          Images.load_image_for_reindex!(id)
        end
      end
      """)

      assert [repo, bang_loader] = ContextBoundaryCheck.violations(root)
      assert repo.message == "controllers must not call Repo directly"
      assert bang_loader.message == "controllers must not call bang loaders"
    end)
  end

  test "accepts documented context functions and actor-scoped controller calls" do
    with_fixture(fn root ->
      write_fixture(root, "lib/philomena/images.ex", """
      defmodule Philomena.Images do
        @doc "Loads an image."
        def load_image(actor, id), do: {actor, id}
      end
      """)

      write_fixture(root, "lib/philomena_web/controllers/image_controller.ex", """
      defmodule PhilomenaWeb.ImageController do
        alias Philomena.Images

        def show(actor, id), do: Images.load_image(actor, id)
      end
      """)

      assert ContextBoundaryCheck.violations(root) == []
    end)
  end

  defp with_fixture(callback) do
    root = Path.join(System.tmp_dir!(), "context-boundary-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    try do
      callback.(root)
    after
      File.rm_rf!(root)
    end
  end

  defp write_fixture(root, path, contents) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  defp format_violations([]), do: "Context boundary checks passed"

  defp format_violations(violations) do
    details =
      Enum.map_join(violations, "\n", fn violation ->
        "#{violation.file}:#{violation.line}: #{violation.message}"
      end)

    "Context boundary violations:\n#{details}"
  end
end
