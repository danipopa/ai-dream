class ApplicationController < ActionController::API
  rescue_from LlmServices::ProviderError, with: :render_llm_provider_error

  private

  def render_llm_provider_error(error)
    Rails.logger.error("LLM provider failure: #{error.message}")
    render json: { error_message: "The configured language model is unavailable. Please try again later." },
           status: :service_unavailable
  end
end
