module VoiceServices
  class SpeechGenerator
    def initialize(memory:, text:, conversation_message_id: nil, language: "EN")
      @memory = memory
      @text = text
      @conversation_message_id = conversation_message_id
      @language = language.to_s.upcase.presence || "EN"
    end

    def create
      profile = memory.voice_profile
      raise ArgumentError, "Create a ready voice profile first" unless profile&.status == "ready"

      generation = memory.speech_generations.create!(
        text: text,
        conversation_message_id: conversation_message_id,
        provider: profile.provider,
        language: language,
        status: "pending"
      )

      if profile.provider == "openvoice"
        audio = OpenVoiceProvider.new.synthesize(
          voice_id: profile.provider_voice_id,
          text: text,
          language: language
        )
        generation.update!(
          status: "complete",
          audio_path: FileStorage.new.store_audio(audio.bytes, extension: audio.extension)
        )
      else
        generation.update!(status: "complete")
      end

      generation
    rescue ProviderError => error
      generation&.update!(status: "failed", error_message: error.message)
      generation
    end

    private

    attr_reader :memory, :text, :conversation_message_id, :language
  end
end
