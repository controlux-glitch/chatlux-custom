class CreateFlowRunEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :flow_run_events do |t|
      t.bigint :account_id, null: false
      t.bigint :flow_run_id, null: false
      t.string :node_id, null: false
      t.string :node_type, null: false
      t.jsonb :input, null: false, default: {}
      t.jsonb :output, null: false, default: {}
      t.integer :status, null: false
      t.text :error_message
      t.string :next_node_id
      t.integer :duration_ms

      t.datetime :created_at, null: false
    end

    add_index :flow_run_events, :account_id
    add_index :flow_run_events, :flow_run_id
    add_index :flow_run_events, [:flow_run_id, :created_at]
  end
end
