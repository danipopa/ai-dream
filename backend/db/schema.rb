# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_09_04_000200) do
  create_table "conversation_messages", force: :cascade do |t|
    t.integer "memory_id", null: false
    t.string "speaker", null: false
    t.text "content", null: false
    t.integer "age_years"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memory_id"], name: "index_conversation_messages_on_memory_id"
  end

  create_table "memories", force: :cascade do |t|
    t.string "person_name", null: false
    t.integer "person_age_at_memory"
    t.date "memory_date"
    t.string "title", null: false
    t.text "story", null: false
    t.text "photo_paths", default: "[]", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "speech_generations", force: :cascade do |t|
    t.integer "memory_id", null: false
    t.integer "conversation_message_id"
    t.string "status", default: "pending", null: false
    t.string "provider", null: false
    t.text "text", null: false
    t.string "audio_path"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "language", default: "EN", null: false
    t.index ["conversation_message_id"], name: "index_speech_generations_on_conversation_message_id"
    t.index ["memory_id"], name: "index_speech_generations_on_memory_id"
  end

  create_table "video_jobs", force: :cascade do |t|
    t.integer "memory_id", null: false
    t.string "status", default: "queued", null: false
    t.text "prompt", null: false
    t.text "generated_script"
    t.string "output_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memory_id"], name: "index_video_jobs_on_memory_id"
  end

  create_table "voice_profiles", force: :cascade do |t|
    t.integer "memory_id", null: false
    t.string "status", default: "pending", null: false
    t.string "provider", null: false
    t.string "provider_voice_id"
    t.string "sample_path", null: false
    t.boolean "consent_confirmed", default: false, null: false
    t.text "consent_statement", null: false
    t.datetime "consent_recorded_at", null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["memory_id"], name: "index_voice_profiles_on_memory_id", unique: true
  end

  add_foreign_key "conversation_messages", "memories"
  add_foreign_key "speech_generations", "conversation_messages"
  add_foreign_key "speech_generations", "memories"
  add_foreign_key "video_jobs", "memories"
  add_foreign_key "voice_profiles", "memories"
end
