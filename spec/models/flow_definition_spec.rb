require 'rails_helper'

RSpec.describe FlowDefinition do
  let(:account) { create(:account) }

  describe 'validations' do
    it 'is valid with a well-formed definition' do
      flow_definition = build(:flow_definition, account: account)
      expect(flow_definition).to be_valid
    end

    it 'is invalid without a name' do
      flow_definition = build(:flow_definition, account: account, name: nil)
      expect(flow_definition).not_to be_valid
      expect(flow_definition.errors[:name]).to be_present
    end

    it 'is invalid when definition nodes is not an array' do
      flow_definition = build(:flow_definition, account: account, definition: { 'nodes' => 'not-an-array', 'edges' => [] })
      expect(flow_definition).not_to be_valid
      expect(flow_definition.errors[:nodes]).to be_present
    end

    it 'is invalid when a node is missing a type' do
      flow_definition = build(:flow_definition, account: account, definition: { 'nodes' => [{ 'id' => 'n1' }], 'edges' => [] })
      expect(flow_definition).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'defaults status to draft' do
      flow_definition = create(:flow_definition)
      expect(flow_definition.status).to eq('draft')
    end
  end

  describe 'associations' do
    it 'links to inboxes through flow_definition_inboxes' do
      flow_definition = create(:flow_definition)
      inbox = create(:inbox, account: flow_definition.account)
      create(:flow_definition_inbox, flow_definition: flow_definition, inbox: inbox, account: flow_definition.account)

      expect(flow_definition.inboxes).to include(inbox)
    end
  end
end
