ProjektStudio.utils.postMessageToParentFromIframe = function(eventType, params) {
  if (window.parent) {
    window.parent.postMessage(
      {
        event_type: eventType,
        params
      },
      '*');
  }
}

ProjektStudio.utils.sendMessageToDtParentFrame = function(eventType, params) {
  ProjektStudio.utils.postMessageToParentFromIframe(eventType, params)
}
