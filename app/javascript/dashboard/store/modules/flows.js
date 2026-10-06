import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import FlowsAPI from '../../api/flows';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getFlows(_state) {
    return _state.records.sort((a1, a2) => a1.id - a2.id);
  },
  getFlow: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_FLOW_UI_FLAG, { isFetching: true });
    try {
      const response = await FlowsAPI.get();
      commit(types.SET_FLOWS, response.data.payload);
    } finally {
      commit(types.SET_FLOW_UI_FLAG, { isFetching: false });
    }
  },
  show: async ({ commit }, id) => {
    const response = await FlowsAPI.show(id);
    commit(types.ADD_FLOW, response.data);
    return response.data;
  },
  create: async ({ commit }, flowObj) => {
    commit(types.SET_FLOW_UI_FLAG, { isCreating: true });
    try {
      const response = await FlowsAPI.create(flowObj);
      commit(types.ADD_FLOW, response.data);
      return response.data;
    } finally {
      commit(types.SET_FLOW_UI_FLAG, { isCreating: false });
    }
  },
  update: async ({ commit }, { id, ...updateObj }) => {
    commit(types.SET_FLOW_UI_FLAG, { isUpdating: true });
    try {
      const response = await FlowsAPI.update(id, updateObj);
      commit(types.EDIT_FLOW, response.data);
      return response.data;
    } finally {
      commit(types.SET_FLOW_UI_FLAG, { isUpdating: false });
    }
  },
  publish: async ({ commit }, id) => {
    const response = await FlowsAPI.publish(id);
    commit(types.EDIT_FLOW, response.data);
    return response.data;
  },
  clone: async ({ commit }, id) => {
    const response = await FlowsAPI.clone(id);
    commit(types.ADD_FLOW, response.data);
    return response.data;
  },
  delete: async ({ commit }, id) => {
    commit(types.SET_FLOW_UI_FLAG, { isDeleting: true });
    try {
      await FlowsAPI.delete(id);
      commit(types.DELETE_FLOW, id);
    } finally {
      commit(types.SET_FLOW_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_FLOW_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.ADD_FLOW]: MutationHelpers.create,
  [types.SET_FLOWS]: MutationHelpers.set,
  [types.EDIT_FLOW]: MutationHelpers.update,
  [types.DELETE_FLOW]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
