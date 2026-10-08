class CreateConversationMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_messages do |t|
      t.references :memory, null: false, foreign_key: true
      t.string :speaker, null: false
      t.text :content, null: false
      t.integer :age_years

      t.timestamps
    end
  end
end
