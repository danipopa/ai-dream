class AddLanguageToSpeechGenerations < ActiveRecord::Migration[7.1]
  def change
    add_column :speech_generations, :language, :string, null: false, default: "EN"
  end
end
