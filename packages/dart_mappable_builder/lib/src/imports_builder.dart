import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;

final path = p.posix;

class ImportsBuilder {
  final Map<Uri, int?> _imports = {};
  final AssetId _input;

  ImportsBuilder(this._input) {
    _imports[Uri.parse('package:dart_mappable/dart_mappable.dart')] = null;
    _imports[Uri.parse('package:dart_mappable/internals.dart')] = null;
  }

  int _nextPrefix() {
    var l = _imports.values.where((s) => s != null).length;
    return l;
  }

  int? add(Uri? import) {
    if (import == null) return null;
    if (import.scheme == 'package' &&
        import.pathSegments.first == 'dart_mappable') {
      return null;
    }
    if (import.scheme == 'dart') {
      if (import.path != 'core') {
        _imports[import] = null;
      }
      return null;
    }
    if (_imports.containsKey(import)) {
      return _imports[import];
    } else {
      return _imports[import] = _nextPrefix();
    }
  }

  String write() {
    List<String> sdk = [], package = [], relative = [];
    var prefixes = <String, int?>{};

    for (var import in _imports.keys) {
      if (import.isScheme('asset')) {
        var relativePath =
            path.relative(import.path, from: path.dirname(_input.uri.path));

        relative.add(relativePath);
        prefixes[relativePath] = _imports[import];
      } else if (import.isScheme('package') &&
          import.pathSegments.first == _input.package &&
          _input.pathSegments.first == 'lib') {
        var libPath =
            import.replace(pathSegments: import.pathSegments.skip(1)).path;

        var inputPath = _input.uri
            .replace(pathSegments: _input.uri.pathSegments.skip(1))
            .path;

        var relativePath =
            path.relative(libPath, from: path.dirname(inputPath));

        relative.add(relativePath);
        prefixes[relativePath] = _imports[import];
      } else if (import.scheme == 'dart') {
        sdk.add(import.toString());
        prefixes[import.toString()] = _imports[import];
      } else if (import.scheme == 'package') {
        package.add(import.toString());
        prefixes[import.toString()] = _imports[import];
      } else {
        relative.add(import.toString()); // TODO: is this correct?
        prefixes[import.toString()] = _imports[import];
      }
    }

    sdk.sort();
    package.sort();
    relative.sort();

    String joined(List<String> s) => s.isNotEmpty
        ? '${s.map((s) => "import '$s'${prefixes[s] != null ? ' as p${prefixes[s]}' : ''};").join('\n')}\n\n'
        : '';

    return joined(sdk) + joined(package) + joined(relative);
  }

  String prefixedType(DartType t, {bool withNullability = true}) {
    if (t is TypeParameterType) {
      return t.getDisplayString(withNullability: withNullability);
    }

    var typeArgs = '';
    if (t is InterfaceType && t.typeArguments.isNotEmpty) {
      typeArgs = '<${t.typeArguments.map(prefixedType).join(', ')}>';
    }

    var type = '${t.element2?.name}$typeArgs';

    if (withNullability && t.nullabilitySuffix == NullabilitySuffix.question) {
      type += '?';
    }

    var prefix = add(t.element2?.librarySource?.uri);
    return (prefix != null ? 'p$prefix.' : '') + type;
  }
}
