class CreateFlowRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :flow_runs do |t|
      t.bigint :account_id, null: false
      t.bigint :flow_definition_id, null: false
      t.integer :flow_version, null: false
      t.bigint :conversation_id, null: false
      t.bigint :contact_id, null: false
      t.bigint :inbox_id, null: false
      t.string :current_node_id
      t.integer :status, null: false, default: 0
      t.jsonb :variables, null: false, default: {}
      t.jsonb :definition_snapshot, null: false, default: {}
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at

      t.timestamps
    end

    add_index :flow_runs, :account_id
    add_index :flow_runs, :flow_definition_id
    add_index :flow_runs, :conversation_id
    add_index :flow_runs, :contact_id
    add_index :flow_runs, [:account_id, :status]
    add_index :flow_runs, :conversation_id, unique: true, where: 'status IN (0, 1)', name: 'index_flow_runs_on_active_conversation'
  end
end
