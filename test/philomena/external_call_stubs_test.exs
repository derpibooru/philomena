defmodule Philomena.ExternalCallStubsTest do
  @moduledoc """
  Smoke tests for the external call stubbing: mailer, object storage
  (ex_aws), and outbound HTTP (PhilomenaProxy.Http via Req.Test).
  """

  use Philomena.DataCase, async: true

  import Swoosh.TestAssertions

  describe "mailer" do
    test "delivers to the test process instead of sending" do
      email =
        Swoosh.Email.new(
          to: {"Test", "test@example.com"},
          from: {"Philomena", "noreply@example.com"},
          subject: "Stub check",
          text_body: "Hello"
        )

      assert {:ok, _metadata} = Philomena.Mailer.deliver(email)
      assert_email_sent(subject: "Stub check")
    end
  end

  describe "object storage" do
    test "ex_aws requests succeed without any storage running" do
      assert {:ok, %{status_code: 200}} =
               ExAws.request(ExAws.S3.put_object("test-bucket", "test/key", "body"))
    end
  end

  describe "outbound HTTP" do
    test "PhilomenaProxy.Http routes through Req.Test stubs" do
      Req.Test.stub(PhilomenaProxy.Http, fn conn ->
        Req.Test.text(conn, "stubbed response")
      end)

      assert {:ok, %{status: 200, body: "stubbed response"}} =
               PhilomenaProxy.Http.get("http://external.example.com/")
    end
  end
end
