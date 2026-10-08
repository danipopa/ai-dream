class SpeechGeneration < ApplicationRecord
  STATUSES = %w[pending complete failed].freeze
  PROVIDERS = %w[openvoice browser_preview].freeze
  LANGUAGES = %w[EN ES FR ZH JP KR].freeze

  belongs_to :memory
  belongs_to :conversation_message, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :language, inclusion: { in: LANGUAGES }
  validates :text, presence: true, length: { maximum: 2_500 }
end
