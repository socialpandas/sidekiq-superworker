class CreateSidekiqSuperworkerSubjobs < ActiveRecord::Migration
  def change
    create_table :sidekiq_superworker_subjobs do |t|
      t.string :jid
      t.string :superjob_id, null: false
      t.integer :subjob_id, null: false
      t.integer :parent_id
      t.text :children_ids
      t.integer :next_id
      t.string :superworker_class, null: false
      t.string :subworker_class, null: false
      t.text :arg_keys
      t.text :arg_values
      t.string :status, null: false
      t.boolean :descendants_are_complete, default: false
      t.text :meta
      
      t.timestamps
    end

    add_index :sidekiq_superworker_subjobs, :jid
    add_index :sidekiq_superworker_subjobs, :subjob_id
    add_index :sidekiq_superworker_subjobs, [:superjob_id, :subjob_id]
    add_index :sidekiq_superworker_subjobs, [:superjob_id, :parent_id]
  end
end
