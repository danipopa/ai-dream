module Api
  module V1
    class SpeechGenerationsController < ApplicationController
      def index
        render json: memory.speech_generations.order(created_at: :desc).map { |generation| serialize(generation) }
      end

      def create
        generation = VoiceServices::SpeechGenerator.new(
          memory: memory,
          text: params.require(:text),
          conversation_message_id: params[:conversation_message_id],
          language: params[:language].presence || "EN"
        ).create

        status = generation.status == "failed" ? :bad_gateway : :created
        render json: serialize(generation), status: status
      rescue ActiveRecord::RecordInvalid => error
        render json: { errors: error.record.errors.full_messages }, status: :unprocessable_content
      rescue ActionController::ParameterMissing, ArgumentError => error
        render json: { errors: [error.message] }, status: :unprocessable_content
      end

      private

      def memory
        @memory ||= Memory.find(params[:memory_id])
      end

      def serialize(generation)
        {
          id: generation.id,
          status: generation.status,
          provider: generation.provider,
          language: generation.language,
          text: generation.text,
          audio_url: generation.audio_path,
          error_message: generation.error_message,
          created_at: generation.created_at
        }
      end
    end
  end
end
