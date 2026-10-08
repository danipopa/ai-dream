class VoiceProfile < ApplicationRecord
  STATUSES = %w[pending ready failed].freeze
  PROVIDERS = %w[openvoice browser_preview].freeze

  belongs_to :memory

  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :sample_path, :consent_statement, :consent_recorded_at, presence: true
  validates :consent_confirmed, acceptance: true
end
