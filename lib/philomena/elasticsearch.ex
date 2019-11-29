defmodule Philomena.Elasticsearch do
  defmacro __using__(opts) do
    definition = Keyword.fetch!(opts, :definition)
    index_name = Keyword.fetch!(opts, :index_name)
    doc_type = Keyword.fetch!(opts, :doc_type)

    elastic_url = Application.get_env(:philomena, :elasticsearch_url)

    quote do
      alias Philomena.Repo
      import Ecto.Query, warn: false
      require Logger

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

        Elastix.Document.index(
          unquote(elastic_url),
          unquote(index_name),
          [unquote(doc_type)],
          data.id,
          data
        )
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
              %{index: %{_index: unquote(index_name), _type: unquote(doc_type), _id: doc.id}},
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

      def search(query_body) do
        {:ok, %{body: results, status_code: 200}} =
          Elastix.Search.search(
            unquote(elastic_url),
            unquote(index_name),
            [unquote(doc_type)],
            query_body
          )

        results
      end

      def search_results(elastic_query, pagination_params \\ %{}) do
        page_number = pagination_params[:page_number] || 1
        page_size = pagination_params[:page_size] || 25
        elastic_query = Map.merge(elastic_query, %{from: (page_number - 1) * page_size, size: page_size, _source: false})

        results = search(elastic_query)
        time = results["took"]
        count = results["hits"]["total"]
        entries = results["hits"]["hits"] |> Enum.map(&String.to_integer(&1["_id"]))

        Logger.debug("[Elasticsearch] Query took #{time}ms")

        %Scrivener.Page{
          entries: entries,
          page_number: page_number,
          page_size: page_size,
          total_entries: count,
          total_pages: div(count + page_size - 1, page_size)
        }
      end

      def search_records(elastic_query, pagination_params \\ %{}, ecto_query \\ __MODULE__) do
        page = search_results(elastic_query, pagination_params)
        ids = page.entries

        records =
          ecto_query
          |> where([m], m.id in ^ids)
          |> Repo.all()
          |> Enum.sort_by(&Enum.find_index(ids, fn el -> el == &1.id end))

        %{page | entries: records}
      end
    end
  end
end
