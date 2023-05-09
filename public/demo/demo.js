/**
 * @param {import("@vcmap/core").VcsApp} app
 * @returns {{stopped: VcsEvent<any>, stop: (function(): void)}}
 */
function createFeatureInfoSession(app) {
    /**
     * @class
     * @extends {import("@vcmap/core").AbstractInteraction}
     */
    class CustomFeatureInfoInteraction extends window.vcs.AbstractInteraction {
        /**
         * @param {string} layerName
         */
        constructor(layerName) {
            super(window.vcs.EventType.CLICK, window.vcs.ModificationKeyType.NONE);
            this.layerName = layerName;
            super.setActive();
        }
        /**
         * @param {import("@vcmap/core").InteractionEvent} event
         * @returns {Promise<import("@vcmap/core").InteractionEvent>}
         */
        async pipe(event) {
            if (event.feature) {
                // restrict alert to specific layer
                if (event.feature[window.vcs.vcsLayerName] === this.layerName) {
                    alert(`The ID of the selected feature is: ${event.feature.getId()}`);
                }
            }
            return event;
        }
    }

    const { eventHandler } = app.maps;
    /** @type {function():void} */
    let stop;
    const interaction = new CustomFeatureInfoInteraction('_demoDrawingLayer');
    const listener = eventHandler.addExclusiveInteraction(
        interaction,
        () => { stop?.(); },
    );
    const currentFeatureInteractionEvent = eventHandler.featureInteraction.active;
    eventHandler.featureInteraction.setActive(window.vcs.EventType.CLICK);

    const stopped = new window.vcs.VcsEvent();
    stop = () => {
        listener();
        interaction.destroy();
        eventHandler.featureInteraction.setActive(currentFeatureInteractionEvent);
        stopped.raiseEvent();
        stopped.destroy();
    };

    return {
        stopped,
        stop,
    };
}

/**
 * @param {import("@vcmap/core").VcsApp} app
 * @param {string} url
 * @returns {Promise<void>}
 */
async function loadModule(app, url) {
    const config = await fetch(url).then(response => response.json());
    const module = new window.vcs.VcsModule(config);
    await app.addModule(module);
}

/**
 * Creates a new VcsApp instance, sets the map target and loads a configuration file
 * @returns {Promise<void>}
 */
async function init() {
    document.querySelector('#vcmap-core').onload = () => {
        // init App and load a config file
        const vcsApp = new window.vcs.VcsApp();
        vcsApp.maps.setTarget('myMapUUID');
        loadModule(vcsApp, 'https://new.virtualcitymap.de/map.config.json');
        // create new feature info session to allow feature click interaction
        createFeatureInfoSession(vcsApp);
        // set cesium base url
        window.CESIUM_BASE_URL = '../dist/assets/cesium/';
        // adding helper instance to window
        window.vcsApp = vcsApp;
    }
}

/**
 * @param {VcsMap} map
 * @param {boolean} [out=false]
 * @param {number} [zoomFactor]
 * @returns {Promise<void>}
 */
async function zoom(map, out = false, zoomFactor = 2) {
    const viewpoint = await map.getViewpoint();
    if (out) {
        viewpoint.distance *= zoomFactor;
    } else {
        viewpoint.distance /= zoomFactor;
    }
    viewpoint.animate = true;
    viewpoint.duration = 0.5;
    viewpoint.cameraPosition = null;
    await map.gotoViewpoint(viewpoint);
}

/**
 * @param {MapCollection} maps
 * @param {string} mapName - name as defined in the module
 * @returns {Promise<void>}
 */
async function setActiveMap(maps, mapName) {
    await maps.setActiveMap(mapName);
}

/**
 * @param {import("@vcmap/ui").VcsUiApp} app
 * @returns {import("@vcmap/core").VectorLayer}
 */
function createSimpleEditorLayer(app) {
    const layer = new vcs.VectorLayer({
        name: '_demoDrawingLayer',
        projection: vcs.wgs84Projection.toJSON(),
        zIndex: vcs.maxZIndex - 1,
    });
    // layer style
    const style = new vcs.VectorStyleItem({
        fill: {
            color: '#ff0000',
        },
        stroke: {
            color: '#ffffff',
            width: 1,
        },
        image: {
            color: '#00ff00',
            src: '../dist/assets/cesium/Assets/Textures/pin.svg',
        },
    });
    layer.setStyle(style);
    // layer will not be serialized
    vcs.markVolatile(layer);
    // activate and add layer
    layer.activate();
    app.layers.add(layer);

    return layer;
}

/**
 * @param {import("@vcmap/core").VcsApp} app
 * @property {import("@vcmap/core").GeometryType} geometryType
 * @returns {function():void}
 */
function drawFeature(app, geometryType) {
    let layer = app.layers.getByKey('_demoDrawingLayer') || createSimpleEditorLayer(app);
    layer.activate();
    const session = vcs.startCreateFeatureSession(app, layer, geometryType);
    // adapt the features style
    const featureCreatedDestroy = session.featureCreated.addEventListener(feature => {
        if (feature.getGeometry() instanceof ol.geom.Point && layer.getFeatures().length > 1) {
            const pinStyle = new vcs.VectorStyleItem({});
            pinStyle.image = new ol.style.Icon({
                color: '#0000ff',
                src: '../dist/assets/cesium/Assets/Textures/pin.svg',
                scale: 2,
            });
            feature.setStyle(pinStyle.style);
        }
    });
    // to draw only a single feature, stop the session, after creationFinished was fired
    const finishedDestroy = session.creationFinished.addEventListener(() => {
        session.stop();
        // reactivate feature info by creating new feature info session
        createFeatureInfoSession(app);
    });
    const destroy = () => {
        featureCreatedDestroy();
        finishedDestroy();
    }
    return destroy;
}
