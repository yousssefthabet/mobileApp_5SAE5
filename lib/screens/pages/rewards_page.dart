import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chargi/services/reward_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  static const Color primaryGreen = Color(0xFF086B5B);
  static const Color backgroundColor = Color(0xFFF7F9F8);
  static const Color cardBorderColor = Color(0xFFE8ECEB);
  static const Color textDark = Color(0xFF1E2926);
  static const Color textMuted = Color(0xFF7A8B86);
  static const Color goldAccent = Color(0xFFD97706);

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Récemment';
    try {
      final dt = timestamp.toDate();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Récemment';
    }
  }

  void _copyPromoCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Code promo $code copié dans le presse-papier !'),
          ],
        ),
        backgroundColor: primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? '';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Fidélité & Récompenses',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: textDark,
        elevation: 0,
      ),
      body: StreamBuilder<int>(
        stream: RewardService.instance.getUserPointsStream(userId),
        builder: (context, snapshot) {
          final points = snapshot.data ?? 0;
          final hasUnlockedPromo = points >= RewardService.promoThresholdPoints;
          final progress = (points / RewardService.promoThresholdPoints).clamp(0.0, 1.0);
          final missingPoints = (RewardService.promoThresholdPoints - points).clamp(0, 100);
          final reservationsNeeded = (missingPoints / RewardService.pointsPerReservation).ceil();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Main Points Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF086B5B), Color(0xFF0E8A76)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.stars_rounded,
                                color: Colors.amberAccent,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Solde Fidélité',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '+10 pts / résa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$points',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Points',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          hasUnlockedPromo ? Colors.amberAccent : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      hasUnlockedPromo
                          ? '🎉 Objectif 100 pts atteint ! Votre code promo 30% est prêt.'
                          : '$points / 100 points · Plus que $reservationsNeeded réservation${reservationsNeeded > 1 ? 's' : ''} pour 30% de remise',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Promo Code 30% Card (Active or Locked)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: hasUnlockedPromo ? Colors.amber.shade400 : cardBorderColor,
                    width: hasUnlockedPromo ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hasUnlockedPromo
                                ? Colors.amber.shade50
                                : const Color(0xFFF0F4F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            hasUnlockedPromo
                                ? Icons.card_giftcard
                                : Icons.lock_outline,
                            color: hasUnlockedPromo ? goldAccent : textMuted,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Réduction de 30% sur réservation',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                hasUnlockedPromo
                                    ? 'Code promo débloqué grâce à vos 100 pts !'
                                    : 'Débloqué dès 100 points accumulés',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasUnlockedPromo ? primaryGreen : textMuted,
                                  fontWeight: hasUnlockedPromo ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (hasUnlockedPromo) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.discount_outlined,
                              color: goldAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Code Promo :',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: goldAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    RewardService.promoCodeName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.5,
                                      color: Color(0xFF854D0E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _copyPromoCode(RewardService.promoCodeName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: goldAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text(
                                'Copier',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '💡 Ce code est à usage unique : il vous accorde 30% de remise immédiate. Dès qu\'il est utilisé, votre compteur sera remis à 0 point pour collecter à nouveau 100 points.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cumulez encore $missingPoints points pour profiter d\'une réduction exclusive de 30% sur votre prochaine réservation.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Program Rules Section
              const Text(
                'Comment fonctionne le système ?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cardBorderColor),
                ),
                child: Column(
                  children: [
                    _buildRuleRow(
                      icon: Icons.ev_station,
                      color: primaryGreen,
                      title: '+10 Points par réservation',
                      description:
                          'Chaque réservation validée sur une borne vous rapporte automatiquement 10 points fidélité.',
                    ),
                    const Divider(height: 24),
                    _buildRuleRow(
                      icon: Icons.discount,
                      color: goldAccent,
                      title: '100 Points = 30% de réduction',
                      description:
                          'Dès que vous atteignez 100 points, appliquez le code PROMO30 sur votre prochaine réservation pour 30% de réduction immédiate.',
                    ),
                    const Divider(height: 24),
                    _buildRuleRow(
                      icon: Icons.repeat,
                      color: Colors.blue.shade700,
                      title: 'Usage unique & Nouveau cycle à 0',
                      description:
                          'Le code promo est utilisable une seule fois. Dès son utilisation, le compteur revient à 0 et vous collectez à nouveau 100 points pour débloquer un autre code.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Reward History Section
              const Text(
                'Historique des points',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: RewardService.instance.getRewardHistoryStream(userId),
                builder: (context, historySnap) {
                  if (historySnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: primaryGreen),
                      ),
                    );
                  }

                  final history = historySnap.data ?? [];
                  if (history.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cardBorderColor),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Aucun historique de points pour l\'instant',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Effectuez votre première réservation pour gagner 10 points !',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: cardBorderColor),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final type = item['type'] ?? 'earned';
                        final isEarned = type == 'earned';
                        final isRevoked = type == 'revoked';

                        final pts = item['points'] ?? 0;
                        final title = item['title'] ??
                            (isEarned ? 'Réservation' : (isRevoked ? 'Annulation' : 'Code promo 30%'));
                        final desc = item['description'] ?? '';
                        final dateStr = _formatDate(item['createdAt']);

                        final Color itemBg = isEarned
                            ? const Color(0xFFE2EFEA)
                            : (isRevoked ? const Color(0xFFFEE2E2) : const Color(0xFFFAF5E9));
                        final Color itemColor = isEarned
                            ? primaryGreen
                            : (isRevoked ? const Color(0xFFDC2626) : goldAccent);
                        final IconData itemIcon = isEarned
                            ? Icons.add_circle_outline
                            : (isRevoked ? Icons.cancel_outlined : Icons.remove_circle_outline);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: itemBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              itemIcon,
                              color: itemColor,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: itemBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isEarned ? '+$pts pts' : '$pts pts',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: itemColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRuleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
