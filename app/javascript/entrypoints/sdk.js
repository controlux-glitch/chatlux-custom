import Cookies from 'js-cookie';
import { IFrameHelper } from '../sdk/IFrameHelper';
import {
  getBubbleView,
  getDarkMode,
  getWidgetStyle,
} from '../sdk/settingsHelper';
import {
  computeHashForUserData,
  getUserCookieName,
  hasUserKeys,
} from '../sdk/cookieHelpers';
import {
  addClasses,
  removeClasses,
  restoreWidgetInDOM,
} from '../sdk/DOMHelpers';
import { setCookieWithDomain } from '../sdk/cookieHelpers';
import { SDK_SET_BUBBLE_VISIBILITY } from 'shared/constants/sharedFrameEvents';

const CONTACT_ADDITIONAL_ATTRIBUTE_KEYS = [
  'company_name',
  'city',
  'country_code',
  'description',
  'social_profiles',
];

const CONTACT_USER_KEYS = [
  'identifier_hash',
  'email',
  'name',
  'avatar_url',
  'phone_number',
  ...CONTACT_ADDITIONAL_ATTRIBUTE_KEYS,
];

const normalizeObject = value =>
  value && typeof value === 'object' && !Array.isArray(value) ? value : {};

const buildInitialUserPayload = (userSettings, initialCustomAttributes = {}) => {
  const normalizedUserSettings = normalizeObject(userSettings);
  if (!Object.keys(normalizedUserSettings).length) {
    return null;
  }

  const {
    identifier,
    custom_attributes: nestedCustomAttributes,
    additional_attributes: nestedAdditionalAttributes,
    ...restUserSettings
  } = normalizedUserSettings;

  const user = {};

  CONTACT_USER_KEYS.forEach(key => {
    if (restUserSettings[key] !== undefined) {
      user[key] = restUserSettings[key];
    }
  });

  const extraCustomAttributes = Object.keys(restUserSettings).reduce(
    (acc, key) => {
      if (CONTACT_USER_KEYS.includes(key)) {
        return acc;
      }

      acc[key] = restUserSettings[key];
      return acc;
    },
    {}
  );

  const additionalAttributes = {
    ...normalizeObject(nestedAdditionalAttributes),
  };

  CONTACT_ADDITIONAL_ATTRIBUTE_KEYS.forEach(key => {
    if (user[key] !== undefined) {
      additionalAttributes[key] = user[key];
    }
  });

  const customAttributes = {
    ...normalizeObject(nestedCustomAttributes),
    ...extraCustomAttributes,
    ...normalizeObject(initialCustomAttributes),
  };

  if (Object.keys(additionalAttributes).length) {
    user.additional_attributes = additionalAttributes;
  }

  if (Object.keys(customAttributes).length) {
    user.custom_attributes = customAttributes;
  }

  return {
    identifier,
    user,
  };
};

