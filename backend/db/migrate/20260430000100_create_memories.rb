class CreateMemories < ActiveRecord::Migration[7.1]
  def change
    create_table :memories do |t|
      t.string :person_name, null: false
      t.integer :person_age_at_memory
      t.date :memory_date
      t.string :title, null: false
      t.text :story, null: false
      t.text :photo_paths, null: false, default: "[]"

      t.timestamps
    end
  end
end
