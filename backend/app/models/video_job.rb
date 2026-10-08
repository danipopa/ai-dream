class VideoJob < ApplicationRecord
  STATUSES = %w[queued scripting rendering complete failed].freeze

  belongs_to :memory

  validates :status, inclusion: { in: STATUSES }
  validates :prompt, presence: true
end
