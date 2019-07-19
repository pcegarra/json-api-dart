import 'package:json_api/src/document/decoding_exception.dart';
import 'package:json_api/src/document/link.dart';
import 'package:json_api/src/document/primary_data.dart';
import 'package:json_api/src/document/resource.dart';
import 'package:json_api/src/document/resource_object.dart';

/// Represents a single resource or a single related resource of a to-one relationship
class ResourceData extends PrimaryData {
  final ResourceObject resourceObject;

  ResourceData(this.resourceObject,
      {Link self, Iterable<ResourceObject> included, Map<String,int> resourcesInArrayPosition})
      : super(self: self, included: included, resourcesInArrayPosition:resourcesInArrayPosition);

  static ResourceData decodeJson(Object json) {
    if (json is Map) {
      final links = Link.decodeJsonMap(json['links']);
      final included = json['included'];
      final resources = <ResourceObject>[];
      if (included is List) {
        resources.addAll(included.map(ResourceObject.decodeJson));
      }

      final resourcesInArrayPosition = Map<String, int>();
      if(resources.isNotEmpty){
        int position = 0;
        resources.forEach((resource){
          resourcesInArrayPosition[resource.type+resource.id] = position;
          position++;
        });
      }


      final data = ResourceObject.decodeJson(json['data']);
      return ResourceData(data,
          self: links['self'],
          resourcesInArrayPosition: resourcesInArrayPosition.isNotEmpty ? resourcesInArrayPosition :null,
          included: resources.isNotEmpty ? resources : null);
    }
    throw DecodingException('Can not decode SingleResourceObject from $json');
  }

  @override
  Map<String, Object> toJson() {
    return {
      ...super.toJson(),
      'data': resourceObject,
      if (included != null && included.isNotEmpty) ...{'included': included},
      if (links.isNotEmpty) ...{'links': links},
    };
  }

  Resource unwrap() => resourceObject.unwrap();
}
