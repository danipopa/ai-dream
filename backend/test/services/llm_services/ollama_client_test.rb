require "test_helper"
require "json"
require "minitest/mock"
require "net/http"

class LlmServices::OllamaClientTest < ActiveSupport::TestCase
  test "sends a non-streaming chat request to the configured model" do
    captured_requests = []
    fake_http = Object.new
    response = success_response(message: { content: "A grounded reply." })
    fake_http.define_singleton_method(:request) do |request|
      captured_requests << request
      response
    end
    http_start = ->(*_args, **_options, &block) { block.call(fake_http) }

    answer = Net::HTTP.stub(:start, http_start) do
      LlmServices::OllamaClient.new(
        base_url: "http://ollama.example:11434",
        model: "qwen2.5:3b"
      ).chat(messages: [{ role: "user", content: "Hello" }], num_predict: 128)
    end

    assert_equal "A grounded reply.", answer
    request = captured_requests.fetch(0)
    assert_equal "/api/chat", request.path
    assert_equal "qwen2.5:3b", JSON.parse(request.body).fetch("model")
    assert_equal false, JSON.parse(request.body).fetch("stream")
    assert_equal 128, JSON.parse(request.body).dig("options", "num_predict")
  end

  test "reports provider failures instead of returning an empty response" do
    fake_http = Object.new
    response = success_response(message: { content: " " })
    fake_http.define_singleton_method(:request) { |_request| response }
    http_start = ->(*_args, **_options, &block) { block.call(fake_http) }

    Net::HTTP.stub(:start, http_start) do
      error = assert_raises(LlmServices::ProviderError) do
        LlmServices::OllamaClient.new.chat(messages: [{ role: "user", content: "Hello" }])
      end
      assert_equal "Ollama returned an empty response", error.message
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
