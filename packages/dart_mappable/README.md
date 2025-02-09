Imagine a mapping & serialization package with:

- **NO** nasty boilerplate code
- **NO** minified/uglified generated files
- **NO** workarounds
- **NO** compromises

while being able to

- **decode & encode** json
- come with built-in **type & null-safety**
- be **fully configurable**
- support **custom types**, **generics**, **polymorphism** and more.

Sounds too good to be true? Not anymore.

# Dart Mappable

`dart_mappable` is an improved json serialization and data-class package that can replace `json_serializable`
or other similar packages. It covers all basic features *(from/to json, == override, toString() override, ...)* 
while adding new or improved support for advances use-cases like generics, inheritance and customization.

> Have a look at the example!

- [Get Started](#get-started)
- [How to use](#how-to-use)
  - [Annotations](#annotations)
  - [Global options](#global-options)
  - [Mapper interface](#mapper-interface)
  - [Generation Methods](#generation-methods)
  - [Utilize Constructors](#utilize-constructors)
  - [Case Styles](#case-styles)
  - [Custom Enum Values](#custom-enum-values)
- [Lists, Sets and Maps](#lists-sets-and-maps)
  - [Non-Trivial Maps](#non-trivial-maps)
- [CopyWith](#copywith)
  - [Deep Copy](#deep-copy)
- [Polymorphism and Discriminators](#polymorphism-and-discriminators)
  - [Null and Default Values](#null-and-default-values)
  - [CopyWith and Polymorphism](#copywith-and-polymorphism)
- [Encoding / Decoding Hooks](#encoding--decoding-hooks)
  - [Unmapped Properties](#unmapped-properties)
- [Custom Mappers](#custom-mappers)
  - [Generic Custom Types](#generic-custom-types)
  - [Custom Iterables and Maps](#custom-iterables-and-maps)
- [Supported Packages](#supported-packages)
  - [Freezed](#freezed)

> This package is still in active development. If you have any feedback or feature requests, write me and issue on github.

## Get Started

First, add `dart_mappable` as a dependency, together with `dart_mappable_builder` and `build_runner` as a dev_dependency.

```shell script
flutter pub add dart_mappable
flutter pub add build_runner --dev
flutter pub add dart_mappable_builder --dev
```

Next, create a `build.yaml` in the root directory of your package and add this snippet:

```yaml
targets:
  $default:
    builders:
      dart_mappable_builder:
        generate_for:
          - lib/main.dart # modify this if you have a different entry point
```

Then annotate your classes that you want to use with `@MappableClass()`:

```dart
import 'package:dart_mappable/dart_mappable.dart';

@MappableClass()
class MyClass with MyClassMappable {
  final int myValue;
  
  MyClass(this.myValue);
}
```

To use a class you must:

- annotate the class with `@MappableClass()` and
- apply a mixin with the name of the class plus `Mappable`.

> Don't worry if the mixin don't exist at first, just run code-generation once an it will be created.
> The builder will also warn you if you define your class without the proper mixin.

> For generic classes (e.g. `MyClass<T>`) make sure to also provide all type parameters 
> to the mixin (`... with MyClassMappable<T>`).

In order to generate the serialization code, run the following command:

```shell script
pub run build_runner build
```

> You'll need to re-run code generation each time you are making changes to your annotated classes.
> During development, you can use `watch` to automatically watch your changes:
> `pub run build_runner watch`

This will generate a `.mapper.g.dart` file for each of your entry points specified in the `build.yaml` file.

Last step is to `import` the generated file wherever you want / need them. There are two main ways to 
interact with your models using this package: Through the generated `Mapper` class, or through the methods
defined by the generated mixin:

```dart

import 'main.mapper.g.dart'; // import the generated file

void main() {
  // Option 1: Use the [Mapper] class, e.g. for:
  // - decoding
  var myClass = Mapper.fromJson<MyClass>('{"myValue": 123}');
  // - encoding
  var json = Mapper.toJson(myClass);
  
  // Option 2: Use the methods on your class provided by the mixin, e.g. for:
  // - encoding
  var json = myClass.toJson();
  // - copyWith
  var myClass2 = myClass.copyWith(myValue: 0);
}
```

Checkout [Mapper Interface](#mapper-interface) for a full list of available methods.

## How to use

### Annotations

The recommended way to use `dart_mappable` is to annotate your model classes with `@MappableClass()` and your enums with `@MappableEnum()`.
Each annotation has a set of properties to configure the generated code.

```dart
@MappableClass()
class MyClass { ... }

@MappableEnum()
enum MyEnum { ... }
```

The properties are documented  [here](https://pub.dev/documentation/dart_mappable/latest/dart_mappable/MappableClass-class.html) for `@MappableClass()` 
and [here](https://pub.dev/documentation/dart_mappable/latest/dart_mappable/MappableEnum-class.html) for `@MappableEnum()`.

For deserialization, `dart_mappable` will use the first available constructor of a class, but you can use a specific constructor using the `@MappableConstructor()` annotation.

```dart
@MappableClass()
class MyClass {
  MyClass(); // Don't use this
  
  @MappableConstructor()
  MyClass.special(); // Use this
}
```

You can also annotate a single field or constructor parameter of a class using `@MappableField()` to set a specific json key or add [hooks](#encoding--decoding-hooks). 

```dart
@MappableClass()
class MyClass {
  MyClass(this.value);

  @MappableField(key: 'my_key')
  String value;
}
```

*Note: This can only be used on a field if it is directly assigned as a constructor parameter (`MyClass(this.myField)`). 
Setting this annotation on any other field will have no effect. 
(See [Utilize Constructors](#utilize-constructors) for an explanation why this is.)*

You can add the `@MappableLib()` annotation to your `library` statement to set a default configuration for all included classes and enums, e.g. the [case style](#case-styles).

```dart
@MappableLib(caseStyle: CaseStyle.camelCase) // will be applied to all classes
library models;

@MappableClass() // no need to set caseStyle here
class MyClass {
  ...
}
```

You can also use the `include` and `exclude` property to add any or all classes and enums in a library. Using `exclude` will result in 
all classes in a library except the specified ones to be included.

Classes or enums specified using those properties do not need to have the `@MappableClass()` or `@MappableEnum()` annotation.
Classes that are included in this way will not have a generated mixin but rather extension methods.

```dart
@MappableLib(include: [MyClass])
library models;

// will be used even without annotation
class MyClass {
  ...
}
```

The `@MappableLib()` annotation can also be used on `import` or `export` statements. This is especially useful when you want to use classes from an external package, since you can't modify its code and add the necessary annotations to its classes and enums.

```dart
@MappableLib(include: [ClassA, ClassB]) // ClassA and ClassB are defined in external_package
import 'package:external_package/external_package.dart';

...
```

Lastly, you can define [custom mappers](#custom-mappers) using the '@CustomMapper()' annotation.

---

Here are again all **seven** annotations that you can use in your code:

1. `@MappableClass()` can be used on a class to specify options like the `caseStyle` of the json keys, whether to ignore null values, or [hooks](#encoding--decoding-hooks).
2. `@MappableConstructor()` can be used on a constructor to mark this to be used for decoding. It has no properties.
3. `@MappableField()` can be used on a constructor parameter or a field to specify a json key to be used instead of the field name, or [hooks](#encoding--decoding-hooks).
4. `@MappableEnum()` can be used on an enum to specify the `mode` or `caseStyle` of the encoded enum values, or the `defaultValue`.
5. `@MappableValue()` can be used on an enum value to specify a custom encoded value to use.
6. `@MappableLib()` can be used on a library statement or import / export statement to set a default configuration for the annotated library or include / exclude classes.
7. `@CustomMapper()` can be used to specify a custom mapper, used alongside the generated mappers. See [Custom Mappers](#custom-mappers) for a details explanation.

For an overview of all the annotation properties, head to the [Api Documentation](https://pub.dev/documentation/dart_mappable/latest/dart_mappable/dart_mappable-library.html).

### Global options

Additionally to using the `@MappableClass()` and `@MappableLib()` annotations for configuration, you can also define a subset of their properties as global options in the `build.yaml` file:

```yaml
targets:
  $default:
    builders:
      dart_mappable_builder:
        generate_for:
          - lib/main.dart
          - lib/models.dart # multiple independent entry files
        options:
          # the case style for the map keys, defaults to 'none'
          caseStyle: none # or 'camelCase', 'snakeCase', etc.
          # the case style for stringified enum values, defaults to 'none'
          enumCaseStyle: none # or 'camelCase', 'snakeCase', etc.
          # if true removes all map keys with null values
          ignoreNull: false # or true
          # used as property name for type discriminators
          discriminatorKey: type
          # used to specify which methods to generate (all by default)
          generateMethods: [decode, encode, copy, stringify, equals]
```

### Mapper Interface

`dart_mappable` will generate a main `Mapper` class that provides access to all important methods:

- `Mapper.fromValue<T>(encoded)` will take an encoded object and return a decoded object of type `T`.
- `Mapper.fromMap<T>(encoded)` and `Mapper.fromJson<T>(encoded)` internally use `fromValue` but expect a `Map<String, dynamic>` or `String` respectively.
- `Mapper.toValue<T>(T decoded)` will take any object and return an encoded object of type `dynamic` (usually a `Map<String, dynamic>` for custom classes).
- `Mapper.toMap<T>(T decoded)` and `Mapper.toJson<T>(T encoded)` internally use `toValue` but will return a `Map<String, dynamic>` or `String` respectively.
- `Mapper.isEqual(a, b)` will compare two objects for equality.
- `Mapper.asString(o)` will return a string representation of an object.

The generated mixins will come with the following methods:

- `toMap()` and `toJson()`, which internally call `Mapper.toMap()` and `Mapper.toJson()` respectively.
- `copyWith()` to create copies of your class instance (see [Copy With](#copywith)).
- overrides for `operator ==`, `hashCode` and `toString()`.

### Generation Methods

This package can generate a few different sets of methods, which can be activated or deactivated. 
This makes sure that only code is generated that you actually need.
By default, all methods are generated for each class.

You can set the `generateMethods` property to specify which methods to generate. Either in the **global options** using a List of Strings, or with a **annotation** using the `GenerateMethods` flags. 
The following methods are supported:

- **decode**: Will generate code used by `Mapper.fromJson`, `Mapper.fromMap` and `Mapper.fromValue`.
- **encode**: Will generate code used by `Mapper.toJson`, `Mapper.toMap` and `Mapper.toValue` as well as the mixin methods `toJson` and `toMap`.
- **copy**: Will generate the mixin method `copyWith`.
- **stringify**: Will generate code used by `Mapper.asString` and the mixin's `toString` override.
- **equals**: Will generate code used by `Mapper.isEqual` and the mixin's `==` and `hashCode` overrides.

When using **annotations**, you can specify multiple methods using the *bitwise-or* operator like this: 
`@MappableClass(generateMethods: GenerateMethods.copy | GenerateMethods.equals | GenerateMethods.stringify)`.

### Utilize Constructors

There exist a lot of custom use cases, when it comes to mapping json to an object. Common ones include:

- providing **default values** to optional fields,
- **renaming** fields,
- **ignoring** fields, 
- **custom formats** for dates or numbers,
- **computing values**,
- ... and lots more.

Instead of providing custom tailored serialization options for some selected use-cases, this package 
utilizes the power of constructor arguments to cover all of them. Thereby, you keep full control
over your models, while writing pure and easy dart code.

*How does that work exactly:* When analysing your code, `dart_mappable` **never looks at the fields** 
of your model, but rather only at the **constructor arguments**; What you do with them - writing to 
fields, renaming, etc. - is up to your model's implementation. To illustrate this, here are some 
examples for the above mentioned use cases:

```dart
class Person {
  String name;
  int age;
    
  // basic example, nothing special going on
  Person.base(this.name, this.age);
  
  // setting default values for some parameters
  Person.opt(this.name, [this.age = 18]);

  // renamed argument, will be 'years': ... in json
  Person.renamed(this.name, int years) : age = years;
  // IMPORTANT: when renaming arguments, make sure to always have a matching getter for serialization (*)
  int get years => age;
  
  // ignores the age field completely
  Person.ignored(this.name);
 
  // computed name value
  Person.computed(String firstName, String lastName, this.age) : name = '$firstName $lastName';
  // IMPORTANT (again): have matching getters for all arguments, reversing the computed value (*)
  String get firstName => name.split(' ')[0];
  String get lastName => name.split(' ')[1];
}

class Event {
  DateTime date;

  // custom formatting as unix timestamp
  Event.format(int timestamp) : date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  int get timestamp => date.millisecondsSinceEpoch;
}
```

**(\*) Regarding the matching getters:** Not-having them won't break your code. 
However this will lead to desynched serialization (keys missing in your json) and eventually to 
errors when trying to deserialize back. You will also get a warning in the builder output to know 
when this happens.

*Remember: dart_mappable will always use the first constructor it sees, but you can use a specific 
constructor using the `@MappableConstructor()` annotation.*

### Case Styles

You can specify the case style for the json keys and your stringified enum values. Choose one of the 
existing styles or specify a custom one.

Currently supported are:
```yaml
none / unmodified: keeps your field names as the are (default)
camelCase: myFieldName -> myFieldName (dart default)
pascalCase: myFieldName -> MyFieldName
snakeCase: myFieldName -> my_field_name
paramCase: myFieldName -> my-field-name
lowerCase: myFieldName -> myfieldname
upperCase: myFieldName -> MYFIELDNAME
```

You can also specify a custom case style using the `custom(ab,c)` syntax. 

- The letters before the comma define how to transform each word of a field name. They can be either 
  `l` for `lowerCase`, `u` for `upperCase`, or `c` for `capitalCase`. When using only one letter, 
  it is applied to all words. When using two letters, the first one is applied to only the first word 
  and the second one to all remaining words.
- The one letter after the comma defines the separator between each word, like `_` or `-`. This can 
  be any character or empty.

Here are some examples that can be achieved using this syntax:
```yaml
custom(u,_): myFieldName -> MY_FIELD_NAME
custom(uc,+): myFieldName -> MY+Field+Name
custom(cl,): myFieldName -> Myfieldname
```

### Custom Enum Values

When using the `@MappableEnum()` annotation you can set the `mode` property to one of two `ValuesMode`s for the encoding of enum values:

- `ValuesMode.named` is the default and will encode all values to their respective names as `String`s, after applying the optional `caseStyle`.
- `ValuesMode.indexed` will encode all values to their respective index as `int`s.

You can also specify a custom encoded value for each enum value using the `@MappableValue(myCustomValue)` annotation. 
It is possible to mix the encoding mode with custom values, and use values of different types.

```dart
@MappableEnum(mode: ValuesMode.indexed)
enum Status {
  zero,                         // encodes to 0
  @MappableValue(200) success,  // encodes to 200
  @MappableValue('error') error // encodes to 'error'
}
```

## Lists, Sets and Maps

`dart_mappable` support `List`s, `Set`s and `Map`s out of the box, without any special syntax, workarounds or hacks. Just use `Mapper.fromJson` as you normally would:

```dart
class Dog with DogMappable {
  String name;
  Dog(this.name);
}

class Box<T> with BoxMappable<T> {
  T content;
  Box(this.content);
}

void main() {

  // simple list
  List<int> nums = Mapper.fromJson('[2, 4, 105]');
  print(nums); // [2, 4, 105]

  // set of objects
  Set<Dog> dogs = Mapper.fromJson('[{"name": "Thor"}, {"name": "Lasse"}, {"name": "Thor"}]');
  print(dogs); // {Dog(name: Thor), Dog(name: Lasse)}

  // or more complex lists, like generics
  List<Box<double>> boxes = Mapper.fromJson('[{"content": 0.1}, {"content": 12.34}]');
  print(boxes); // [Box(content: 0.1), Box(content: 12.34)]
}
```

There is also the `Mapper.fromIterable` method. This can be used if you already have a list of dynamic objects instead of the raw json string.
Additionally this can get handy to decode a dynamic list of partly-encoded values:

```dart
List<double> myNumbers = Mapper.fromIterable([2.312, '1.32', 500, '1e4']);
print(myNumbers); // [2.312, 1.32, 500.0, 10000.0]
```
  
### Non-Trivial Maps  
  
We also support decoding of non-trivial maps.
Although the use-cases might be rare, you can decode to something other than a map of string keys like this:

```dart
var encodedMap = {
  {'name': 'Bonny'}: 1,
  {'name': 'Clyde'}: 5,
};

Map<Dog, int> treatsPerDog = Mapper.fromValue(encodedMap);
print(treatsPerDog[Dog('Clyde')]!); // 5

var myMap = Mapper.toValue(treatsPerDog);
print(myMap); // {{name: Bonny}: 1, {name: Clyde}: 5}
```

> Make sure to mixin `Mappable` on your key class, in order to enable easy property access

> Since json only supports string keys, we can't do `Mapper.fromJson` or `Mapper.toJson` on these maps. You would have to decode / encode your keys and values separately.

## CopyWith

`dart_mappable` can generate a powerful `copyWith` method for your classes. It supports assigning `null` as well as chained deep copies.

```dart
@MappableClass()
class Person with PersonMappable {
  String name;
  int? age;
    
  Person(this.name, this.age);
}

void main() {
  var person = Person('Tom', 20);

  // `age` not passed, its value is preserved
  print(person.copyWith(name: 'Max')); // Person(name: Max, age: 24)
  // `age` is set to `null`
  print(person.copyWith(age: null)); // Person(name: Tom, age: null)
}
```

### Deep Copy

When having complex nested classes, this syntax can get quite verbose. 
Therefore this package provides a special syntax for nested classes, similar to 
[freezed](https://pub.dev/packages/freezed#deep-copy).

Consider the following classes:

```dart
@MappableClass()
class Person with PersonMappable {
  String name;

  Person(this.name);
}

@MappableClass()
class Company with CompanyMappable {
  Person manager;
  List<Person> employees;
  
  Company(this.manager, this.employees);
}

void main() {
  var company = Company(Person('Anna'), [Person('Max'), Person('Tom')]);
  
  // access nested object using the 'dot' syntax
  print(company.copyWith.manager(name: 'Laura')); 
  // prints: Company(manager: Person(name: 'Laura'), ...)
  
  // this also works with lists or maps
  print(company.copyWith.employees.at(0)(name: 'John')); 
  // prints: Company(..., employees: [Person(name: 'John), Person(name: 'Tom')])
  
  // you can also use 'apply' with a custom function to transform a value
  print(company.copyWith.manager.apply((manager) => Person(manager.name.toUpperCase())));
  // prints: Company(manager: Person(name: 'ANNA'), ...)
}
```

When working with `List`s or `Map`s and `copyWith`, there are different methods you can use to access, add, remove or filter elements.
The complete interfaces are documented

- [here](https://pub.dev/documentation/dart_mappable/latest/internals/ListCopyWith-class.html) for Lists
- [here](https://pub.dev/documentation/dart_mappable/latest/internals/MapCopyWith-class.html) for Maps

### CopyWith for Inheritance, Polymorphism and Generics

CopyWith works not only for simple use-cases, but also supports complex class structures with 
inheritance or generics, like [Polymorphism](#polymorphism-and-discriminators).

## Polymorphism and Discriminators

A common pattern that you might want to use for your classes is polymorphism. As a simple example see the classes below. 

```dart
@MappableClass()
abstract class Animal with AnimalMappable {
  String name;
  Animal(this.name);
}

@MappableClass()
class Cat extends Animal with CatMappable {
  String color;
  Cat(String name, this.color) : super(name);
}

@MappableClass()
class Dog extends Animal with DogMappable {
  int age;
  Dog(String name, this.age) : super(name);
}
```

Now when we want to encode a `Home` object, the `pet` property can either be a `Cat` or a `Dog`. 
To make sure that this information isn't lost when converting to json, we need to add a **discriminator property**, that keeps track of the specific type of the `pet`.

By default no discriminator is applied, but you can change this by setting the `discriminatorKey` annotation property or in the build configuration. The value
of this property will default to the name of the class, but you can change this as well with the `discriminatorValue` annotation property.
Make sure to specify the `discriminatorKey` property globally or on the base class - `Animal` in our example - and the `discriminatorValue` property
on each of the child classes - `Cat` and `Dog` in our case.

```dart
@MappableClass(discriminatorKey: 'type')
abstract class Animal with AnimalMappable {
  ...
}

...

void main() {
  // encode a polymorphic class
  String catJson = Mapper.toJson(Cat('Judy', 'Black'));
  print(catJson); // {"name":"Judy","color":"Black","type":"Cat"}

  Animal myPet = Mapper.fromJson(catJson); // implicit decoding as an 'Animal'
  print(myPet.runtimeType); // Cat

  // explicit decoding also works as usual without a discriminator
  Cat myCat = Mapper.fromJson('{"name": "Kitty", "color": "Brown"}');
  print(myCat.name); // Kitty
}
```

### Null and Default Values

There are two additional cases that you might want to cover. Either your discriminator property is `null`, or some other value, that you did not specify.

1. For the `null` case, you can explicitly set the `discriminatorValue` property to `null` and this will work as expected.
2. For the other case, you can specify a fallback class to be used whenever we come across an unknown discriminator value. On this class set the `discriminatorValue` to `MappableClass.useAsDefault`.
  
```dart
@MappableClass(discriminatorValue: null)
class NullAnimal extends Animal with NullAnimalMappable {
  NullAnimal(String name) : super(name);
}

@MappableClass(discriminatorValue: MappableClass.useAsDefault)
class DefaultAnimal extends Animal with DefaultAnimalMappable {
  String type;
  DefaultAnimal(String name, this.type) : super(name);
}

void main() {
  // decode json with the discriminator set to null (same as missing property)
  Animal animal1 = Mapper.fromJson('{"name": "Scar", "type": null}');
  print(animal1.runtimeType); // NullAnimal

  // decode json with unknown discriminator value
  Animal animal2 = Mapper.fromJson('{"name": "Balu", "type": "Bear"}');
  print(animal2.runtimeType); // DefaultAnimal
  print(animal2.type); // Bear
}
```

## Encoding / Decoding Hooks

Hooks provide a way to hook into the encoding and decoding process for a class or single field. 
When using hooks, you have the possibility to inspect and modify values before and after they are encoded or decoded.

To use hooks, create a custom class extending the `MappingHooks` class, and set this as the `hooks` argument of either the `MappableClass` or `MappableField` annotation like this:

```dart
class GameHooks extends MappingHooks {
  const GameHooks();
}

class PlayerHooks extends MappingHooks {
  const PlayerHooks();
}

@MappableClass(hooks: GameHooks())
class Game {
  @MappableField(hooks: PlayerHooks())
  Player player;

  Game(this.player);
}

class Player {
  String id;
  Player(this.id);
}
```

Now, whenever an instance of `Game` is encoded or decoded, the `GameHooks` will be applied to the class and the `PlayerHooks` will be applied to the `player` field. 
Inside your hooks class, you have four methods that you can override:

- `dynamic beforeDecode(dynamic value)`
- `dynamic afterDecode(dynamic value)`
- `dynamic beforeEncode(dynamic value)`
- `dynamic afterEncode(dynamic value)`

Each method takes a dynamic value and returns an optionally modified value.

> Tip: If the `beforeDecode` hook already returns an instance of the target type, the normal decoding logic is skipped. The same is true for the `beforeEncode` hook.
> This gives you the possibility to use different custom mappers on the same type, especially on a field-by-field level.

A simple use-case for this would be to modify the input json before an object is decoded. 
In the example below, the player field can either be a full json object, or a single string. 
The string would then be treated as the id of the player.

```dart
class PlayerHooks extends MappingHooks {
  const PlayerHooks();

  @override
  dynamic beforeDecode(dynamic value) {
    if (value is String) {
      return {'id': value};
    }
    return value;
  }
}

...

void main() {
  // This works as usual
  Game game = Mapper.fromJson('{"player": {"id": "Tom"}}');
  print(game.player.id); // Tom;

  // Special case: 'player' is a string instead of an object
  Game game2 = Mapper.fromJson('{"player": "John"}');
  print(game.player.id); // John
}
```

Additionally, it is important to note that field- and class-hooks are inherited by any subclasses. 
When both the superclass and the subclass define class-hooks, both are applied in the following order:
`super.beforeDecode -> sub.beforeDecode -> decode -> sub.afterDecode -> super.afterDecode`. For field-hooks, only the sub-class-hook is applied.

### Chaining multiple MappingHooks

You can chain and apply multiple hooks using the `ChainedHooks` class like this:
`@MappableClass(hooks: ChainedHooks([ MyHooks1(), MyHooks2(), ... ]))`.

The hooks are applied for encoding and decoding in nested order:
`first.beforeDecode -> second.beforeDecode -> ... -> decode -> ... -> second.afterDecode -> first.afterDecode`.

### Unmapped Properties

A frequently needed use-case for hooks is to catch additional, unmapped properties from json when decoding an object. 
Because of this, we provide a ready-to-use `MappingHook` called `UnmappedPropertiesHooks`.

To use this hook, define a `Map<String, dynamic>` field in your class, and provide it's name to the `UnmappedPropertiesHooks` constructor. 
Be aware that you have to provide the matching json key of the field (after applying the case style, etc.) instead of the dart field name.

```dart
@MappableClass(hooks: UnmappedPropertiesHooks('unmapped_props'))
class Game {
  String id;
  Map<String, dynamic> unmappedProps;

  Game(this.id, this.unmappedProps);
}

void main() {
  Game game = Mapper.fromJson('{"id": 1, "type": "pacman", "score": 100}');
  print(game.id); // 1
  print(game.unmappedProps); // {type: pacman, score: 100}
}
```

## Custom Mappers

You can create custom mappers to serialize / deserialize custom types that are not part of the generated code.
To do this, create a class extending `SimpleMapper<T>` with `T` being the type that you want to decode to / encode from.
Then use the `@CustomMapper` annotation and implement the `decode()` and `encode()` methods.

A custom mapper for the `Uri` type would look like this:

```dart
@CustomMapper()
class UriMapper extends SimpleMapper<Uri> {
  @override
  Uri decode(dynamic value) {
    return Uri.parse(value as String);
  }

  @override
  dynamic encode(Uri self) {
    return self.toString();
  }
}
```

In the `encode()` method you should return a primitive serializable type, like `String`, `int`, 
`bool`, etc. or a `List` or `Map` of those types.

There are also additional methods you can override, like `stringify`, or `equals`.
This will enable `Mapper.isEqual` and `Mapper.asString` on this type.

Using the `@CustomMapper()` annotation, this mapper will automatically be registered and used by the library. 
Or, you can instead register a custom mapper dynamically using `Mapper.use<MyClass>(MyCustomMapper())` and unregister using `Mapper.unuse<MyClass>()`.
This might come in handy if you want to switch between different custom mappers for the same type. 
Also, be aware that you can also `unuse()` (and replace) any mappers, both custom, generated, and mappers of primitive types. 

### Generic Custom Types

When dealing with generic types, we need a more sophisticated syntax for decoding. 
Instead of extending `SimpleMapper` you have to extend `BaseMapper` when wanting to decode a generic class.
Next, instead of overriding the `decode` function, specify a `decoder` getter, which must be a function that 
can accept up to five additional type arguments.

You also need to construct a `typeFactory` as shown below.

```dart
class GenericBox<T> {
  T content;
  GenericBox(this.content);
}

@CustomMapper()
class CustomGenericMapper extends BaseMapper<GenericBox> { // only use the base type here

  @override
  Function decoder = <T>(dynamic value) { // specify the decoder as a generic function
    return GenericBox<T>(Mapper.fromValue<T>(value)); // use the type parameter in your decoding logic
  };
  
  @override
  Function encoder = <T>(GenericBox<T> self) { // specify as generic function similar to [decoder]
    return Mapper.toValue<T>(self.content); // use the type parameter in your encoding logic
  };

  // in case of generic types, we also must specify a type factory. This is a special type of 
  // function used internally to construct generic instances of your type.
  // Specify any type arguments in alignment to the decoder function
  @override
  Function get typeFactory => <T>(f) => f<GenericBox<T>>();
}
```

### Custom Iterables and Maps

For special Iterable and Map types, you can of course specify `CustomMapper`s as described in the previous section.
However, we provide ready-to-use `IterableMapper` and `MapMapper` to make your life a little bit easier:

For both you have to provide 
1. a factory function, which converts a generic iterable / map to your special implementation, 
2. a type factory, similar to the one used in generic custom mappers.

```dart
Mapper.use(IterableMapper<HashSet>(
  <T>(Iterable<T> i) => HashSet.of(i),
  <T>(f) => f<HashSet<T>>(),
));

Mapper.use(MapMapper<HashMap>(
  <K, V>(Map<K, V> m) => HashMap.of(m),
  <K, V>(f) => f<HashMap<K, V>>(),
));

HashSet<Brand> brands = Mapper.fromJson('["toyota", "audi", "audi"]');
print(brands); // {Brands.Toyota, Brands.Audi}
```

## Supported Packages

This package aims to be compatible with other code-generation packages. Check the `examples` directory for some common use-cases.

### Freezed

[Freezed](https://pub.dev/packages/freezed) is a "code generator for unions/pattern-matching/copy"; 
With this package, it is easy to create union or sealed classes. 

Here is a simple example taken from their documentation:

```dart
@freezed
class Union with _$Union {
  const factory Union(int value) = Data;
  const factory Union.loading() = Loading;
  const factory Union.error([String? message]) = ErrorDetails;
}
```

To make it compatible with dart_mappable, just add your `@MappableClass` annotations to both the parent class, and all **factory constructors**, as if they were the child classes. 
For a description of the `discriminatorKey` and `discriminatorValue` properties head up to the [Polymorphism and Discriminators](#polymorphism-and-discriminators) section.
You can also add the `@MappableField()` annotation to any of the fields.

```dart
@freezed
@MappableClass(discriminatorKey: 'type')
class Union with _$Union {
  @MappableClass(discriminatorValue: 'data')
  const factory Union.data(@MappableField(key: 'mykey') int value) = Data;
  @MappableClass(discriminatorValue: 'loading')
  const factory Union.loading() = Loading;
  @MappableClass(discriminatorValue: 'error')
  const factory Union.error([String? message]) = ErrorDetails;
}
```

This will now allow you to use this and the resulting `Data`, `Loading` and `ErrorDetails` classes as usual:

```dart
void main() {
  var data = Union.data(42);

  var dataJson = data.toJson();
  print(dataJson); // {"mykey":42,"type":"data"}

  var parsedData = Mapper.fromJson<Union>(dataJson);
  print(parsedData); // Union.data(value: 42)
}
```

For the full example and generated files, check out the `examples/example_freezed` directory.