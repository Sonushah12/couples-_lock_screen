import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../home/controllers/home_controller.dart';
import '../../../core/motion/app_motion.dart';

class ComposeView extends StatefulWidget {
  const ComposeView({super.key, this.question = false, this.countdown = false});
  final bool question, countdown;
  @override
  State<ComposeView> createState() => _ComposeViewState();
}

class _ComposeViewState extends State<ComposeView> {
  final text = TextEditingController();
  final form = GlobalKey<FormState>();
  DateTime date = DateTime.now().add(const Duration(days: 7));
  String? questionDay, questionText;
  @override
  void initState() {
    super.initState();
    if (widget.question) _loadQuestion();
  }

  void _loadQuestion() {
    final c = Get.find<HomeController>();
    c.refreshQuestionDay();
    questionDay = c.questionKey;
    questionText = c.questionForDay(questionDay!);
    text.text = (c.repository.state['answers'] as Map?)?[questionDay] ?? '';
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.question
            ? 'Today’s question'
            : widget.countdown
            ? 'Something to look forward to'
            : 'A little note',
      ),
    ),
    body: PageBody(
      children: [
        Text(
          widget.question
              ? questionText!
              : widget.countdown
              ? 'Plan a little happiness.'
              : 'Say it in your own words.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          widget.question
              ? Get.find<HomeController>().isCloud
                    ? 'Answer in your own words. Your person’s answer appears after you submit yours.'
                    : 'Your answer is saved on this phone. Sign in to share your daily ritual.'
              : widget.countdown
              ? 'A date worth counting down to.'
              : 'A tiny note can make a whole day.',
        ),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: TextFormField(
            controller: text,
            maxLength: widget.countdown ? 60 : 500,
            minLines: widget.countdown ? 1 : 5,
            maxLines: widget.countdown ? 1 : 8,
            decoration: InputDecoration(
              labelText: widget.countdown
                  ? 'Event name'
                  : widget.question
                  ? 'Your answer'
                  : 'Your message',
              alignLabelWithHint: true,
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Please write something first'
                : null,
          ),
        ),
        if (widget.countdown)
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (d != null) setState(() => date = d);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('${date.day}/${date.month}/${date.year}'),
          ),
        const SizedBox(height: 24),
        Obx(
          () => FilledButton(
            onPressed: Get.find<HomeController>().busy.value
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final c = Get.find<HomeController>();
                    final ok = widget.question
                        ? await c.saveAnswer(
                            text.text,
                            questionDay: questionDay,
                          )
                        : widget.countdown
                        ? await c.addCountdown(text.text, date)
                        : await c.send('note', text.text.trim());
                    if (ok) {
                      if (!widget.question) {
                        Get.back();
                      }
                      Get.snackbar(
                        widget.question ? 'Answer saved' : 'Saved',
                        c.saveMessage,
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
            child: BusyLabel(
              widget.question
                  ? 'Save my answer'
                  : widget.countdown
                  ? 'Add countdown'
                  : Get.find<HomeController>().isCloud
                  ? 'Share my note'
                  : 'Save my note',
              busy: Get.find<HomeController>().busy.value,
            ),
          ),
        ),
        if (widget.question) ...[
          const SizedBox(height: 24),
          Obx(() {
            final c = Get.find<HomeController>();
            if (c.questionKey != questionDay) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A new question is ready. Open it to share today’s answer.',
                    ),
                    TextButton(
                      onPressed: () => setState(_loadQuestion),
                      child: const Text('Open today’s question'),
                    ),
                  ],
                ),
              );
            }
            if (((c.repository.state['answers'] as Map?)?[questionDay] ?? '')
                .isEmpty) {
              return const EmptyState(
                'A little mystery',
                'Your person’s answer stays private until you write yours.',
                icon: Icons.lock_outline,
              );
            }
            if (c.partnerAnswer.isEmpty) {
              return EmptyState(
                'Your answer is saved',
                c.paired
                    ? 'Waiting for your person to answer. Their words will appear here.'
                    : 'Invite your person to share this ritual.',
                icon: Icons.hourglass_empty,
              );
            }
            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${c.displayPartner}’s answer',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.partnerAnswer.value,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    ),
  );
}
