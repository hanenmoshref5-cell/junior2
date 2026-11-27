import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/constants/app_colors.dart';
import '../../../../common/constants/app_text_styles.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  const _ChatMessage({required this.text, required this.isUser});
}

class _QuickReply {
  final String label, response;
  const _QuickReply({required this.label, required this.response});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  List<_QuickReply> _currentReplies = [];
  bool _started = false;

  final List<_QuickReply> _initialReplies = [
    _QuickReply(
      label: 'أشعر بتنميل في القدم',
      response:
          'التنميل في القدمين قد يكون علامة على اعتلال الأعصاب السكري. ننصحك بمراجعة طبيبك لإجراء الفحوصات اللازمة، والحرص على ضبط مستوى السكر يومياً.',
    ),
    _QuickReply(
      label: 'لا أرى بشكل جيد',
      response:
          'ضعف البصر مع السكري قد يكون بسبب ارتفاع السكر أو اعتلال الشبكية. يُنصح بمراجعة طبيب العيون وضبط مستوى السكر فوراً.',
    ),
    _QuickReply(
      label: 'أشعر بتعب وألم',
      response:
          'التعب والألم العام من الأعراض الشائعة لمرضى السكري خصوصاً عند ارتفاع السكر. احرص على الراحة الكافية وقياس سكرك الآن.',
    ),
    _QuickReply(
      label: 'أشعر بعطش شديد',
      response:
          'العطش الشديد من أبرز علامات ارتفاع السكر في الدم. قس سكرك الآن واشرب الماء، وإذا كانت القراءة مرتفعة استشر طبيبك.',
    ),
    _QuickReply(
      label: 'أشعر بدوخة',
      response:
          'الدوخة قد تكون بسبب انخفاض السكر. تناول شيئاً حلواً كعصير أو تمرات فوراً، ثم قس سكرك بعد 15 دقيقة.',
    ),
  ];

  final Map<String, List<_QuickReply>> _followUps = {
    'التنميل في القدمين قد يكون علامة على اعتلال الأعصاب السكري. ننصحك بمراجعة طبيبك لإجراء الفحوصات اللازمة، والحرص على ضبط مستوى السكر يومياً.': [
      _QuickReply(
        label: 'كيف أحمي قدميّ؟',
        response:
            'افحص قدميك يومياً، ارتدِ أحذية مريحة، تجنب المشي حافياً، ورطّب الجلد جيداً. الحفاظ على سكر طبيعي يحمي الأعصاب من التلف.',
      ),
      _QuickReply(
        label: 'متى أزور الطبيب؟',
        response:
            'يُنصح بزيارة الطبيب فوراً إذا استمر التنميل أكثر من أسبوع أو ظهرت جروح لا تلتئم أو تورم في القدمين.',
      ),
    ],
    'ضعف البصر مع السكري قد يكون بسبب ارتفاع السكر أو اعتلال الشبكية. يُنصح بمراجعة طبيب العيون وضبط مستوى السكر فوراً.': [
      _QuickReply(
        label: 'كيف أحمي عينيّ؟',
        response:
            'افحص عينيك سنوياً، ضبط السكر هو أهم حماية للعينين، وتجنب التدخين لأنه يسرّع تلف الأوعية الدموية.',
      ),
    ],
  };

  void _sendMessage(String text, String botResponse) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: botResponse, isUser: false));
        _currentReplies = _followUps[botResponse] ?? [];
        _started = true;
      });
      _scrollToBottom();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                color: AppColors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('المساعد الصحي'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                // رسالة ترحيب
                _BotBubble(
                  text:
                      'مرحباً! أنا مساعدك الصحي. اختر من الأسئلة أدناه وسأجيبك فوراً 💙',
                ),
                const SizedBox(height: 16),

                // الردود السريعة الأولى
                if (!_started)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: _initialReplies
                        .map(
                          (r) => _QuickReplyChip(
                            label: r.label,
                            onTap: () => _sendMessage(r.label, r.response),
                          ),
                        )
                        .toList(),
                  ),

                // المحادثة
                ..._messages.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: m.isUser
                        ? _UserBubble(text: m.text)
                        : _BotBubble(text: m.text),
                  ),
                ),

                // ردود متابعة
                if (_currentReplies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: _currentReplies
                        .map(
                          (r) => _QuickReplyChip(
                            label: r.label,
                            onTap: () => _sendMessage(r.label, r.response),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  final String text;
  const _BotBubble({required this.text});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: AppColors.divider),
              ),
              child: Text(
                text,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickReplyChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.lightBeige,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(color: AppColors.darkBrown),
        ),
      ),
    );
  }
}
