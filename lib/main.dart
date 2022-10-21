import 'dart:developer' as dev;
import 'dart:ui' as ui;

import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ham_tests/flutter_ham_tests_route.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_ham_tests_routes.dart';

late final SharedPreferences sp;
const String _keyDoneList = 'done_list';
const String _keyFavoriteList = 'favorite_list';
const String _keyWrongList = 'wrong_list';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sp = await SharedPreferences.getInstance();
  await parseQuestions();
  runApp(const MyApp());
}

final allQuestions = <Question>[];

Future<void> parseQuestions() async {
  final content = await rootBundle.loadString('assets/A-v20211022.txt');
  allQuestions.addAll(
    content.split('[P]\n').where((e) => e.isNotEmpty).map(Question.fromString),
  );
  dev.log('Parsed ${allQuestions.length} questions.');
}

class Question {
  const Question(this.id, this.content, this.answers);

  factory Question.fromString(String string) {
    final lines = string.trim().split('\n');
    final id = lines.removeAt(0).replaceAll('[I]', '');
    final content = lines.removeAt(0).replaceAll('[Q]', '');
    final answers = lines.map(Answer.fromString).toList(growable: false);
    return Question(id, content, answers);
  }

  final String id;
  final String content;
  final List<Answer> answers;

  List<Answer> getRandomAnswers() => answers.toList(growable: false)..shuffle();

  @override
  String toString() => '($id) $content';
}

class Answer {
  const Answer(this.content, this.isCorrect);

  factory Answer.fromString(String string) {
    return Answer(
      string.replaceAll(RegExp(r'\[[A-Z]\]'), ''),
      string.startsWith('[A]'),
    );
  }

  final String content;
  final bool isCorrect;

  @override
  String toString() {
    return '[${isCorrect ? '正确' : '错误'}] $content';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OKToast(
      duration: const Duration(seconds: 3),
      position: ToastPosition.bottom.copyWith(
        offset: -MediaQueryData.fromWindow(ui.window).size.height / 12,
      ),
      radius: 5,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: const Color.fromARGB(255, 20, 56, 130).swatch,
          appBarTheme: const AppBarTheme(centerTitle: true),
          textTheme: _textThemeBy(),
        ),
        initialRoute: Routes.homePage.name,
        onGenerateRoute: (RouteSettings settings) => onGenerateRoute(
          settings: settings,
          getRouteSettings: getRouteSettings,
          notFoundPageBuilder: () => Container(
            alignment: Alignment.center,
            color: Colors.black,
            child: Text(
              '${settings.name ?? 'Unknown'} route not found',
              style: const TextStyle(color: Colors.white, inherit: false),
            ),
          ),
        ),
      ),
    );
  }
}

@FFRoute(name: 'home-page', argumentImports: ["import 'main.dart';"])
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void gotoQuestionsPageWith(String title, List<Question> questions) {
    Navigator.of(context).pushNamed(
      Routes.questionsPage.name,
      arguments: Routes.questionsPage.d(title: title, questions: questions),
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required String name,
    required String description,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(16.0).copyWith(left: 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HAM')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildAction(
              context,
              name: '顺序练习',
              description: '从第一题开始学习全部365道考题',
              icon: Icons.double_arrow_rounded,
              onPressed: () => gotoQuestionsPageWith(
                '顺序练习',
                allQuestions.toList(growable: false),
              ),
            ),
            _buildAction(
              context,
              name: '随机练习',
              description: '打乱顺序显示全部365道考试题',
              icon: Icons.shuffle_rounded,
              onPressed: () => gotoQuestionsPageWith(
                '随机练习',
                allQuestions.toList(growable: false)..shuffle(),
              ),
            ),
            _buildAction(
              context,
              name: '只看未做',
              description: '仅显示未做过的题目',
              icon: Icons.refresh_rounded,
              onPressed: () {
                final done = sp.getStringList(_keyDoneList) ?? [];
                final list = allQuestions.toList();
                for (final e in done) {
                  list.removeWhere((q) => q.id == e);
                }
                gotoQuestionsPageWith('只看未做', list);
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {},
        tooltip: '模拟考试',
        child: const Icon(Icons.score),
      ),
    );
  }
}

@FFRoute(name: 'questions-page')
class QuestionsPage extends StatefulWidget {
  const QuestionsPage({
    Key? key,
    required this.title,
    required this.questions,
  }) : super(key: key);

  final String title;
  final List<Question> questions;

