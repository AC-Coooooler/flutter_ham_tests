import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui' as ui;

import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ham_tests/flutter_ham_tests_route.dart';
import 'package:oktoast/oktoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flutter_ham_tests_routes.dart';

late final SharedPreferences sp;
const String _keyDarkMode = 'dark_mode';
const String _keyDoneList = 'done_list';
const String _keyFavoriteList = 'favorite_list';
const String _keyWrongList = 'wrong_list';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sp = await SharedPreferences.getInstance();
  await parseQuestions();
  runApp(MyApp());
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

final appGlobalKey = GlobalKey<_MyAppState>();

class MyApp extends StatefulWidget {
  MyApp() : super(key: appGlobalKey);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  void rebuildAllChildren() {
    setState(() {});

    dev.log('Rebuilding all elements...');
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness;
    final isDarkMode = sp.getBool(_keyDarkMode);
    if (isDarkMode == null) {
      brightness = MediaQueryData.fromWindow(ui.window).platformBrightness;
    } else {
      brightness = isDarkMode ? Brightness.dark : Brightness.light;
    }
    return OKToast(
      duration: const Duration(seconds: 3),
      position: ToastPosition.bottom.copyWith(
        offset: -MediaQueryData.fromWindow(ui.window).size.height / 12,
      ),
      radius: 5,
      child: MaterialApp(
        scrollBehavior: CustomScrollBehavior(),
        title: 'HAM Tests',
        theme: ThemeData(
          primarySwatch: const Color.fromARGB(255, 20, 56, 130).swatch,
          appBarTheme: const AppBarTheme(centerTitle: true),
          textTheme: _textThemeBy(brightness: brightness),
          brightness: brightness,
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

  Future<void> gotoExam() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('模拟考试'),
        content: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '本次模拟考试将从365道A类题中取30道题，'
                    '合格需答对25道题，时间共15分钟（正式考试约60分钟）。',
              ),
              TextSpan(
                text: '开始考试？',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed(
              Routes.examPage.name,
            ),
            child: const Text('开始'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('放弃'),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
      ),
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
      appBar: AppBar(
        title: const Text('HAM'),
        leading: IconButton(
          onPressed: () async {
            final isDarkMode = sp.getBool(_keyDarkMode) == true;
            await sp.setBool(_keyDarkMode, !isDarkMode);
            appGlobalKey.currentState?.rebuildAllChildren();
          },
          icon: Icon(
            sp.getBool(_keyDarkMode) == true
                ? Icons.dark_mode
                : Icons.light_mode,
          ),
        ),
      ),
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
        onPressed: gotoExam,
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
    final question = widget.questions[index];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '[${index + 1}/$length]  '),
            TextSpan(text: question.content),
            TextSpan(
              text: '[${question.id}]',
              style: TextStyle(
                color: Theme.of(context).textTheme.caption?.color,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          fontSize: 20,
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
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      answer.content,
                      style: const TextStyle(fontSize: 20, height: 1.4),
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
            Icon(icon, size: 32),
            const SizedBox(height: 4),
            Text(name, style: const TextStyle(fontSize: 16)),
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
              children: [_buildQuestion(context), _buildAnswers(context)],
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

class AnswerHolder {
  AnswerHolder(this.answers, this.selectedAnswer);

  final List<Answer> answers;
  Answer? selectedAnswer;
}

@FFRoute(name: 'exam-page')
class ExamPage extends StatefulWidget {
  const ExamPage({
    Key? key,
    this.remainsMinutes = 15,
  })  : assert(remainsMinutes > 0),
        super(key: key);

  final int remainsMinutes;

  @override
  State<ExamPage> createState() => _ExamPageState();
}

class _ExamPageState extends State<ExamPage> {
  late final DateTime endTime;
  late final ValueNotifier<String> remainsTime;
  late final Timer timer;
  late final Map<Question, AnswerHolder> holders;
  late final List<Question> questions = holders.keys.toList();
  final List<int> wrongIndex = [];
  bool isTimeout = false, hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    endTime = DateTime.now().add(Duration(minutes: widget.remainsMinutes));
    remainsTime = ValueNotifier<String>(
      '${'${widget.remainsMinutes}'.padLeft(2, '0')}:00',
    );
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      final difference = endTime.difference(DateTime.now());
      if (difference.isNegative) {
        timesUp();
      }
      final minutes = difference.inSeconds ~/ 60;
      final seconds = difference.inSeconds % 60;
      remainsTime.value = '${'$minutes'.padLeft(2, '0')}'
          ':${'$seconds'.padLeft(2, '0')}';
    });
    final questions = allQuestions.toList()..shuffle();
    holders = Map.fromIterable(
      questions.sublist(0, 30),
      value: (e) => AnswerHolder((e as Question).getRandomAnswers(), null),
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void timesUp() {
    timer.cancel();
    isTimeout = true;
    setState(() {});
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Center(child: Text('考试结束')),
      ),
    );
  }

  void selectAnswer(Question question, Answer answer) {
    if (isTimeout) {
      return;
    }
    setState(() {
      holders[question]!.selectedAnswer = answer;
    });
  }

  Future<void> submit() async {
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('是否提交答卷？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('提交'),
          ),
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('放弃'),
          ),
        ],
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
    if (result != true) {
      return;
    }
    timer.cancel();
    final wrongAnswers = holders.entries
        .where(
          (e) => e.value.selectedAnswer?.isCorrect == false,
        )
        .toList();
    wrongIndex.clear();
    for (final entry in wrongAnswers) {
      wrongIndex.add(questions.indexOf(entry.key) + 1);
    }
    hasSubmitted = true;
    setState(() {});
    final correctCount = holders.entries
        .where((e) => e.value.selectedAnswer?.isCorrect == true)
        .length;
    final passed = correctCount >= 25;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('成绩${passed ? '合格' : '不合格'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: '答对了'),
                TextSpan(
                  text: '$correctCount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '道'),
                const TextSpan(text: '（答对'),
                const TextSpan(
                  text: '25',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '即为合格）'),
              ]),
            ),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: '错题：'),
                if (wrongIndex.isEmpty)
                  const TextSpan(text: '无')
                else
                  TextSpan(
                    text: '$wrongIndex',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
              ]),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, Question question, int index) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${index + 1}.  '),
            TextSpan(text: question.content),
            TextSpan(
              text: '[${question.id}]',
              style: TextStyle(
                color: Theme.of(context).textTheme.caption?.color,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          fontSize: 20,
          height: 1.5,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }

  Widget _buildAnswers(
    BuildContext context,
    Question question,
    AnswerHolder holder,
  ) {
    final answers = holder.answers;
    final selectedAnswer = holder.selectedAnswer;
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
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => selectAnswer(question, answer),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selectedAnswer == answer
                        ? Icons.circle
                        : Icons.circle_outlined,
                    color:
                        selectedAnswer == answer ? Colors.green : Colors.grey,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      answer.content,
                      style: const TextStyle(fontSize: 20, height: 1.4),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模拟考试')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final question = questions[index];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestion(context, question, index),
                    _buildAnswers(context, question, holders[question]!),
                  ],
                );
              },
            ),
          ),
          Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: FittedBox(
                      child: ValueListenableBuilder<String>(
                        valueListenable: remainsTime,
                        builder: (_, String value, __) => Text(
                          isTimeout
                              ? '已超时'
                              : hasSubmitted
                                  ? '已提交'
                                  : value,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: isTimeout ? null : submit,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      color: Theme.of(context).primaryColor,
                      child: FittedBox(
                        child: Text(
                          isTimeout
                              ? '无法交卷'
                              : hasSubmitted
                                  ? '再交一次'
                                  : '提交答卷',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  // Override behavior methods and getters like dragDevices
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
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
