/* global axios */
import ApiClient from './ApiClient';

class FlowsAPI extends ApiClient {
  constructor() {
    super('flow_definitions', { accountScoped: true });
  }

  publish(flowId) {
    return axios.post(`${this.url}/${flowId}/publish`);
  }

  clone(flowId) {
    return axios.post(`${this.url}/${flowId}/clone`);
  }

  runs(flowId) {
    return axios.get(`${this.url}/${flowId}/flow_runs`);
  }

  run(flowId, runId) {
    return axios.get(`${this.url}/${flowId}/flow_runs/${runId}`);
  }
}

export default new FlowsAPI();