  @override
  State<QuestionsPage> createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage> {
  late final length = widget.questions.length;
  int index = 0;
  late List<Answer> answers = widget.questions[index].getRandomAnswers();
  Answer? selectedAnswer;

  Question get currentQuestion => widget.questions[index];

  void selectAnswer(Answer answer) {
    selectedAnswer = answer;
    final id = currentQuestion.id;
    final wrongSet = sp.getStringList(_keyWrongList)?.toSet() ?? {};
    if (answer.isCorrect) {
      wrongSet.remove(id);
    } else {
      wrongSet.add(id);
    }
    // 记录错题情况
    sp.setStringList(_keyWrongList, wrongSet.toList());
    // 记录完成情况
    final doneSet = (sp.getStringList(_keyDoneList)?.toSet() ?? {})..add(id);
    sp.setStringList(_keyDoneList, doneSet.toList());
    setState(() {});
    if (answer.isCorrect) {
      nextQuestion();
    }
  }

  void refreshAnswers() {
    selectedAnswer = null;
    answers = widget.questions[index].getRandomAnswers();
  }

  void previousQuestion() {
    if (index == 0) {
      showToast('没有下一题了');
    } else {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => setState(() {
          index--;
          refreshAnswers();
        }),
      );
    }
  }

  void nextQuestion() {
    if (index + 1 == length) {
      showToast('没有下一题了');
    } else {
      Future.delayed(
        const Duration(milliseconds: 100),
        () => setState(() {
          index++;
          refreshAnswers();
        }),
      );
    }
  }

  Widget _buildQuestion(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '[${index + 1}/$length]  '),
            TextSpan(text: widget.questions[index].content),
            TextSpan(
              text: '[${currentQuestion.id}]',
              style: TextStyle(
                color: Theme.of(context).textTheme.caption?.color,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          fontSize: 24,
          height: 1.5,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }

  Widget _buildAnswers(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Theme.of(context).dividerColor),
        ),
        color: Theme.of(context).cardColor,
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: answers.length,
        itemBuilder: (context, index) {
          final answer = answers[index];
          final showAsCorrect = answer.isCorrect && selectedAnswer != null;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => selectAnswer(answer),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    showAsCorrect
                        ? Icons.check_circle
                        : selectedAnswer == answer
                            ? Icons.cancel_outlined
                            : Icons.circle_outlined,
                    color: showAsCorrect
                        ? Colors.green
                        : selectedAnswer == answer
                            ? Colors.redAccent
                            : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      answer.content,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required IconData icon,
    required String name,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildQuestion(context),
                _buildAnswers(context),
              ],
            ),
          ),
          const Divider(height: 1),
          ColoredBox(
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAction(
                  context,
                  icon: Icons.arrow_circle_left_outlined,
                  name: '上一题',
                  onPressed: previousQuestion,
                ),
                _buildAction(
                  context,
                  icon: Icons.arrow_circle_right_outlined,
                  name: '下一题',
                  onPressed: nextQuestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

TextTheme _textThemeBy({Brightness brightness = Brightness.light}) {
  const TextStyle baseStyle = TextStyle(
    fontFamilyFallback: <String>['PingFang SC', 'Heiti SC'],
    height: 1.24,
    leadingDistribution: TextLeadingDistribution.even,
    textBaseline: TextBaseline.ideographic,
  );
  final Typography typography = Typography.material2014(
    platform: defaultTargetPlatform,
  );
  final TextTheme baseTextTheme =
      brightness == Brightness.dark ? typography.white : typography.black;
  return baseTextTheme.merge(
    TextTheme(
      displayLarge: baseStyle.copyWith(fontWeight: FontWeight.normal),
      displayMedium: baseStyle.copyWith(fontWeight: FontWeight.normal),
      displaySmall: baseStyle.copyWith(fontWeight: FontWeight.normal),
      headlineLarge: baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: baseStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: baseStyle.copyWith(fontWeight: FontWeight.bold),
      titleMedium: baseStyle.copyWith(fontWeight: FontWeight.normal),
      titleSmall: baseStyle.copyWith(fontWeight: FontWeight.bold),
      bodyLarge: baseStyle.copyWith(fontWeight: FontWeight.normal),
      bodyMedium: baseStyle.copyWith(fontWeight: FontWeight.normal),
      bodySmall: baseStyle.copyWith(fontWeight: FontWeight.normal),
      labelLarge: baseStyle.copyWith(fontWeight: FontWeight.bold),
      labelMedium: baseStyle.copyWith(fontWeight: FontWeight.normal),
      labelSmall: baseStyle.copyWith(fontWeight: FontWeight.normal),
    ),
  );
}

extension ColorExtension on Color {
  MaterialColor get swatch {
    return Colors.primaries.firstWhere(
      (Color c) => c.value == value,
      orElse: () => _swatch,
    );
  }

  Map<int, Color> get getMaterialColorValues {
    return <int, Color>{
      50: _swatchShade(50),
      100: _swatchShade(100),
      200: _swatchShade(200),
      300: _swatchShade(300),
      400: _swatchShade(400),
      500: _swatchShade(500),
      600: _swatchShade(600),
      700: _swatchShade(700),
      800: _swatchShade(800),
      900: _swatchShade(900),
    };
  }

  MaterialColor get _swatch => MaterialColor(value, getMaterialColorValues);

  Color _swatchShade(int swatchValue) => HSLColor.fromColor(this)
      .withLightness(1 - (swatchValue / 1000))
      .toColor();
}
