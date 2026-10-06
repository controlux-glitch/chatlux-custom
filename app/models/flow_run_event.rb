# == Schema Information
#
# Table name: flow_run_events
#
#  id            :bigint           not null, primary key
#  duration_ms   :integer
#  error_message :text
#  input         :jsonb            not null
#  node_type     :string           not null
#  output        :jsonb            not null
#  status        :integer          not null
#  created_at    :datetime         not null
#  account_id    :bigint           not null
#  flow_run_id   :bigint           not null
#  next_node_id  :string
#  node_id       :string           not null
#
# Indexes
#
#  index_flow_run_events_on_account_id                  (account_id)
#  index_flow_run_events_on_flow_run_id                 (flow_run_id)
#  index_flow_run_events_on_flow_run_id_and_created_at  (flow_run_id,created_at)
#
class FlowRunEvent < ApplicationRecord
  belongs_to :account
  belongs_to :flow_run

  enum status: { success: 0, error: 1, waiting: 2 }

  validates :node_id, presence: true
  validates :node_type, presence: true
end
