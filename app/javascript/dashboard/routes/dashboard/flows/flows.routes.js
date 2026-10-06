import { frontendURL } from 'dashboard/helper/URLHelper.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import FlowsPageRouteView from './pages/FlowsPageRouteView.vue';
import FlowsIndexPage from './pages/FlowsIndexPage.vue';
import FlowEditorPage from './pages/FlowEditorPage.vue';
import FlowRunsPage from './pages/FlowRunsPage.vue';

const meta = {
  featureFlag: FEATURE_FLAGS.FLOWS,
  permissions: ['administrator'],
};

const flowsRoutes = {
  routes: [
    {
      path: frontendURL('accounts/:accountId/flows'),
      component: FlowsPageRouteView,
      children: [
        {
          path: '',
          name: 'flows_index',
          meta,
          component: FlowsIndexPage,
        },
        {
          path: 'new',
          name: 'flows_new',
          meta,
          component: FlowEditorPage,
        },
        {
          path: ':flowId',
          name: 'flows_edit',
          meta,
          component: FlowEditorPage,
        },
        {
          path: ':flowId/runs',
          name: 'flows_runs',
          meta,
          component: FlowRunsPage,
        },
      ],
    },
  ],
};

export default flowsRoutes;
