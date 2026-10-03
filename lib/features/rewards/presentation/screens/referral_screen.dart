import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_navigation_controls.dart';
import '../../domain/rewards.dart';
import '../rewards_providers.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(referralSummaryProvider);
    final wallet = ref.watch(walletEntriesProvider).valueOrNull;
    final balance = wallet == null
        ? null
        : WalletSummary.fromEntries(wallet).balance;
    return Scaffold(
      appBar: AppBar(
        leading: const AppNavigationControls(),
        leadingWidth: AppNavigationControls.kLeadingWidth,
        title: const Text('Refer & Earn'),
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load referrals: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (data) => _ReferralBody(summary: data, balance: balance),
      ),
    );
  }
}

class _ReferralBody extends ConsumerWidget {
  const _ReferralBody({required this.summary, required this.balance});

  final ReferralSummary summary;
  final double? balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewarded = summary.items
        .where((item) => _status(item) == 'completed')
        .length;
    final pending = summary.items.length - rewarded;
    final credited = summary.items.fold<double>(0, (sum, item) {
      final amount = item['amount'];
      if (amount is num && _status(item) == 'completed') return sum + amount;
      return sum;
    });
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final padding = constraints.maxWidth >= 600 ? 24.0 : 16.0;
        final story = _HowItWorks(code: summary.code);
        final invite = _InviteCard(code: summary.code);
        final main = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RewardHero(
              balance: balance,
              rewarded: rewarded,
              pending: pending,
              credited: credited,
            ),
            const SizedBox(height: 16),
            _CodeCard(code: summary.code),
            const SizedBox(height: 16),
            _ClaimReferralField(ref: ref),
            const SizedBox(height: 16),
            _History(items: summary.items),
          ],
        );
        return ListView(
          padding: EdgeInsets.all(padding),
          children: [
            if (!wide) ...[
              main,
              const SizedBox(height: 16),
              story,
              const SizedBox(height: 16),
              invite,
            ] else
              LayoutBuilder(
                builder: (context, rowConstraints) {
                  const gap = 20.0;
                  final left = (rowConstraints.maxWidth - gap) * 0.58;
                  final right = rowConstraints.maxWidth - gap - left;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: left, child: main),
                      const SizedBox(width: gap),
                      SizedBox(
                        width: right,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            story,
                            const SizedBox(height: 16),
                            invite,
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

String _status(Map<String, dynamic> item) =>
    (item['status'] as String? ?? 'pending').toLowerCase();

class _RewardHero extends StatelessWidget {
  const _RewardHero({
    required this.balance,
    required this.rewarded,
    required this.pending,
    required this.credited,
  });

  final double? balance;
  final int rewarded;
  final int pending;
  final double credited;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const Text(
                'REFERRAL REWARDS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              if (balance != null)
                Text(
                  'Wallet: ₹${balance!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Give ₹500, Get ₹500!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Invite friends to BookMySpace. They receive a ₹500 welcome credit, and you earn ₹500 when their first booking qualifies.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _Stat(
                label: 'TOTAL REWARDED',
                value: '₹${credited.toStringAsFixed(0)}',
              ),
              _Stat(label: 'SUCCESSFUL REFERS', value: '$rewarded Friends'),
              _Stat(label: 'PENDING', value: '$pending Friends'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'YOUR UNIQUE REFERRAL CODE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              code,
              key: const Key('referral-code'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('referral-share-code'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'Join BookMySpace with my code $code — https://bookmyspace.app/register?ref=$code',
                      ),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral code copied')),
                    );
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        '1',
        'Share Your Code',
        'Send $code or the register link to a friend.',
      ),
      (
        '2',
        'Friend Gets ₹500 Welcome Bonus',
        'When they sign up with your code, the welcome credit is posted to their wallet.',
      ),
      (
        '3',
        'Earn ₹500 on First Booking',
        'When their first booking qualifies, ₹500 is posted to your wallet.',
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How Referral Program Works',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            for (final step in steps) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    child: Text(step.$1, style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$2,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(step.$3),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatefulWidget {
  const _InviteCard({required this.code});

  final String code;

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  final _name = TextEditingController();
  final _contact = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final contact = _contact.text.trim();
    final name = _name.text.trim();
    if (contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an email or mobile number')),
      );
      return;
    }
    final greeting = name.isEmpty ? 'Hello' : 'Hello $name';
    final body =
        '$greeting, join BookMySpace with my code ${widget.code}: https://bookmyspace.app/register?ref=${widget.code}';
    final uri = contact.contains('@')
        ? Uri(
            scheme: 'mailto',
            path: contact,
            queryParameters: {
              'subject': 'Join BookMySpace',
              'body': body,
            },
          )
        : Uri(scheme: 'sms', path: contact, queryParameters: {'body': body});
    final opened = await launchUrl(uri);
    if (!mounted) return;
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: body));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite copied. No mail or SMS app opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send Direct Invitation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Opens your email or SMS app with your code.'),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: "Friend's Full Name"),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contact,
              decoration: const InputDecoration(
                labelText: "Friend's Email or Mobile Number",
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('referral-send-invite'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _send,
              child: const Text(
                'Send Invite & Earn ₹500',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Referral History',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('No referrals yet.')
        else
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Text(
                  _status(item).isEmpty ? '?' : _status(item)[0].toUpperCase(),
                ),
              ),
              title: Text(_status(item).toUpperCase()),
              subtitle: Text(item['created_at'] as String? ?? ''),
            ),
      ],
    );
  }
}

class _ClaimReferralField extends StatefulWidget {
  const _ClaimReferralField({required this.ref});
  final WidgetRef ref;
  @override
  State<_ClaimReferralField> createState() => _ClaimReferralFieldState();
}

class _ClaimReferralFieldState extends State<_ClaimReferralField> {
  final _controller = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Have a Friend's Referral Code?",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter a referral code to claim the welcome credit on your wallet.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'e.g. BMS-ANKIT01',
                      isDense: true,
                    ),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await widget.ref
                                .read(rewardsRepositoryProvider)
                                .claimReferral(_controller.text);
                            widget.ref.invalidate(referralSummaryProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Referral attributed'),
                                ),
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(error.toString())),
                              );
                            }
                          }
                          if (mounted) setState(() => _busy = false);
                        },
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Claim ₹500'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
