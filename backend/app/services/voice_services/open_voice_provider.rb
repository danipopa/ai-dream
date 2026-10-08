require "json"
require "marcel"
require "net/http"
require "pathname"

module VoiceServices
  class OpenVoiceProvider
    AudioResult = Data.define(:bytes, :extension)

    def initialize(base_url: ENV.fetch("VOICE_SERVICE_URL"), token: ENV["VOICE_SERVICE_TOKEN"])
      @base_uri = URI(base_url)
      @token = token
    end

    def create_voice(name:, sample_path:)
      file = File.open(sample_path, "rb")
      request = Net::HTTP::Post.new(endpoint("/v1/voices"))
      add_authentication(request)
      request.set_form([
        ["name", name],
        ["sample", file, { filename: File.basename(sample_path), content_type: Marcel::MimeType.for(Pathname.new(sample_path)) }]
      ], "multipart/form-data")

      JSON.parse(perform(request).body).fetch("voice_id")
    ensure
      file&.close
    end

    def synthesize(voice_id:, text:, language: "EN")
      request = Net::HTTP::Post.new(endpoint("/v1/speech/#{voice_id}"))
      add_authentication(request)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(text: text, language: language)
      response = perform(request)
      extension = response["Content-Type"].to_s.include?("mpeg") ? "mp3" : "wav"
      AudioResult.new(bytes: response.body, extension: extension)
    end

    private

    attr_reader :base_uri, :token

    def endpoint(path)
      uri = base_uri.dup
      uri.path = [base_uri.path.delete_suffix("/"), path].join
      uri.query = nil
      uri
    end

    def add_authentication(request)
      request["X-Internal-Token"] = token if token.present?
    end

    def perform(request)
      response = Net::HTTP.start(
        request.uri.host,
        request.uri.port,
        use_ssl: request.uri.scheme == "https",
        open_timeout: 10,
        read_timeout: 180
      ) { |http| http.request(request) }
      return response if response.is_a?(Net::HTTPSuccess)

      raise ProviderError, "Voice service returned #{response.code}: #{response.body.to_s.first(300)}"
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise ProviderError, "Voice service is unavailable: #{error.message}"
    end
  end
end
