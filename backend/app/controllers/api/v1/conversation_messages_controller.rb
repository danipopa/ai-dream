module Api
  module V1
    class ConversationMessagesController < ApplicationController
      def index
        render json: memory.conversation_messages.order(:created_at).map { |message| serialize_message(message) }
      end

      def create
        response = ConversationServices::MemoryPersonaResponder.new(memory: memory).reply(
          user_message: params.require(:message),
          age_years: params[:age_years].presence
        )

        render json: response.map { |message| serialize_message(message) }, status: :created
      end

      private

      def memory
        @memory ||= Memory.find(params[:memory_id])
      end

      def serialize_message(message)
        {
          id: message.id,
          speaker: message.speaker,
          content: message.content,
          age_years: message.age_years,
          created_at: message.created_at
        }
      end
    end
  end
end
