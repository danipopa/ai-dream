class ConversationMessage < ApplicationRecord
  SPEAKERS = %w[user memory_person].freeze

  belongs_to :memory
  has_many :speech_generations, dependent: :nullify

  validates :speaker, inclusion: { in: SPEAKERS }
  validates :content, presence: true
end
