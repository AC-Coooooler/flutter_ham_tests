// GENERATED CODE - DO NOT MODIFY MANUALLY
// **************************************************************************
// Auto generated by https://github.com/fluttercandies/ff_annotation_route
// **************************************************************************
// fast mode: true
// version: 10.0.6
// **************************************************************************
// ignore_for_file: prefer_const_literals_to_create_immutables,unused_local_variable,unused_import,unnecessary_import,unused_shown_name,implementation_imports,duplicate_import
import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:flutter/widgets.dart';

import 'main.dart';

FFRouteSettings getRouteSettings({
  required String name,
  Map<String, dynamic>? arguments,
  PageBuilder? notFoundPageBuilder,
}) {
  final Map<String, dynamic> safeArguments =
      arguments ?? const <String, dynamic>{};
  switch (name) {
    case 'exam-page':
      return FFRouteSettings(
        name: name,
        arguments: arguments,
        builder: () => ExamPage(
          key: asT<Key?>(
            safeArguments['key'],
          ),
          remainsMinutes: asT<int>(
            safeArguments['remainsMinutes'],
            15,
          )!,
        ),
      );
    case 'home-page':
      return FFRouteSettings(
        name: name,
        arguments: arguments,
        builder: () => MyHomePage(
          key: asT<Key?>(
            safeArguments['key'],
          ),
        ),
      );
    case 'questions-page':
      return FFRouteSettings(
        name: name,
        arguments: arguments,
        builder: () => QuestionsPage(
          key: asT<Key?>(
            safeArguments['key'],
          ),
          title: asT<String>(
            safeArguments['title'],
          )!,
          questions: asT<List<Question>>(
            safeArguments['questions'],
          )!,
        ),
      );
    default:
      return FFRouteSettings(
        name: FFRoute.notFoundName,
        routeName: FFRoute.notFoundRouteName,
        builder: notFoundPageBuilder ?? () => Container(),
      );
  }
}