const runSDK = ({ baseUrl, websiteToken }) => {
  if (window.$chatwoot) {
    return;
  }

  // if this is a Rails Turbo app
  document.addEventListener('turbo:before-render', event => {
    // when morphing the page, this typically happens on reload like events
    // say you update a "Customer" on a form and it reloads the page
    // We have already added data-turbo-permananent to true. This
    // will ensure that the widget it preserved
    // Read more about morphing here: https://turbo.hotwired.dev/handbook/page_refreshes#morphing
    // and peristing elements here: https://turbo.hotwired.dev/handbook/building#persisting-elements-across-page-loads
    if (event.detail.renderMethod === 'morph') return;

    restoreWidgetInDOM(event.detail.newBody);
  });

  if (window.Turbolinks) {
    document.addEventListener('turbolinks:before-render', event => {
      restoreWidgetInDOM(event.data.newBody);
    });
  }

  // if this is an astro app
  document.addEventListener('astro:before-swap', event =>
    restoreWidgetInDOM(event.newDocument.body)
  );

  const chatwootSettings = window.chatwootSettings || {};
  const initialCustomAttributes = normalizeObject(
    chatwootSettings.customAttributes
  );
  const initialUserPayload = buildInitialUserPayload(
    chatwootSettings.user || chatwootSettings.contact,
    initialCustomAttributes
  );
  const initialConversationCustomAttributes = normalizeObject(
    chatwootSettings.conversationCustomAttributes
  );
  let locale = chatwootSettings.locale;
  let baseDomain = chatwootSettings.baseDomain;

  if (chatwootSettings.useBrowserLanguage) {
    locale = window.navigator.language.replace('-', '_');
  }

  window.$chatwoot = {
    baseUrl,
    baseDomain,
    hasLoaded: false,
    hideMessageBubble: chatwootSettings.hideMessageBubble || false,
    isOpen: false,
    position: chatwootSettings.position === 'left' ? 'left' : 'right',
    websiteToken,
    locale,
    useBrowserLanguage: chatwootSettings.useBrowserLanguage || false,
    type: getBubbleView(chatwootSettings.type),
    launcherTitle: chatwootSettings.launcherTitle || '',
    showPopoutButton: chatwootSettings.showPopoutButton || false,
    showUnreadMessagesDialog: chatwootSettings.showUnreadMessagesDialog ?? true,
    widgetStyle: getWidgetStyle(chatwootSettings.widgetStyle) || 'standard',
    resetTriggered: false,
    darkMode: getDarkMode(chatwootSettings.darkMode),
    welcomeTitle: chatwootSettings.welcomeTitle || '',
    welcomeDescription: chatwootSettings.welcomeDescription || '',
    availableMessage: chatwootSettings.availableMessage || '',
    unavailableMessage: chatwootSettings.unavailableMessage || '',
    enableFileUpload: chatwootSettings.enableFileUpload,
    enableEmojiPicker: chatwootSettings.enableEmojiPicker ?? true,
    enableEndConversation: chatwootSettings.enableEndConversation ?? true,
    user: initialUserPayload,
    customAttributes: initialUserPayload ? {} : initialCustomAttributes,
    conversationCustomAttributes: initialConversationCustomAttributes,

    toggle(state) {
      IFrameHelper.events.toggleBubble(state);
    },

    toggleBubbleVisibility(visibility) {
      let widgetElm = document.querySelector('.woot--bubble-holder');
      let widgetHolder = document.querySelector('.woot-widget-holder');
      if (visibility === 'hide') {
        addClasses(widgetHolder, 'woot-widget--without-bubble');
        addClasses(widgetElm, 'woot-hidden');
        window.$chatwoot.hideMessageBubble = true;
      } else if (visibility === 'show') {
        removeClasses(widgetElm, 'woot-hidden');
        removeClasses(widgetHolder, 'woot-widget--without-bubble');
        window.$chatwoot.hideMessageBubble = false;
      }
      IFrameHelper.sendMessage(SDK_SET_BUBBLE_VISIBILITY, {
        hideMessageBubble: window.$chatwoot.hideMessageBubble,
      });
    },

    popoutChatWindow() {
      IFrameHelper.events.popoutChatWindow({
        baseUrl: window.$chatwoot.baseUrl,
        websiteToken: window.$chatwoot.websiteToken,
        locale,
      });
    },

    setUser(identifier, user) {
      if (typeof identifier !== 'string' && typeof identifier !== 'number') {
        throw new Error('Identifier should be a string or a number');
      }

      if (!hasUserKeys(user)) {
        throw new Error(
          'User object should have one of the keys [avatar_url, email, name]'
        );
      }

      const userCookieName = getUserCookieName();
      const existingCookieValue = Cookies.get(userCookieName);
      const hashToBeStored = computeHashForUserData({ identifier, user });
      if (hashToBeStored === existingCookieValue) {
        return;
      }

      window.$chatwoot.identifier = identifier;
      window.$chatwoot.user = user;
      IFrameHelper.sendMessage('set-user', { identifier, user });

      setCookieWithDomain(userCookieName, hashToBeStored, {
        baseDomain,
      });
    },

    setCustomAttributes(customAttributes = {}) {
      if (!customAttributes || !Object.keys(customAttributes).length) {
        throw new Error('Custom attributes should have atleast one key');
      } else {
        IFrameHelper.sendMessage('set-custom-attributes', { customAttributes });
      }
    },

    deleteCustomAttribute(customAttribute = '') {
      if (!customAttribute) {
        throw new Error('Custom attribute is required');
      } else {
        IFrameHelper.sendMessage('delete-custom-attribute', {
          customAttribute,
        });
      }
    },

    setConversationCustomAttributes(customAttributes = {}) {
      if (!customAttributes || !Object.keys(customAttributes).length) {
        throw new Error('Custom attributes should have atleast one key');
      } else {
        IFrameHelper.sendMessage('set-conversation-custom-attributes', {
          customAttributes,
        });
      }
    },

    deleteConversationCustomAttribute(customAttribute = '') {
      if (!customAttribute) {
        throw new Error('Custom attribute is required');
      } else {
        IFrameHelper.sendMessage('delete-conversation-custom-attribute', {
          customAttribute,
        });
      }
    },

    setLabel(label = '') {
      IFrameHelper.sendMessage('set-label', { label });
    },

    removeLabel(label = '') {
      IFrameHelper.sendMessage('remove-label', { label });
    },

    setLocale(localeToBeUsed = 'en') {
      IFrameHelper.sendMessage('set-locale', { locale: localeToBeUsed });
    },

    setColorScheme(darkMode = 'light') {
      IFrameHelper.sendMessage('set-color-scheme', {
        darkMode: getDarkMode(darkMode),
      });
    },

    reset() {
      if (window.$chatwoot.isOpen) {
        IFrameHelper.events.toggleBubble();
      }

      Cookies.remove('cw_conversation');
      Cookies.remove(getUserCookieName());

      const iframe = IFrameHelper.getAppFrame();
      iframe.src = IFrameHelper.getUrl({
        baseUrl: window.$chatwoot.baseUrl,
        websiteToken: window.$chatwoot.websiteToken,
      });

      window.$chatwoot.resetTriggered = true;
    },
  };

  IFrameHelper.createFrame({
    baseUrl,
    websiteToken,
  });
};

window.chatwootSDK = {
  run: runSDK,
};
