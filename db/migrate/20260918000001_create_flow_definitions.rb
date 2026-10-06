class CreateFlowDefinitions < ActiveRecord::Migration[7.1]
  def change
    create_table :flow_definitions do |t|
      t.bigint :account_id, null: false
      t.bigint :created_by_id
      t.bigint :updated_by_id
      t.string :name, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.jsonb :definition, null: false, default: { nodes: [], edges: [] }
      t.jsonb :published_definition
      t.integer :version, null: false, default: 0
      t.datetime :published_at

      t.timestamps
    end

    add_index :flow_definitions, :account_id
    add_index :flow_definitions, [:account_id, :status]
  end
end
