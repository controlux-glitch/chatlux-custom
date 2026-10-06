# == Schema Information
#
# Table name: flow_runs
#
#  id                  :bigint           not null, primary key
#  definition_snapshot :jsonb            not null
#  error_message       :text
#  finished_at         :datetime
#  flow_version        :integer          not null
#  started_at          :datetime         not null
#  status              :integer          default("running"), not null
#  variables           :jsonb            not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  contact_id          :bigint           not null
#  conversation_id     :bigint           not null
#  current_node_id     :string
#  flow_definition_id  :bigint           not null
#  inbox_id            :bigint           not null
#
# Indexes
#
#  index_flow_runs_on_account_id             (account_id)
#  index_flow_runs_on_account_id_and_status  (account_id,status)
#  index_flow_runs_on_active_conversation    (conversation_id) UNIQUE WHERE (status = ANY (ARRAY[0, 1]))
#  index_flow_runs_on_contact_id             (contact_id)
#  index_flow_runs_on_conversation_id        (conversation_id)
#  index_flow_runs_on_flow_definition_id     (flow_definition_id)
#
class FlowRun < ApplicationRecord
  belongs_to :account
  belongs_to :flow_definition
  belongs_to :conversation
  belongs_to :contact
  belongs_to :inbox

  has_many :flow_run_events, dependent: :destroy_async

  enum status: { running: 0, waiting_input: 1, completed: 2, failed: 3, cancelled: 4, handed_off: 5 }

  validates :account_id, presence: true
  validates :flow_version, presence: true
  validates :started_at, presence: true

  scope :active, -> { where(status: [:running, :waiting_input]) }

  before_validation :ensure_started_at

  def active?
    running? || waiting_input?
  end

  private

  def ensure_started_at
    self.started_at ||= Time.current
  end
end
