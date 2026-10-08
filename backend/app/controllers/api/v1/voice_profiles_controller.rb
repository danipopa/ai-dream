module Api
  module V1
    class VoiceProfilesController < ApplicationController
      MAX_SAMPLE_SIZE = 25.megabytes

      def show
        return head :no_content unless memory.voice_profile

        render json: serialize_voice_profile(memory.voice_profile)
      end

      def create
        sample = params[:sample]
        if sample.respond_to?(:size) && sample.size > MAX_SAMPLE_SIZE
          return render json: { errors: ["Voice sample must be smaller than 25 MB"] }, status: :unprocessable_content
        end

        profile = VoiceServices::VoiceProfileCreator.new(
          memory: memory,
          upload: sample,
          consent_confirmed: params[:consent_confirmed]
        ).create

        status = profile.status == "failed" ? :bad_gateway : :created
        render json: serialize_voice_profile(profile), status: status
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_content
      rescue ArgumentError => error
        render json: { errors: [error.message] }, status: :unprocessable_content
      end

      private

      def memory
        @memory ||= Memory.find(params[:memory_id])
      end

      def serialize_voice_profile(profile)
        {
          id: profile.id,
          status: profile.status,
          provider: profile.provider,
          sample_url: profile.sample_path,
          consent_confirmed: profile.consent_confirmed,
          consent_recorded_at: profile.consent_recorded_at,
          error_message: profile.error_message,
          created_at: profile.created_at,
          updated_at: profile.updated_at
        }
      end
    end
  end
end
