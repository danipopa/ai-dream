module Api
  module V1
    class VideoJobsController < ApplicationController
      def index
        render json: memory.video_jobs.order(created_at: :desc).map { |video_job| serialize_video_job(video_job) }
      end

      def create
        video_job = MediaServices::VideoJobPlanner.new(memory: memory).create(prompt: params[:prompt])
        render json: serialize_video_job(video_job), status: :created
      end

      private

      def memory
        @memory ||= Memory.find(params[:memory_id])
      end

      def serialize_video_job(video_job)
        {
          id: video_job.id,
          status: video_job.status,
          prompt: video_job.prompt,
          generated_script: video_job.generated_script,
          output_url: video_job.output_url,
          created_at: video_job.created_at,
          updated_at: video_job.updated_at
        }
      end
    end
  end
end
