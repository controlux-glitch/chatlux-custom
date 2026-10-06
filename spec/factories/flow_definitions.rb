FactoryBot.define do
  factory :flow_definition do
    account
    sequence(:name) { |n| "Test Flow #{n}" }
    status { :draft }
    definition do
      {
        'nodes' => [
          { 'id' => 'n1', 'type' => 'TRIGGER', 'params' => {} },
          { 'id' => 'n2', 'type' => 'MESSAGE', 'params' => { 'content' => 'Hola {{contact.name}}' } }
        ],
        'edges' => [
          { 'id' => 'e1', 'source' => 'n1', 'target' => 'n2' }
        ]
      }
    end
  end

  factory :flow_definition_inbox do
    account
    flow_definition
    inbox
    status { :active }
  end

  factory :flow_run do
    account
    flow_definition { create(:flow_definition, account: account) }
    inbox { create(:inbox, account: account) }
    contact { create(:contact, account: account) }
    conversation { create(:conversation, account: account, inbox: inbox, contact: contact) }
    flow_version { flow_definition.version }
    status { :running }
    started_at { Time.current }
    definition_snapshot { flow_definition.definition }
  end

  factory :flow_run_event do
    account
    flow_run
    node_id { 'n1' }
    node_type { 'MESSAGE' }
    status { :success }
  end
end
