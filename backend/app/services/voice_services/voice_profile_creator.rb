module VoiceServices
  class VoiceProfileCreator
    CONSENT_STATEMENT = "I confirm that I own this voice or have explicit permission to create and use its clone.".freeze

    def initialize(memory:, upload:, consent_confirmed:)
      @memory = memory
      @upload = upload
      @consent_confirmed = ActiveModel::Type::Boolean.new.cast(consent_confirmed)
    end

    def create
      raise ActiveRecord::RecordInvalid, invalid_profile unless consent_confirmed
      raise ArgumentError, "An audio sample is required" unless upload.respond_to?(:original_filename)
      raise ArgumentError, "The sample must be an audio file" unless upload.content_type.to_s.start_with?("audio/")

      sample_url = storage.store(upload)
      provider = ENV["VOICE_SERVICE_URL"].present? ? "openvoice" : "browser_preview"
      profile = memory.voice_profile || memory.build_voice_profile
      profile.assign_attributes(
        status: "pending",
        provider: provider,
        provider_voice_id: nil,
        sample_path: sample_url,
        consent_confirmed: true,
        consent_statement: CONSENT_STATEMENT,
        consent_recorded_at: Time.current,
        error_message: nil
      )
      profile.save!

      voice_id = create_provider_voice(profile)
      profile.update!(status: "ready", provider_voice_id: voice_id)
      profile
    rescue ProviderError => error
      profile&.update!(status: "failed", error_message: error.message)
      profile
    end

    private

    attr_reader :memory, :upload, :consent_confirmed

    def create_provider_voice(profile)
      return nil unless profile.provider == "openvoice"

      OpenVoiceProvider.new.create_voice(
        name: memory.person_name,
        sample_path: Rails.root.join("storage", "uploads", File.basename(profile.sample_path))
      )
    end

    def invalid_profile
      profile = memory.voice_profile || memory.build_voice_profile
      profile.errors.add(:consent_confirmed, "must be confirmed before cloning a voice")
      profile
    end

    def storage
      @storage ||= FileStorage.new
    end
  end
end
