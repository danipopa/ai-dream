class CreateVoiceProfilesAndSpeechGenerations < ActiveRecord::Migration[7.1]
  def change
    create_table :voice_profiles do |t|
      t.references :memory, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "pending"
      t.string :provider, null: false
      t.string :provider_voice_id
      t.string :sample_path, null: false
      t.boolean :consent_confirmed, null: false, default: false
      t.text :consent_statement, null: false
      t.datetime :consent_recorded_at, null: false
      t.text :error_message

      t.timestamps
    end

    create_table :speech_generations do |t|
      t.references :memory, null: false, foreign_key: true
      t.references :conversation_message, null: true, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :provider, null: false
      t.text :text, null: false
      t.string :audio_path
      t.text :error_message

      t.timestamps
    end
  end
end
