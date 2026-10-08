class Memory < ApplicationRecord
  has_many :conversation_messages, dependent: :destroy
  has_many :video_jobs, dependent: :destroy
  has_one :voice_profile, dependent: :destroy
  has_many :speech_generations, dependent: :destroy

  serialize :photo_paths, coder: JSON

  validates :person_name, :title, :story, presence: true
end
