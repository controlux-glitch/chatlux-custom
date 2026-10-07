class MigrateFlowsFeatureFlag < ActiveRecord::Migration[7.2]
  # Flows is the eighth flag in feature_flags_ext_1; earlier flags keep their positions.
  def up
    execute <<~SQL
      UPDATE accounts
      SET feature_flags_ext_1 = feature_flags_ext_1 | 128
      WHERE internal_attributes ->> 'feature_flows' = 'true'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE accounts
      SET internal_attributes = jsonb_set(internal_attributes, '{feature_flows}',
                                         to_jsonb((feature_flags_ext_1 & 128) <> 0)),
          feature_flags_ext_1 = feature_flags_ext_1 & ~128::bigint
    SQL
  end
end
