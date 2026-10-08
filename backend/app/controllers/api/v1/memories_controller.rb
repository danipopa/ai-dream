module Api
  module V1
    class MemoriesController < ApplicationController
      def index
        memories = Memory.order(created_at: :desc)
        render json: memories.map { |memory| serialize_memory(memory) }
      end

      def show
        render json: serialize_memory(memory)
      end

      def create
        memory = Memory.new(memory_params)
        memory.photo_paths = photo_storage.store(params[:photos])

        if memory.save
          render json: serialize_memory(memory), status: :created
        else
          render json: { errors: memory.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if memory.update(memory_params)
          render json: serialize_memory(memory)
        else
          render json: { errors: memory.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        memory.destroy
        head :no_content
      end

      private

      def memory
        @memory ||= Memory.find(params[:id])
      end

      def memory_params
        params.permit(:person_name, :person_age_at_memory, :memory_date, :title, :story)
      end

      def photo_storage
        MemoryServices::PhotoStorage.new
      end

      def serialize_memory(memory)
        {
          id: memory.id,
          person_name: memory.person_name,
          person_age_at_memory: memory.person_age_at_memory,
          memory_date: memory.memory_date,
          title: memory.title,
          story: memory.story,
          photos: memory.photo_paths,
          created_at: memory.created_at,
          updated_at: memory.updated_at
        }
      end
    end
  end
end
