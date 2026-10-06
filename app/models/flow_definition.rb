# == Schema Information
#
# Table name: flow_definitions
#
#  id                   :bigint           not null, primary key
#  definition           :jsonb            not null
#  description          :text
#  name                 :string           not null
#  published_at         :datetime
#  published_definition :jsonb
#  status               :integer          default("draft"), not null
#  version              :integer          default(0), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  created_by_id        :bigint
#  updated_by_id        :bigint
#
# Indexes
#
#  index_flow_definitions_on_account_id             (account_id)
#  index_flow_definitions_on_account_id_and_status  (account_id,status)
#
class FlowDefinition < ApplicationRecord
  DEFINITION_SCHEMA = {
    'type' => 'object',
    'required' => %w[nodes edges],
    'properties' => {
      'nodes' => {
        'type' => 'array',
        'items' => {
          'type' => 'object',
          'required' => %w[id type],
          'properties' => {
            'id' => { 'type' => 'string' },
            'type' => { 'type' => 'string' },
            'position' => { 'type' => 'object' },
            'params' => { 'type' => 'object' }
          }
        }
      },
      'edges' => {
        'type' => 'array',
        'items' => {
          'type' => 'object',
          'required' => %w[id source target],
          'properties' => {
            'id' => { 'type' => 'string' },
            'source' => { 'type' => 'string' },
            'target' => { 'type' => 'string' },
            'source_handle' => { 'type' => 'string' }
          }
        }
      }
    }
  }.freeze

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :flow_definition_inboxes, dependent: :destroy_async
  has_many :inboxes, through: :flow_definition_inboxes
  has_many :flow_runs, dependent: :destroy_async

  enum status: { draft: 0, published: 1, disabled: 2 }

  validates :account_id, presence: true
  validates :name, presence: true
  validates_with JsonSchemaValidator, schema: DEFINITION_SCHEMA, attribute_resolver: ->(record) { record.definition }

  before_validation :ensure_definition_defaults

  private

  def ensure_definition_defaults
    self.definition ||= { 'nodes' => [], 'edges' => [] }
  end
end

FlowDefinition.include_mod_with('Audit::FlowDefinition')
FlowDefinition.prepend_mod_with('FlowDefinition')
