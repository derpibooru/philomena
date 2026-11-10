defmodule Philomena.ExAwsHttpClientStub do
  @moduledoc """
  ExAws HTTP client for tests: pretends every object-storage request
  succeeded, without any object storage running.

  Configured as `config :ex_aws, http_client:` for the test environment so
  that avatar/badge/image persistence (`PhilomenaMedia.Objects`) neither
  needs the `files` s3proxy container nor writes dev data from tests. Reads
  through `Objects.download_file/2` return an empty body; tests that need
  real object contents must arrange their own stubbing.
  """

  @behaviour ExAws.Request.HttpClient

  @impl true
  def request(_method, _url, _body, _headers, _http_opts) do
    {:ok, %{status_code: 200, headers: [], body: ""}}
  end
end
