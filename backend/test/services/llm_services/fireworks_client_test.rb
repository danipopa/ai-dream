require "test_helper"
require "json"
require "net/http"

class LlmServices::FireworksClientTest < ActiveSupport::TestCase
  test "sends an authenticated non-streaming chat completion request" do
    captured_requests = []
    fake_http = Object.new
    response = success_response(
      choices: [{ message: { content: "A helpful reply." } }]
    )
    fake_http.define_singleton_method(:request) do |request|
      captured_requests << request
      response
    end
    http_start = ->(*_args, **_options, &block) { block.call(fake_http) }

    answer = Net::HTTP.stub(:start, http_start) do
      LlmServices::FireworksClient.new(
        base_url: "https://api.fireworks.ai/inference/v1",
        model: "accounts/fireworks/models/test-model",
        api_key: "test-api-key\n"
      ).chat(messages: [{ role: "user", content: "Hello" }], num_predict: 128)
    end

    assert_equal "A helpful reply.", answer
    request = captured_requests.fetch(0)
    payload = JSON.parse(request.body)
    assert_equal "/inference/v1/chat/completions", request.path
    assert_equal "Bearer test-api-key", request["Authorization"]
    assert_equal "accounts/fireworks/models/test-model", payload.fetch("model")
    assert_equal false, payload.fetch("stream")
    assert_equal 128, payload.fetch("max_tokens")
  end

  test "rejects missing API credentials and insecure endpoints" do
    error = assert_raises(LlmServices::ProviderError) do
      LlmServices::FireworksClient.new(api_key: "")
    end
    assert_equal "Fireworks API key is not configured", error.message

    error = assert_raises(LlmServices::ProviderError) do
      LlmServices::FireworksClient.new(base_url: "http://api.fireworks.ai", api_key: "test")
    end
    assert_equal "Fireworks API URL must use HTTPS", error.message
  end

  test "reports empty model responses" do
    fake_http = Object.new
    response = success_response(choices: [{ message: { content: " " } }])
    fake_http.define_singleton_method(:request) { |_request| response }
    http_start = ->(*_args, **_options, &block) { block.call(fake_http) }

    Net::HTTP.stub(:start, http_start) do
      error = assert_raises(LlmServices::ProviderError) do
        LlmServices::FireworksClient.new(api_key: "test").chat(
          messages: [{ role: "user", content: "Hello" }]
        )
      end
      assert_equal "Fireworks returned an empty response", error.message
    end
  end

  private

  def success_response(payload)
    Class.new(Net::HTTPSuccess) do
      define_method(:initialize) { |body| @response_body = body }
      define_method(:body) { @response_body }
      define_method(:code) { "200" }
    end.new(JSON.generate(payload))
  end
end
