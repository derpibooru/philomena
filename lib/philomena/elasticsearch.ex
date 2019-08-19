defmodule Philomena.Elasticsearch do
  defmacro __using__(opts) do
    definition = Keyword.fetch!(opts, :definition)
    index_name = Keyword.fetch!(opts, :index_name)

    elastic_url = Application.get_env(:philomena, :elasticsearch_url)

    quote do
      alias Philomena.Repo
      import Ecto.Query, warn: false

      def create_index! do
        Elastix.Index.create(
          unquote(elastic_url),
          unquote(index_name),
          unquote(definition).mapping()
        )
      end

      def delete_index! do
        Elastix.Index.delete(unquote(elastic_url), unquote(index_name))
      end

      def index_document(doc) do
        data = unquote(definition).as_json(doc)

        Elastix.Document.index(unquote(elastic_url), unquote(index_name), ["_doc"], data.id, data)
      end

      def reindex(ecto_query, batch_size \\ 1000) do
        ids =
          ecto_query
          |> exclude(:preload)
          |> exclude(:order_by)
          |> order_by(asc: :id)
          |> select([m], m.id)
          |> limit(^batch_size)
          |> Repo.all()

        reindex(ecto_query, batch_size, ids)
      end

      def reindex(ecto_query, batch_size, []), do: nil

      def reindex(ecto_query, batch_size, ids) do
        lines =
          ecto_query
          |> where([m], m.id in ^ids)
          |> Repo.all()
          |> Enum.flat_map(fn m ->
            doc = unquote(definition).as_json(m)

            [
              %{index: %{_index: unquote(index_name), _type: "_doc", _id: doc.id}},
              doc
            ]
          end)

        Elastix.Bulk.post(unquote(elastic_url), lines,
          index: unquote(index_name),
          httpoison_options: [timeout: 30_000]
        )

        ids =
          ecto_query
          |> exclude(:preload)
          |> exclude(:order_by)
          |> order_by(asc: :id)
          |> where([m], m.id > ^Enum.max(ids))
          |> select([m], m.id)
          |> limit(^batch_size)
          |> Repo.all()

        reindex(ecto_query, batch_size, ids)
      end

      def search_results(elastic_query) do
        {:ok, %{body: results, status_code: 200}} =
          Elastix.Search.search(
            unquote(elastic_url),
            unquote(index_name),
            ["_doc"],
            elastic_query
          )

        results
      end

      def search_records(elastic_query, ecto_query \\ __MODULE__) do
        results = search_results(elastic_query)

        ids = results["hits"]["hits"] |> Enum.map(&String.to_integer(&1["_id"]))
        records = ecto_query |> where([m], m.id in ^ids) |> Repo.all()

        records |> Enum.sort_by(&Enum.find_index(ids, fn el -> el == &1.id end))
      end
    end
  end
end
