class CreateVideoJobs < ActiveRecord::Migration[7.1]
  def change
    create_table :video_jobs do |t|
      t.references :memory, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.text :prompt, null: false
      t.text :generated_script
      t.string :output_url

      t.timestamps
    end
  end
end
