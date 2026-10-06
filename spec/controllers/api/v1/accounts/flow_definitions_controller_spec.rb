require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::FlowDefinitionsController', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'GET /api/v1/accounts/{account.id}/flow_definitions' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/flow_definitions"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      it 'returns all flow definitions for the account' do
        flow_definition = create(:flow_definition, account: account, name: 'Welcome Flow')

        get "/api/v1/accounts/#{account.id}/flow_definitions", headers: administrator.create_new_auth_token

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body, symbolize_names: true)
        expect(body[:payload].first[:id]).to eq(flow_definition.id)
      end
    end

    context 'when it is an authenticated agent (non-admin)' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/flow_definitions", headers: agent.create_new_auth_token
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/flow_definitions' do
    let(:params) do
      {
        name: 'Welcome Flow',
        definition: {
          nodes: [{ id: 'n1', type: 'TRIGGER' }],
          edges: []
        }
      }
    end

    it 'creates a flow definition' do
      post "/api/v1/accounts/#{account.id}/flow_definitions", params: params, headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(account.flow_definitions.count).to eq(1)
      expect(account.flow_definitions.first.status).to eq('draft')
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/flow_definitions/:id/publish' do
    it 'publishes the flow and snapshots the definition' do
      flow_definition = create(:flow_definition, account: account)

      post "/api/v1/accounts/#{account.id}/flow_definitions/#{flow_definition.id}/publish", headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      flow_definition.reload
      expect(flow_definition.status).to eq('published')
      expect(flow_definition.published_definition).to eq(flow_definition.definition)
      expect(flow_definition.version).to eq(1)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/flow_definitions/:id/clone' do
    it 'duplicates the flow as a draft' do
      flow_definition = create(:flow_definition, account: account, status: :published, version: 2)

      post "/api/v1/accounts/#{account.id}/flow_definitions/#{flow_definition.id}/clone", headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(account.flow_definitions.count).to eq(2)
      expect(account.flow_definitions.last.status).to eq('draft')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/flow_definitions/:id' do
    it 'deletes the flow definition' do
      flow_definition = create(:flow_definition, account: account)

      delete "/api/v1/accounts/#{account.id}/flow_definitions/#{flow_definition.id}", headers: administrator.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(account.flow_definitions.count).to eq(0)
    end
  end
end
