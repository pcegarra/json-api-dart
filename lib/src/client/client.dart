import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:json_api/src/client/custom_response.dart';
import 'package:json_api/src/client/simple_document_builder.dart';
import 'package:json_api/src/client/status_code.dart';
import 'package:json_api/src/document/document.dart';
import 'package:json_api/src/document/identifier.dart';
import 'package:json_api/src/document/primary_data.dart';
import 'package:json_api/src/document/relationship.dart';
import 'package:json_api/src/document/resource.dart';
import 'package:json_api/src/document/resource_collection_data.dart';
import 'package:json_api/src/document/resource_data.dart';
import 'package:json_api/src/document_builder.dart';

/// JSON:API client
class JsonApiClient {
  static const contentType = 'application/vnd.api+json';

  final Dio httpClient;
  final SimpleDocumentBuilder _build;

  const JsonApiClient(this.httpClient, {SimpleDocumentBuilder builder})
      : _build = builder ?? const DocumentBuilder();

  /// Fetches a resource collection by sending a GET query to the [uri].
  /// Use [headers] to pass extra HTTP headers.
  Future<CustomResponse<ResourceCollectionData>> fetchCollection(Uri uri,
          {Map<String, String> headers}) =>
      _call(_get(uri, headers), ResourceCollectionData.decodeJson);

  /// Fetches a single resource
  /// Use [headers] to pass extra HTTP headers.
  Future<CustomResponse<ResourceData>> fetchResource(Uri uri,
          {Map<String, String> headers}) =>
      _call(_get(uri, headers), ResourceData.decodeJson);

  /// Fetches a to-one relationship
  /// Use [headers] to pass extra HTTP headers.
  Future<CustomResponse<ToOne>> fetchToOne(Uri uri,
          {Map<String, String> headers}) =>
      _call(_get(uri, headers), ToOne.decodeJson);

  /// Fetches a to-many relationship
  /// Use [headers] to pass extra HTTP headers.
  Future<CustomResponse<ToMany>> fetchToMany(Uri uri,
          {Map<String, String> headers}) =>
      _call(_get(uri, headers), ToMany.decodeJson);

  /// Fetches a to-one or to-many relationship.
  /// The actual type of the relationship can be determined afterwards.
  /// Use [headers] to pass extra HTTP headers.
  Future<CustomResponse<Relationship>> fetchRelationship(Uri uri,
          {Map<String, String> headers}) =>
      _call(_get(uri, headers), Relationship.decodeJson);

  /// Creates a new resource. The resource will be added to a collection
  /// according to its type.
  ///
  /// https://jsonapi.org/format/#crud-creating
  Future<CustomResponse<ResourceData>> createResource(
          Uri uri, Resource resource, {Map<String, String> headers}) =>
      _call(_post(uri, headers, _build.resourceDocument(resource)),
          ResourceData.decodeJson);

  /// Deletes the resource.
  ///
  /// https://jsonapi.org/format/#crud-deleting
  Future<CustomResponse> deleteResource(Uri uri,
          {Map<String, String> headers}) =>
      _call(_delete(uri, headers), null);

  /// Updates the resource via PATCH query.
  ///
  /// https://jsonapi.org/format/#crud-updating
  Future<CustomResponse<ResourceData>> updateResource(
          Uri uri, Resource resource, {Map<String, String> headers}) =>
      _call(_patch(uri, headers, _build.resourceDocument(resource)),
          ResourceData.decodeJson);

  /// Updates a to-one relationship via PATCH query
  ///
  /// https://jsonapi.org/format/#crud-updating-to-one-relationships
  Future<CustomResponse<ToOne>> replaceToOne(Uri uri, Identifier identifier,
          {Map<String, String> headers}) =>
      _call(_patch(uri, headers, _build.toOneDocument(identifier)),
          ToOne.decodeJson);

  /// Removes a to-one relationship. This is equivalent to calling [replaceToOne]
  /// with id = null.
  Future<CustomResponse<ToOne>> deleteToOne(Uri uri,
          {Map<String, String> headers}) =>
      replaceToOne(uri, null, headers: headers);

  /// Replaces a to-many relationship with the given set of [identifiers].
  ///
  /// The server MUST either completely replace every member of the relationship,
  /// return an appropriate error response if some resources can not be found or accessed,
  /// or return a 403 Forbidden response if complete replacement is not allowed by the server.
  ///
  /// https://jsonapi.org/format/#crud-updating-to-many-relationships
  Future<CustomResponse<ToMany>> replaceToMany(
          Uri uri, List<Identifier> identifiers,
          {Map<String, String> headers}) =>
      _call(_patch(uri, headers, _build.toManyDocument(identifiers)),
          ToMany.decodeJson);

  /// Adds the given set of [identifiers] to a to-many relationship.
  ///
  /// The server MUST add the specified members to the relationship
  /// unless they are already present.
  /// If a given type and id is already in the relationship, the server MUST NOT add it again.
  ///
  /// Note: This matches the semantics of databases that use foreign keys
  /// for has-many relationships. Document-based storage should check
  /// the has-many relationship before appending to avoid duplicates.
  ///
  /// If all of the specified resources can be added to, or are already present in,
  /// the relationship then the server MUST return a successful response.
  ///
  /// Note: This approach ensures that a query is successful if the server’s state
  /// matches the requested state, and helps avoid pointless race conditions
  /// matches the requested state, and helps avoid pointless race conditions
  /// caused by multiple clients making the same changes to a relationship.
  ///
  /// https://jsonapi.org/format/#crud-updating-to-many-relationships
  Future<CustomResponse<ToMany>> addToMany(
          Uri uri, List<Identifier> identifiers,
          {Map<String, String> headers}) =>
      _call(_post(uri, headers, _build.toManyDocument(identifiers)),
          ToMany.decodeJson);

  Future<Response> _get(Uri uri, Map<String, String> headers) =>
      httpClient.get(uri.toString(), options: Options(headers: headers));

  Future<Response> _post(Uri uri, Map<String, String> headers, Document doc) =>
      httpClient.post(uri.toString(), data: json.encode(doc));

  Future<Response> _delete(Uri uri, Map<String, String> headers) =>
      httpClient.delete(uri.toString());

  Future<Response> _patch(uri, Map<String, String> headers, Document doc) =>
      httpClient.patch(uri.toString(), data: json.encode(doc));

  Future<CustomResponse<D>> _call<D extends PrimaryData>(
      Future<Response> res, D decodePrimaryData(Object _)) async {
    final response = await httpClient.resolve(res);

    dynamic data;
    int statusCode;
    DioHttpHeaders headers;
    if (response.data is Map) {
      data = response.data;
      statusCode = response.statusCode;
      headers = response.headers;
    }
    else{
        DioError error = response.data;
        statusCode = error.response.statusCode;
        headers = error.response.headers;
        data = error.response.data;
    }

    return CustomResponse(statusCode, headers,
        document: Document.decodeJson(
            data is Map ? data : jsonDecode(data), decodePrimaryData));
  }
}
