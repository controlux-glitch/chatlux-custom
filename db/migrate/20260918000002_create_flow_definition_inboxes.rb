class CreateFlowDefinitionInboxes < ActiveRecord::Migration[7.1]
  def change
    create_table :flow_definition_inboxes do |t|
      t.bigint :account_id, null: false
      t.bigint :flow_definition_id, null: false
      t.bigint :inbox_id, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :flow_definition_inboxes, :account_id
    add_index :flow_definition_inboxes, [:flow_definition_id, :inbox_id], unique: true, name: 'index_flow_def_inboxes_on_flow_definition_and_inbox'
    add_index :flow_definition_inboxes, :inbox_id
  end
end
