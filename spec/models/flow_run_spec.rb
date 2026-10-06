require 'rails_helper'

RSpec.describe FlowRun do
  describe 'validations and scopes' do
    it 'is valid with required associations' do
      flow_run = create(:flow_run)
      expect(flow_run).to be_valid
    end

    it 'only returns running/waiting_input runs in the active scope' do
      running = create(:flow_run, status: :running)
      waiting = create(:flow_run, status: :waiting_input)
      create(:flow_run, status: :completed)

      expect(described_class.active).to contain_exactly(running, waiting)
    end

    it 'does not allow two active runs for the same conversation' do
      first_run = create(:flow_run, status: :running)

      duplicate = build(:flow_run, status: :running, conversation: first_run.conversation, account: first_run.account,
                                   contact: first_run.contact, inbox: first_run.inbox, flow_definition: first_run.flow_definition)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
