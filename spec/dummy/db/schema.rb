# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130522204048) do

  create_table "sidekiq_superworker_subjobs", :force => true do |t|
    t.string   "jid"
    t.string   "superjob_id",                                 :null => false
    t.integer  "subjob_id",                                   :null => false
    t.integer  "parent_id"
    t.text     "children_ids"
    t.integer  "next_id"
    t.string   "superworker_class",                           :null => false
    t.string   "subworker_class",                             :null => false
    t.text     "arg_keys"
    t.text     "arg_values"
    t.string   "status",                                      :null => false
    t.boolean  "descendants_are_complete", :default => false
    t.text     "meta"
    t.datetime "created_at",                                  :null => false
    t.datetime "updated_at",                                  :null => false
  end

  add_index "sidekiq_superworker_subjobs", ["jid"], :name => "index_sidekiq_superworker_subjobs_on_jid"
  add_index "sidekiq_superworker_subjobs", ["subjob_id"], :name => "index_sidekiq_superworker_subjobs_on_subjob_id"
  add_index "sidekiq_superworker_subjobs", ["superjob_id", "parent_id"], :name => "index_sidekiq_superworker_subjobs_on_superjob_id_and_parent_id"
  add_index "sidekiq_superworker_subjobs", ["superjob_id", "subjob_id"], :name => "index_sidekiq_superworker_subjobs_on_superjob_id_and_subjob_id"

end
