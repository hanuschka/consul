ProjektStudio.utils.postMessageToParentFromIframe = function(eventType, params) {
  if (window.parent) {
    window.parent.postMessage(
      JSON.stringify({
        event_type: eventType,
        params
      }),
      '*');
  }
}

ProjektStudio.utils.sendMessageToDtParentFrame = function(eventType, params) {
  postMessageToParentFromIframe(eventType, params)
}

ProjektStudio.utils.parseIframeEventData = function(eventData) {
  if (typeof eventData === "string") {
    return JSON.parse(eventData)
  } else if (typeof eventData === "object"){
    return eventData
  }
}
