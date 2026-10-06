# == Schema Information
#
# Table name: flow_definition_inboxes
#
#  id                 :bigint           not null, primary key
#  status             :integer          default("active"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  flow_definition_id :bigint           not null
#  inbox_id           :bigint           not null
#
# Indexes
#
#  index_flow_def_inboxes_on_flow_definition_and_inbox  (flow_definition_id,inbox_id) UNIQUE
#  index_flow_definition_inboxes_on_account_id          (account_id)
#  index_flow_definition_inboxes_on_inbox_id            (inbox_id)
#
class FlowDefinitionInbox < ApplicationRecord
  belongs_to :account
  belongs_to :flow_definition
  belongs_to :inbox

  enum status: { active: 0, inactive: 1 }

  validates :flow_definition_id, presence: true
  validates :inbox_id, presence: true

  before_validation :ensure_account_id

  private

  def ensure_account_id
    self.account_id ||= inbox&.account_id
  end
end
