define(['./defaultValue-0a909f67', './Matrix3-315394f6', './arrayRemoveDuplicates-c2038105', './BoundingRectangle-be5924f4', './Transforms-40229881', './Matrix2-13178034', './ComponentDatatype-f7b11d02', './PolylineVolumeGeometryLibrary-a510d657', './Check-666ab1a0', './GeometryAttribute-7d6f1732', './GeometryAttributes-f06a2792', './GeometryPipeline-ce4339ed', './IndexDatatype-a55ceaa1', './Math-2dbd6b93', './PolygonPipeline-844aab0a', './VertexFormat-6b480673', './combine-ca22a614', './RuntimeError-06c93819', './WebGLConstants-a8cc3e8c', './EllipsoidTangentPlane-214683dc', './AxisAlignedBoundingBox-ff186ccc', './IntersectionTests-f6e6bd8a', './Plane-900aa728', './PolylinePipeline-32f36d2a', './EllipsoidGeodesic-98c62a56', './EllipsoidRhumbLine-19756602', './AttributeCompression-b646d393', './EncodedCartesian3-81f70735'], function (defaultValue, Matrix3, arrayRemoveDuplicates, BoundingRectangle, Transforms, Matrix2, ComponentDatatype, PolylineVolumeGeometryLibrary, Check, GeometryAttribute, GeometryAttributes, GeometryPipeline, IndexDatatype, Math, PolygonPipeline, VertexFormat, combine, RuntimeError, WebGLConstants, EllipsoidTangentPlane, AxisAlignedBoundingBox, IntersectionTests, Plane, PolylinePipeline, EllipsoidGeodesic, EllipsoidRhumbLine, AttributeCompression, EncodedCartesian3) {
  'use strict';

  function computeAttributes(combinedPositions, shape, boundingRectangle, vertexFormat) {
    var attributes = new GeometryAttributes.GeometryAttributes();
    if (vertexFormat.position) {
      attributes.position = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.DOUBLE,
        componentsPerAttribute: 3,
        values: combinedPositions
      });
    }
    var shapeLength = shape.length;
    var vertexCount = combinedPositions.length / 3;
    var length = (vertexCount - shapeLength * 2) / (shapeLength * 2);
    var firstEndIndices = PolygonPipeline.PolygonPipeline.triangulate(shape);
    var indicesCount = (length - 1) * shapeLength * 6 + firstEndIndices.length * 2;
    var indices = IndexDatatype.IndexDatatype.createTypedArray(vertexCount, indicesCount);
    var i, j;
    var ll, ul, ur, lr;
    var offset = shapeLength * 2;
    var index = 0;
    for (i = 0; i < length - 1; i++) {
      for (j = 0; j < shapeLength - 1; j++) {
        ll = j * 2 + i * shapeLength * 2;
        lr = ll + offset;
        ul = ll + 1;
        ur = ul + offset;
        indices[index++] = ul;
        indices[index++] = ll;
        indices[index++] = ur;
        indices[index++] = ur;
        indices[index++] = ll;
        indices[index++] = lr;
      }
      ll = shapeLength * 2 - 2 + i * shapeLength * 2;
      ul = ll + 1;
      ur = ul + offset;
      lr = ll + offset;
      indices[index++] = ul;
      indices[index++] = ll;
      indices[index++] = ur;
      indices[index++] = ur;
      indices[index++] = ll;
      indices[index++] = lr;
    }
    if (vertexFormat.st || vertexFormat.tangent || vertexFormat.bitangent) {
      // st required for tangent/bitangent calculation
      var st = new Float32Array(vertexCount * 2);
      var lengthSt = 1 / (length - 1);
      var heightSt = 1 / boundingRectangle.height;
      var heightOffset = boundingRectangle.height / 2;
      var s, t;
      var stindex = 0;
      for (i = 0; i < length; i++) {
        s = i * lengthSt;
        t = heightSt * (shape[0].y + heightOffset);
        st[stindex++] = s;
        st[stindex++] = t;
        for (j = 1; j < shapeLength; j++) {
          t = heightSt * (shape[j].y + heightOffset);
          st[stindex++] = s;
          st[stindex++] = t;
          st[stindex++] = s;
          st[stindex++] = t;
        }
        t = heightSt * (shape[0].y + heightOffset);
        st[stindex++] = s;
        st[stindex++] = t;
      }
      for (j = 0; j < shapeLength; j++) {
        s = 0;
        t = heightSt * (shape[j].y + heightOffset);
        st[stindex++] = s;
        st[stindex++] = t;
      }
      for (j = 0; j < shapeLength; j++) {
        s = (length - 1) * lengthSt;
        t = heightSt * (shape[j].y + heightOffset);
        st[stindex++] = s;
        st[stindex++] = t;
      }
      attributes.st = new GeometryAttribute.GeometryAttribute({
        componentDatatype: ComponentDatatype.ComponentDatatype.FLOAT,
        componentsPerAttribute: 2,
        values: new Float32Array(st)
      });
    }
    var endOffset = vertexCount - shapeLength * 2;
    for (i = 0; i < firstEndIndices.length; i += 3) {
      var v0 = firstEndIndices[i] + endOffset;
      var v1 = firstEndIndices[i + 1] + endOffset;
      var v2 = firstEndIndices[i + 2] + endOffset;
      indices[index++] = v0;
      indices[index++] = v1;
      indices[index++] = v2;
      indices[index++] = v2 + shapeLength;
      indices[index++] = v1 + shapeLength;
      indices[index++] = v0 + shapeLength;
    }
    var geometry = new GeometryAttribute.Geometry({
      attributes: attributes,
      indices: indices,
      boundingSphere: Transforms.BoundingSphere.fromVertices(combinedPositions),
      primitiveType: GeometryAttribute.PrimitiveType.TRIANGLES
    });
    if (vertexFormat.normal) {
      geometry = GeometryPipeline.GeometryPipeline.computeNormal(geometry);
    }
    if (vertexFormat.tangent || vertexFormat.bitangent) {
      try {
        geometry = GeometryPipeline.GeometryPipeline.computeTangentAndBitangent(geometry);
      } catch (e) {
        PolylineVolumeGeometryLibrary.oneTimeWarning("polyline-volume-tangent-bitangent", "Unable to compute tangents and bitangents for polyline volume geometry");
        //TODO https://github.com/CesiumGS/cesium/issues/3609
      }

      if (!vertexFormat.tangent) {
        geometry.attributes.tangent = undefined;
      }
      if (!vertexFormat.bitangent) {
        geometry.attributes.bitangent = undefined;
      }
      if (!vertexFormat.st) {
        geometry.attributes.st = undefined;
      }
    }
    return geometry;
  }

  /**
   * A description of a polyline with a volume (a 2D shape extruded along a polyline).
   *
   * @alias PolylineVolumeGeometry
   * @constructor
   *
   * @param {Object} options Object with the following properties:
   * @param {Cartesian3[]} options.polylinePositions An array of {@link Cartesian3} positions that define the center of the polyline volume.
   * @param {Cartesian2[]} options.shapePositions An array of {@link Cartesian2} positions that define the shape to be extruded along the polyline
   * @param {Ellipsoid} [options.ellipsoid=Ellipsoid.WGS84] The ellipsoid to be used as a reference.
   * @param {Number} [options.granularity=CesiumMath.RADIANS_PER_DEGREE] The distance, in radians, between each latitude and longitude. Determines the number of positions in the buffer.
   * @param {VertexFormat} [options.vertexFormat=VertexFormat.DEFAULT] The vertex attributes to be computed.
   * @param {CornerType} [options.cornerType=CornerType.ROUNDED] Determines the style of the corners.
   *
   * @see PolylineVolumeGeometry#createGeometry
   *
   * @demo {@link https://sandcastle.cesium.com/index.html?src=Polyline%20Volume.html|Cesium Sandcastle Polyline Volume Demo}
   *
   * @example
   * function computeCircle(radius) {
   *   const positions = [];
   *   for (let i = 0; i < 360; i++) {
   *     const radians = Cesium.Math.toRadians(i);
   *     positions.push(new Cesium.Cartesian2(radius * Math.cos(radians), radius * Math.sin(radians)));
   *   }
   *   return positions;
   * }
   *
   * const volume = new Cesium.PolylineVolumeGeometry({
   *   vertexFormat : Cesium.VertexFormat.POSITION_ONLY,
   *   polylinePositions : Cesium.Cartesian3.fromDegreesArray([
   *     -72.0, 40.0,
   *     -70.0, 35.0
   *   ]),
   *   shapePositions : computeCircle(100000.0)
   * });
   */
  function PolylineVolumeGeometry(options) {
    options = defaultValue.defaultValue(options, defaultValue.defaultValue.EMPTY_OBJECT);
    var positions = options.polylinePositions;
    var shape = options.shapePositions;

    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(positions)) {
      throw new Check.DeveloperError("options.polylinePositions is required.");
    }
    if (!defaultValue.defined(shape)) {
      throw new Check.DeveloperError("options.shapePositions is required.");
    }
    //>>includeEnd('debug');

    this._positions = positions;
    this._shape = shape;
    this._ellipsoid = Matrix3.Ellipsoid.clone(defaultValue.defaultValue(options.ellipsoid, Matrix3.Ellipsoid.WGS84));
    this._cornerType = defaultValue.defaultValue(options.cornerType, PolylineVolumeGeometryLibrary.CornerType.ROUNDED);
    this._vertexFormat = VertexFormat.VertexFormat.clone(defaultValue.defaultValue(options.vertexFormat, VertexFormat.VertexFormat.DEFAULT));
    this._granularity = defaultValue.defaultValue(options.granularity, Math.CesiumMath.RADIANS_PER_DEGREE);
    this._workerName = "createPolylineVolumeGeometry";
    var numComponents = 1 + positions.length * Matrix3.Cartesian3.packedLength;
    numComponents += 1 + shape.length * Matrix2.Cartesian2.packedLength;

    /**
     * The number of elements used to pack the object into an array.
     * @type {Number}
     */
    this.packedLength = numComponents + Matrix3.Ellipsoid.packedLength + VertexFormat.VertexFormat.packedLength + 2;
  }

  /**
   * Stores the provided instance into the provided array.
   *
   * @param {PolylineVolumeGeometry} value The value to pack.
   * @param {Number[]} array The array to pack into.
   * @param {Number} [startingIndex=0] The index into the array at which to start packing the elements.
   *
   * @returns {Number[]} The array that was packed into
   */
  PolylineVolumeGeometry.pack = function (value, array, startingIndex) {
    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(value)) {
      throw new Check.DeveloperError("value is required");
    }
    if (!defaultValue.defined(array)) {
      throw new Check.DeveloperError("array is required");
    }
    //>>includeEnd('debug');

    startingIndex = defaultValue.defaultValue(startingIndex, 0);
    var i;
    var positions = value._positions;
    var length = positions.length;
    array[startingIndex++] = length;
    for (i = 0; i < length; ++i, startingIndex += Matrix3.Cartesian3.packedLength) {
      Matrix3.Cartesian3.pack(positions[i], array, startingIndex);
    }
    var shape = value._shape;
    length = shape.length;
    array[startingIndex++] = length;
    for (i = 0; i < length; ++i, startingIndex += Matrix2.Cartesian2.packedLength) {
      Matrix2.Cartesian2.pack(shape[i], array, startingIndex);
    }
    Matrix3.Ellipsoid.pack(value._ellipsoid, array, startingIndex);
    startingIndex += Matrix3.Ellipsoid.packedLength;
    VertexFormat.VertexFormat.pack(value._vertexFormat, array, startingIndex);
    startingIndex += VertexFormat.VertexFormat.packedLength;
    array[startingIndex++] = value._cornerType;
    array[startingIndex] = value._granularity;
    return array;
  };
  var scratchEllipsoid = Matrix3.Ellipsoid.clone(Matrix3.Ellipsoid.UNIT_SPHERE);
  var scratchVertexFormat = new VertexFormat.VertexFormat();
  var scratchOptions = {
    polylinePositions: undefined,
    shapePositions: undefined,
    ellipsoid: scratchEllipsoid,
    vertexFormat: scratchVertexFormat,
    cornerType: undefined,
    granularity: undefined
  };

  /**
   * Retrieves an instance from a packed array.
   *
   * @param {Number[]} array The packed array.
   * @param {Number} [startingIndex=0] The starting index of the element to be unpacked.
   * @param {PolylineVolumeGeometry} [result] The object into which to store the result.
   * @returns {PolylineVolumeGeometry} The modified result parameter or a new PolylineVolumeGeometry instance if one was not provided.
   */
  PolylineVolumeGeometry.unpack = function (array, startingIndex, result) {
    //>>includeStart('debug', pragmas.debug);
    if (!defaultValue.defined(array)) {
      throw new Check.DeveloperError("array is required");
    }
    //>>includeEnd('debug');

    startingIndex = defaultValue.defaultValue(startingIndex, 0);
    var i;
    var length = array[startingIndex++];
    var positions = new Array(length);
    for (i = 0; i < length; ++i, startingIndex += Matrix3.Cartesian3.packedLength) {
      positions[i] = Matrix3.Cartesian3.unpack(array, startingIndex);
    }
    length = array[startingIndex++];
    var shape = new Array(length);
    for (i = 0; i < length; ++i, startingIndex += Matrix2.Cartesian2.packedLength) {
      shape[i] = Matrix2.Cartesian2.unpack(array, startingIndex);
    }
    var ellipsoid = Matrix3.Ellipsoid.unpack(array, startingIndex, scratchEllipsoid);
    startingIndex += Matrix3.Ellipsoid.packedLength;
    var vertexFormat = VertexFormat.VertexFormat.unpack(array, startingIndex, scratchVertexFormat);
    startingIndex += VertexFormat.VertexFormat.packedLength;
    var cornerType = array[startingIndex++];
    var granularity = array[startingIndex];
    if (!defaultValue.defined(result)) {
      scratchOptions.polylinePositions = positions;
      scratchOptions.shapePositions = shape;
      scratchOptions.cornerType = cornerType;
      scratchOptions.granularity = granularity;
      return new PolylineVolumeGeometry(scratchOptions);
    }
    result._positions = positions;
    result._shape = shape;
    result._ellipsoid = Matrix3.Ellipsoid.clone(ellipsoid, result._ellipsoid);
    result._vertexFormat = VertexFormat.VertexFormat.clone(vertexFormat, result._vertexFormat);
    result._cornerType = cornerType;
    result._granularity = granularity;
    return result;
  };
  var brScratch = new BoundingRectangle.BoundingRectangle();

  /**
   * Computes the geometric representation of a polyline with a volume, including its vertices, indices, and a bounding sphere.
   *
   * @param {PolylineVolumeGeometry} polylineVolumeGeometry A description of the polyline volume.
   * @returns {Geometry|undefined} The computed vertices and indices.
   */
  PolylineVolumeGeometry.createGeometry = function (polylineVolumeGeometry) {
    var positions = polylineVolumeGeometry._positions;
    var cleanPositions = arrayRemoveDuplicates.arrayRemoveDuplicates(positions, Matrix3.Cartesian3.equalsEpsilon);
    var shape2D = polylineVolumeGeometry._shape;
    shape2D = PolylineVolumeGeometryLibrary.PolylineVolumeGeometryLibrary.removeDuplicatesFromShape(shape2D);
    if (cleanPositions.length < 2 || shape2D.length < 3) {
      return undefined;
    }
    if (PolygonPipeline.PolygonPipeline.computeWindingOrder2D(shape2D) === PolygonPipeline.WindingOrder.CLOCKWISE) {
      shape2D.reverse();
    }
    var boundingRectangle = BoundingRectangle.BoundingRectangle.fromPoints(shape2D, brScratch);
    var computedPositions = PolylineVolumeGeometryLibrary.PolylineVolumeGeometryLibrary.computePositions(cleanPositions, shape2D, boundingRectangle, polylineVolumeGeometry, true);
    return computeAttributes(computedPositions, shape2D, boundingRectangle, polylineVolumeGeometry._vertexFormat);
  };
  function createPolylineVolumeGeometry(polylineVolumeGeometry, offset) {
    if (defaultValue.defined(offset)) {
      polylineVolumeGeometry = PolylineVolumeGeometry.unpack(polylineVolumeGeometry, offset);
    }
    polylineVolumeGeometry._ellipsoid = Matrix3.Ellipsoid.clone(polylineVolumeGeometry._ellipsoid);
    return PolylineVolumeGeometry.createGeometry(polylineVolumeGeometry);
  }
  return createPolylineVolumeGeometry;
});